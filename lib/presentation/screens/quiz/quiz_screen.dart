import 'dart:async' show unawaited;
import 'dart:math' as math;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/quiz/quiz_provider.dart';
import '../../providers/audio/audio_provider.dart';
import '../../../core/languages.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/stt_simulator.dart';
import '../../../core/utils/stt_debug_log.dart';
import '../../../core/utils/fsrs_algorithm.dart';
import '../../../core/widget_keys.dart';
import '../../../services/speech/speech_recognition_service.dart';
import '../../../services/speech/whisper_speech_service.dart';
import '../../../services/speech/stt_race.dart';
import '../../../services/speech/system_stt_engine.dart';
import '../../../services/speech/whisper_stt_engine.dart';
import '../../../services/quiz_orchestration/voice_turn_machine.dart';
import '../../providers/settings/stt_engine_mode_provider.dart';
import '../../providers/speech/whisper_speech_provider.dart';
import '../../widgets/dotted_ground.dart';
import '../../widgets/vk_waveform.dart';
import '../../widgets/mic_button.dart';
import '../../widgets/study/study_scaffold.dart';
import '../../widgets/study/word_in_wave.dart';
import '../../widgets/study/study_feedback_flood.dart';
import '../../design/v3/v3_study_scaffold.dart';
import '../../design/v3/v3_card_stack.dart';
import '../../design/v3/v3_tokens.dart';

// Under test, animations are frozen so Patrol's pumpAndSettle actually settles
// (a perpetual ticker on any study screen otherwise makes every action wait out
// the settle timeout and intermittently trips mid-layout binding assertions).
const _kTestMode = bool.fromEnvironment('TEST_MODE');

class QuizScreen extends ConsumerStatefulWidget {
  const QuizScreen({super.key, required this.args});
  final QuizArgs args;

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen>
    with TickerProviderStateMixin {
  final _stt = SpeechRecognitionService();
  // Whisper engine (own capture + own endpointing) — app-lifetime via
  // provider; the model is heavy. Initialized in initState: a lazy `late`
  // here would first resolve in dispose(), where ref is no longer usable.
  late final WhisperSpeechService _whisper;
  final _answerCtrl = TextEditingController();
  // Guards against stale STT callbacks firing on a new card.
  // True while the current listen session is managed by the SttRace pipeline
  // (Settings → Moteur vocal → Course). The legacy _stt callbacks
  // Race adapters, created lazily on first race use. They WRAP this screen's
  // existing service instances — never disposed here (the services' own
  // lifecycles are unchanged; see dispose()).
  SystemSttEngine? _raceSystemEngine;
  WhisperSttEngine? _raceWhisperEngine;

  // Incremented every time _startListening is called; onListeningDone
  // only acts if the token still matches.
  int _listenToken = 0;
  // Voice "Clavier" escape: when equal to the current card index, that card
  // shows a text-input fallback instead of the mic.
  int? _voiceKbIndex;
  // Hands-free pause state.
  bool _hfPaused = false;
  // Display-only: attempts consumed on the current card, fed by the
  // machine's ShowNotHeard command (the "essai x/3" banner).
  int _notHeardRetries = 0;
  bool _hfNotHeard = false;
  // Hands-free "analyse" phase: mic closed, answer captured, verdict pending.
  // Marked by a low closing tick + pulsing status text so the user knows to
  // stop talking (protocol spec, user request 2026-07-08).
  bool _hfAnalyzing = false;
  bool _hfAutoPausedSilence = false;
  // Flashcards are self-graded by a directional swipe. Keeping this state in
  // the screen (rather than in the quiz provider) makes the physical exit an
  // animation concern and leaves the stack anchored in one place.
  bool _flashcardExiting = false;
  int _flashcardExitDirection = 1;
  double _flashcardDragProgress = 0;
  // Whole-screen warm breathing pulse used during the hands-free reading state.
  late final AnimationController _pulseCtrl;
  // Listening-window countdown bar: fills left→right over the mic's
  // listenFor window; a full bar means the attempt timed out. Restarted on
  // every mic open (retries included).
  late final AnimationController _listenBarCtrl;

  @override
  void initState() {
    super.initState();
    _whisper = ref.read(whisperSpeechProvider);
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1900));
    // Don't run the perpetual breathing pulse under test — it never settles.
    if (!_kTestMode) _pulseCtrl.repeat(reverse: true);
    // Duration mirrors SpeechRecognitionService.startListening's listenFor.
    _listenBarCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 10));
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!SttSimulator.isOn) {
        final ok = await _stt.initialize();
        if (!ok && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('quiz.stt_unavailable'.tr()),
            behavior: SnackBarBehavior.floating,
          ));
        }
      }
      // All voice sessions are machine/race-managed (refactor 4c): engine
      // errors surface as failed windows and go through the machine's
      // ladder. Log-only here.
      _stt.onError = (msg) => sttLog('[STT] engine error (race-managed): $msg');

      // Between race-managed sessions any session-end event is stale — the
      // SystemSttEngine adapter borrows this hook DURING sessions and
      // restores it after (refactor 4c deleted the legacy retry ladder that
      // used to live here).
      _stt.onListeningDone = () {
        sttLog(
            '[STT] stale onListeningDone outside a race-managed session — ignored');
      };
      if (mounted) ref.read(quizProvider.notifier).loadCards(widget.args);
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _listenBarCtrl.dispose();
    _stt.dispose();
    unawaited(_whisper.stopListening());
    _answerCtrl.dispose();
    super.dispose();
  }

  /// Opens the mic only AFTER the app has finished talking (question TTS,
  /// and on a new card after a mistake, the KO correction still in flight).
  /// The old fixed 300ms delay cut speech mid-word via the mic's audio-stop
  /// AND let the recognizer transcribe the app's own voice as the user's
  /// answer (user feedback 2026-07-05).
  Future<void> _waitForSpeechThenListen(QuizCard card) async {
    // Speech at a card boundary is a CHAIN, not one utterance — the wait
    // semantics (and their field-log history) live in AudioDirector.
    final director = ref.read(audioDirectorProvider);
    final waitStart = DateTime.now();
    await director.chainQuiet(keepGoing: () => mounted);
    final speechWaitMs = DateTime.now().difference(waitStart).inMilliseconds;
    sttLog(
        '[HF] waited ${speechWaitMs}ms for TTS chain (isSpeaking=${director.isSpeaking}) — starting 250ms echo tail');
    // Echo tail: let the room go quiet before the mic opens.
    await Future.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    if (_stt.isListening) {
      // A stale session must not swallow this card's window (it would hear
      // our TTS and validate against the wrong card) — stop it, then start
      // fresh. Never skip: skipping left cards without their own session.
      sttLog(
          '[HF] stale session still open — stopping it before this card\'s listen');
      await _stt.stopListening();
      await _whisper.stopListening();
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
    }
    sttLog('[HF] speech finished — calling _startListening');
    unawaited(_startListening(card));
  }

  /// Serializes mic starts: multiple recovery paths (not-heard, stopped-too-
  /// fast, noise-guard) schedule delayed retries, and two firing close
  /// together used to start OVERLAPPING sessions — the second killed the
  /// first, spawning death events, another retry, and another of Samsung's
  /// own recognizer chimes ("1 to 3 bips" per card, field log 2026-07-07).
  bool _listenStartInFlight = false;

  /// Enters the hands-free "analyse" phase: the mic captured speech (or
  /// closed after a real listen) and the verdict is pending. Plays the low
  /// closing tick so the user knows to stop talking. Idempotent per phase —
  /// reset when a new listen or card starts.
  void _enterAnalyzing() {
    if (_hfAnalyzing || widget.args.mode != QuizMode.handsFree) return;
    _listenBarCtrl.stop(); // mic closed — freeze the countdown
    if (!_kTestMode) {
      unawaited(ref.read(audioDirectorProvider).playListenDone());
    }
    if (mounted) setState(() => _hfAnalyzing = true);
  }

  Future<void> _startListening(QuizCard card, {bool isRetry = false}) async {
    if (_listenStartInFlight) {
      sttLog('[HF] _startListening skipped — another start is in flight');
      return;
    }
    if (isRetry && _stt.isListening) {
      sttLog('[HF] retry skipped — a live session is already listening');
      return;
    }
    _listenStartInFlight = true;
    try {
      await _startListeningInner(card, isRetry: isRetry);
    } finally {
      _listenStartInFlight = false;
    }
  }

  /// Experimental race pipeline (SttEngineMode.race): lane 1 races the system
  /// recognizer; on a miss, lane 2 gives offline Whisper a shot. Every guess
  /// is validated inside [SttRace] against the card's accepted answers, the
  /// first match wins, and the card is graded EXACTLY once — the race returns
  /// a single outcome (this also structurally prevents the triple-grade
  /// >100% score bug of 2026-07-19). Becomes a true parallel race when a
  /// sharedPcm engine (sherpa-onnx) is registered.
  // The per-session turn machine (race mode). Owns grade-once, the
  // not-heard ladder, retry pacing and the consecutive-silence auto-pause —
  // one instance per screen so the silence streak spans the whole session.
  VoiceTurnMachine? _turnMachine;

  Future<void> _startRaceListening(
      QuizCard card, String langCode, int sessionToken) async {
    _raceSystemEngine ??= SystemSttEngine(_stt);
    _raceWhisperEngine ??= WhisperSttEngine(_whisper);
    await _raceSystemEngine!.prepare(); // idempotent — already initialised
    // Whisper joins lane 2 in hybrid mode once its model is ready; kick the
    // download in the background on first use. This is intentionally enabled
    // for debug APKs too: field tests must exercise the same hybrid pipeline
    // as the version we plan to ship.
    final courseMode = ref.read(sttEngineModeProvider) == SttEngineMode.race;
    if (courseMode && !_whisper.isReady && !_kTestMode) {
      unawaited(_whisper.ensureModel());
    }

    // The caller flow (card-change listener → chain wait → hand-off → cue)
    // has already executed the transition/prompt/cue phases — feed them
    // through so the machine is in sync, then execute what it commands.
    // From here machine-internal retries replace the legacy ladder: the
    // race path never re-enters _startListening for the same card.
    final m = _turnMachine ??= VoiceTurnMachine();
    m.on(TurnStarted(sessionToken));
    m.on(SlateClean(sessionToken));
    m.on(PromptFinished(sessionToken));
    await _runTurnCommands(m.on(CueFinished(sessionToken)), card, langCode);
  }

  /// True when the machine's turn no longer matches reality — unmounted, a
  /// newer listen session, another card, or a verdict already landed. The
  /// machine's own turn/terminal guards back this up.
  bool _turnStale(int turn, QuizCard card) =>
      !mounted ||
      turn != _listenToken ||
      ref.read(quizProvider).currentCard?.progress.variantId !=
          card.progress.variantId ||
      ref.read(quizProvider).answerState != QuizAnswerState.idle;

  /// Executes the machine's commands for race mode (step 4 of the
  /// voice-orchestration refactor): policy lives in [VoiceTurnMachine], this
  /// is pure mechanism.
  Future<void> _runTurnCommands(
      List<TurnCommand> cmds, QuizCard card, String langCode) async {
    final m = _turnMachine!;
    final turn = m.turn;
    for (final cmd in cmds) {
      switch (cmd) {
        case CleanSlate():
        case PlayPrompt():
        case PlayCue():
          // Performed by the caller flow before the machine was handed the
          // turn; only seen on the initial hand-in.
          break;
        case OpenMic(:final useRescueEngine):
          unawaited(_runRaceLanes(card, langCode, rescue: useRescueEngine));
        case ShowAnalyzing():
          _enterAnalyzing();
        case ShowNotHeard(:final attempt, :final maxAttempts):
          sttLog('[RACE][HF] 🔇 pas entendu — attempt $attempt/$maxAttempts');
          ref.read(quizProvider.notifier).setListening(false);
          if (widget.args.mode == QuizMode.handsFree) {
            if (mounted) {
              setState(() {
                _notHeardRetries = attempt; // "essai ${attempt+1}/max" banner
                _hfNotHeard = true;
                _hfAnalyzing = false; // retry prompt outranks "analyse"
              });
            }
          } else if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('quiz.stt_not_recognised'.tr()),
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ));
          }
        case WaitThenRetry(:final duration):
          // Voice mode has no auto-retry protocol — the user re-taps the mic
          // (a fresh turn supersedes this one).
          if (widget.args.mode != QuizMode.handsFree) break;
          Future.delayed(duration, () {
            if (_turnStale(turn, card)) return;
            unawaited(
                _runTurnCommands(m.on(WaitElapsed(turn)), card, langCode));
          });
        case GradeCorrect(:final candidate):
          _listenBarCtrl.stop();
          sttLog('[RACE][HF] ✅ "$candidate" validated — grading correct');
          ref
              .read(quizProvider.notifier)
              .submitVoiceAnswer(candidate, isDrivingMode: true);
        case GradeWrong(:final transcript):
          _listenBarCtrl.stop();
          sttLog('[RACE][HF] ❌ "$transcript" never validated — grading wrong');
          ref
              .read(quizProvider.notifier)
              .submitVoiceAnswer(transcript, isDrivingMode: true);
        case SkipCard():
          _listenBarCtrl.stop();
          sttLog('[RACE][HF] ⏭ silence — skipping WITHOUT grading');
          ref.read(quizProvider.notifier).setListening(false);
          ref.read(quizProvider.notifier).skipCurrentCard();
        case PauseSession():
          sttLog('[RACE][HF] 🔇🔇 consecutive silent cards — auto-pausing');
          _stt.stopListening();
          unawaited(_whisper.stopListening());
          ref.read(quizProvider.notifier).setListening(false);
          if (mounted) {
            setState(() {
              _hfAutoPausedSilence = true;
              _hfPaused = true;
            });
          }
      }
    }
  }

  /// One listen attempt: lane 1 races the system recognizer; on a miss lane 2
  /// gives offline Whisper a shot. Outcomes are REPORTED to the machine —
  /// every decision (grade/retry/skip/pause) comes back as commands.
  Future<void> _runRaceLanes(QuizCard card, String langCode,
      {required bool rescue}) async {
    final m = _turnMachine!;
    final turn = m.turn;

    // Retry attempts replay the "your turn" earcon (protocol 2026-07-08:
    // retry message → start bip); the first attempt's cue came from the
    // caller flow.
    if (m.attempt > 1 &&
        widget.args.mode == QuizMode.handsFree &&
        !_kTestMode) {
      await ref.read(audioDirectorProvider).listenCue();
      if (_turnStale(turn, card)) return;
    }

    m.on(MicOpened(turn));
    ref.read(quizProvider.notifier).setListening(true);

    // While the user answers, prepare the NEXT card: pre-warm its TTS voice
    // (fr↔ko engine switch costs 1-3.7s) and prefetch its ElevenLabs audio
    // (first render is a 1-4s network fetch). Lived in the legacy block and
    // was silently skipped by race mode since 4a — restored here (4c).
    final upcoming = ref.read(quizProvider).nextCard;
    if (upcoming != null && m.attempt == 0) {
      final audio = ref.read(audioPlayerServiceProvider);
      unawaited(audio.warmUp(upcoming.progress.direction.questionLang));
      unawaited(audio.prefetch(
          upcoming.questionWord, upcoming.progress.direction.questionLang));
      if (upcoming.answerWords.isNotEmpty) {
        unawaited(audio.prefetch(upcoming.answerWords.first,
            upcoming.progress.direction.answerLang));
      }
    }
    void runBar() {
      if (!_kTestMode) {
        _listenBarCtrl
          ..reset()
          ..forward();
      }
    }

    sttLog(
        '[RACE][HF] lane 1 (system)  turn=$turn  attempt=${m.attempt}  rescue=$rescue  lang=$langCode');
    runBar();
    var outcome = await SttRace([_raceSystemEngine!]).run(
      langCode: langCode,
      acceptedAnswers: card.answerWords,
      promptHints: card.answerWords,
      timeout: const Duration(seconds: 10),
      restartOnSessionEnd: false,
      onPartial: (h) {
        if (!_turnStale(turn, card)) {
          ref.read(quizProvider.notifier).setPartialTranscript(h.transcript);
        }
      },
    );
    if (_turnStale(turn, card)) return;
    var hadReal = outcome.hadRealSession;

    final courseMode = ref.read(sttEngineModeProvider) == SttEngineMode.race;
    if (!outcome.matched && courseMode && _whisper.isReady) {
      sttLog('[RACE][HF] lane 2 (whisper)  turn=$turn');
      await _runTurnCommands(m.micClosedPendingVerdict(turn), card, langCode);
      runBar();
      final second = await SttRace([_raceWhisperEngine!]).run(
        langCode: langCode,
        acceptedAnswers: card.answerWords,
        promptHints: card.answerWords,
        timeout: const Duration(seconds: 8),
      );
      if (_turnStale(turn, card)) return;
      hadReal = hadReal || second.hadRealSession;
      if (second.matched ||
          (second.bestTranscript?.trim().isNotEmpty ?? false)) {
        outcome = second;
      }
    }

    _listenBarCtrl.stop();
    final heard = outcome.bestTranscript;
    final TurnEvent verdictEvent = outcome.matched
        ? MatchHeard(turn, outcome.matchedCandidate!)
        : (heard != null && heard.trim().isNotEmpty)
            ? WrongHeard(turn, heard)
            : NothingHeard(turn, hadRealWindow: hadReal);
    await _runTurnCommands(m.on(verdictEvent), card, langCode);
  }

  Future<void> _startListeningInner(QuizCard card,
      {required bool isRetry}) async {
    // Fresh listens reset the banner to "speak now"; retry listens KEEP the
    // "try x/3" / "répète" prompts visible — they already say what to do.
    if ((_hfNotHeard && !isRetry) || _hfAnalyzing) {
      setState(() {
        _hfNotHeard = _hfNotHeard && isRetry;
        _hfAnalyzing = false;
      });
    }
    _listenToken++;
    sttLog(
        '[HF] _startListening  token=$_listenToken  isRetry=$isRetry  question="${card.questionWord}"  answerWords=${card.answerWords}');
    ref.read(quizProvider.notifier).setListening(true);

    if (SttSimulator.isOn) {
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      final answer = switch (SttSimulator.mode) {
        'correct' => card.answerWords.isNotEmpty ? card.answerWords.first : '',
        'wrong' => '__wrong__',
        _ => '',
      };
      ref.read(quizProvider.notifier).submitVoiceAnswer(
            answer,
            isDrivingMode: widget.args.mode == QuizMode.handsFree ||
                widget.args.mode == QuizMode.voice,
          );
      return;
    }

    // Stop audio without awaiting — let Android's audio-focus system handle the
    // handover concurrently.  We still wait 300 ms so ExoPlayer has time to
    // release the focus before STT grabs the mic (Samsung requirement).
    sttLog('[HF] Triggering audio stop + 300ms focus-handover wait');
    await ref.read(audioDirectorProvider).handOffToMic();
    if (!mounted) return;

    // Hands-free is eyes-off: "your turn" earcon + haptic BEFORE the mic
    // opens — played while listening, the recognizer hears the earcon itself
    // and can transcribe it as a (wrong) answer.
    // Retries are cued too: the protocol is "retry message → start bip"
    // (user request 2026-07-08). Safe now that earcons use FOCUS_NONE and
    // session starts are serialized — the old silent-retry rule guarded
    // against focus-contest kills that no longer happen.
    if (widget.args.mode == QuizMode.handsFree && !_kTestMode) {
      sttLog('[HF] 🔔 playing listen earcon (mic opens in 250ms)');
      HapticFeedback.selectionClick();
      await ref.read(audioDirectorProvider).listenCue();
      if (!mounted) return;
    }

    final currentDir = ref.read(quizProvider).currentCard?.progress.direction;
    final langCode = currentDir?.answerLang ?? widget.args.langB;
    // Capture token so late-arriving onResult from this session is ignored
    // once a new session (next card) has started.
    final sessionToken = _listenToken;

    // Refactor 4c: EVERY voice turn — vocab AND grammar — runs on the
    // VoiceTurnMachine. Système is a system-only lane, Course adds the
    // offline Whisper lane. The legacy streaming path is gone; grammar's
    // short generated answers grade exactly like vocab through the race.
    await _startRaceListening(card, langCode, sessionToken);
  }

  @override
  Widget build(BuildContext context) {
    final quizState = ref.watch(quizProvider);

    ref.listen<QuizState>(quizProvider, (prev, next) {
      if (prev?.answerState == QuizAnswerState.idle &&
          next.answerState != QuizAnswerState.idle) {
        final correct = next.answerState == QuizAnswerState.correct;
        // Sound effect for every mode. Muted in TEST_MODE: audio HAL calls
        // destabilize the CI emulator (suspected cause of the silent app-spawn
        // deaths that only ever hit the quiz E2E suites).
        if (!_kTestMode) {
          final director = ref.read(audioDirectorProvider);
          if (correct) {
            director.playCorrect();
          } else {
            director.playIncorrect();
          }
        }
        // Hands-free is eyes-off: pair the earcon with a distinct haptic.
        if (widget.args.mode == QuizMode.handsFree) {
          if (correct) {
            HapticFeedback.mediumImpact();
          } else {
            HapticFeedback.heavyImpact();
          }
        }
        // Auto-speak the revealed answer — see shouldSpeakAnswer for the policy.
        // (Also muted in TEST_MODE, same emulator-audio rationale as above.)
        final shouldSpeak = !_kTestMode &&
            shouldSpeakAnswer(widget.args.mode, correct: correct);
        if (shouldSpeak) {
          final card = next.currentCard;
          if (card != null && card.answerWords.isNotEmpty) {
            final answerLang = card.progress.direction.answerLang;
            unawaited(ref
                .read(audioPlayerServiceProvider)
                .speak(card.answerWords.first, answerLang));
          }
        }
        // Hands-free renders the full-screen StudyFeedbackFlood in build()
        // (transient — the provider auto-advances in driving mode), so no
        // separate flash overlay here.
      }
      if (widget.args.mode == QuizMode.handsFree) {
        final cardChanged = prev?.currentIndex != next.currentIndex;
        final justLoaded = prev?.isLoading == true && !next.isLoading;
        // Backup trigger: cards appeared without an isLoading transition.
        final cardsJustAppeared = !justLoaded &&
            (prev?.cards.isEmpty ?? true) &&
            next.cards.isNotEmpty;
        final card = next.currentCard;
        if ((cardChanged || justLoaded || cardsJustAppeared) &&
            card != null &&
            !next.isComplete) {
          sttLog(
              '[HF] Card trigger: cardChanged=$cardChanged justLoaded=$justLoaded cardsJustAppeared=$cardsJustAppeared  idx=${next.currentIndex}  question="${card.questionWord}"  answers=${card.answerWords}');
          // Invalidate the previous card's session NOW: a session left open
          // across the transition hears the new card's TTS question and
          // grades it against the old card (field log 2026-07-06 — "mouton"
          // spoken by the app's own voice failed the 양 card).
          _listenToken++;
          if (_stt.isListening || _whisper.isListening) {
            sttLog('[HF] stopping stale listen session from previous card');
            unawaited(_stt.stopListening());
            unawaited(_whisper.stopListening());
          }
          // Clean slate at the card boundary (field report 2026-07-20): the
          // countdown bar kept the PREVIOUS card's frozen value all through
          // the new card's reading phase (it only reset when the next mic
          // opened) — zero it now.
          _listenBarCtrl
            ..stop()
            ..reset();
          // New card = back to the reading phase; don't let the previous
          // card's "analyse" banner linger over the new word.
          if (_hfAnalyzing || _hfNotHeard) {
            setState(() {
              _hfAnalyzing = false;
              _hfNotHeard = false;
            });
          }
          unawaited(_waitForSpeechThenListen(card));
        }
      }
    });

    if (quizState.isLoading) {
      return const Scaffold(
        body: Center(
          child:
              CircularProgressIndicator(color: AppColors.clay, strokeWidth: 2),
        ),
      );
    }

    if (quizState.errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline,
                    size: 48, color: AppColors.rose),
                const SizedBox(height: 16),
                Text(quizState.errorMessage!,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body.copyWith(color: AppColors.muted)),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: () => context.go('/home'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.teal,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text('quiz.go_home_button'.tr(),
                        style: AppTextStyles.fig(15, FontWeight.w700)
                            .copyWith(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (quizState.isComplete) {
      return _SummaryScreen(
        correct: quizState.correctCount,
        total: quizState.displayTotal,
        onDone: () => context.go('/home'),
        onRestart: () {
          ref.read(quizProvider.notifier).loadCards(widget.args);
        },
      );
    }

    final card = quizState.currentCard;
    if (card == null) {
      return const Scaffold(
        body: Center(
          child:
              CircularProgressIndicator(color: AppColors.clay, strokeWidth: 2),
        ),
      );
    }

    // Every mode renders on the unified dark/paper study canvas.
    return switch (widget.args.mode) {
      QuizMode.voice => _buildVoiceStudy(context, quizState, card),
      QuizMode.flashcard => _buildCartesStudy(context, quizState, card),
      QuizMode.typing => _buildEcrireStudy(context, quizState, card),
      QuizMode.handsFree => _buildHandsFreeStudy(context, quizState, card),
    };
  }

  // ── Hands-free controls ───────────────────────────────────────────────────
  void _toggleHfPause() {
    setState(() {
      _hfPaused = !_hfPaused;
      _hfAutoPausedSilence = false;
    });
    if (_hfPaused) {
      _stt.stopListening();
      unawaited(_whisper.stopListening());
      ref.read(quizProvider.notifier).setListening(false);
      unawaited(ref.read(audioPlayerServiceProvider).stop());
    } else {
      // Manual resume = the user says the environment is OK again.
      _turnMachine?.resetSilenceStreak();
      final card = ref.read(quizProvider).currentCard;
      if (card != null) unawaited(_startListening(card));
    }
  }

  void _hfRepeat() {
    final card = ref.read(quizProvider).currentCard;
    if (card == null) return;
    final questionLang = card.progress.direction.questionLang;
    unawaited(ref
        .read(audioPlayerServiceProvider)
        .speak(card.questionWord, questionLang));
    unawaited(_startListening(card));
  }

  void _hfSkip() {
    // A deliberate skip is not a wrong answer: nothing is graded, the card
    // returns later in the session.
    _stt.stopListening();
    unawaited(_whisper.stopListening());
    ref.read(quizProvider.notifier).skipCurrentCard();
  }

  /// Hands-free (Mains libres) — eyes-off canvas: word in the wave with the
  /// audio-I/O state machine (frozen + screen-pulse while reading vs animated
  /// while listening), oversized Répéter/Passer, tap-centre to pause, and the
  /// transient full-screen flood for grading.
  Widget _buildHandsFreeStudy(
      BuildContext context, QuizState s, QuizCard card) {
    final questionIsHangul =
        Languages.usesHangul(card.progress.direction.questionLang);
    final answerIsHangul =
        Languages.usesHangul(card.progress.direction.answerLang);

    if (s.answerState != QuizAnswerState.idle) {
      final correct = s.answerState == QuizAnswerState.correct;
      return StudyFeedbackFlood(
        isCorrect: correct,
        label:
            correct ? 'quiz.feedback_correct'.tr() : 'quiz.feedback_wrong'.tr(),
        answer: correct ? null : card.answerWords.join(' / '),
        answerIsKorean: answerIsHangul,
        // No onContinue → transient; the provider auto-advances (driving mode).
      );
    }

    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final listening = s.isListening && !_hfPaused;

    // Phase priority: paused > analyzing (mic closed, verdict pending) >
    // not-heard (retry prompt with attempt count) > listening (speak now) >
    // reading the word.
    final cue = _hfPaused
        ? null
        : (_hfAnalyzing
            ? 'quiz.hf_analyzing'.tr()
            : ((_hfNotHeard
                ? 'quiz.hf_not_heard_retry'.tr(namedArgs: {
                    'attempt': '${_notHeardRetries + 1}',
                    'total': '3',
                  })
                : (listening
                    ? 'quiz.say_in_lang'.tr(namedArgs: {
                        'lang': 'lang.${_answerLangCode(card)}'.tr()
                      })
                    : 'quiz.hf_reading'.tr()))));
    // Hands-free lives on the V3 dark study canvas in every app theme. Never
    // inherit light-theme foregrounds here: that is what made the light-mode
    // version unreadable against the pond background.
    final cueColor =
        listening && !_hfAnalyzing ? V3Colors.amber : V3Colors.inkLight70;

    return V3StudyScaffold(
      remaining: (s.displayTotal - s.position + 1).clamp(1, s.displayTotal),
      onQuit: _quit,
      child: Stack(
        children: [
          // Reading state only: whole-canvas warm breathing pulse (not in
          // the "pas entendu" state).
          if (!listening && !_hfPaused && !_hfNotHeard)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _pulseCtrl,
                  builder: (_, __) {
                    final t = reduceMotion ? 0.5 : _pulseCtrl.value;
                    return DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          radius: 1.1,
                          colors: [
                            AppColors.clay.withValues(alpha: 0.04 + 0.10 * t),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          // Main content — tap centre to pause.
          GestureDetector(
            onTap: _toggleHfPause,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      // During "analyse" the status text breathes (slow fade
                      // in/out) and the wave freezes — the mic is closed.
                      child: AnimatedBuilder(
                        animation: _pulseCtrl,
                        builder: (_, __) {
                          final fade = _hfAnalyzing && !reduceMotion
                              ? 0.35 + 0.65 * _pulseCtrl.value
                              : 1.0;
                          return WordInWave(
                            word: card.questionWord,
                            isKorean: questionIsHangul,
                            cue: cue,
                            wordColor: V3Colors.inkLight,
                            cueColor: cueColor.withValues(alpha: fade),
                            waveActive: listening && !_hfAnalyzing,
                          );
                        },
                      ),
                    ),
                  ),
                  // Listening-window countdown: fills left→right while the
                  // mic is open; a full bar = this attempt timed out. Hidden
                  // outside the listening phase.
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: listening && !_hfAnalyzing ? 1.0 : 0.0,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: AnimatedBuilder(
                        animation: _listenBarCtrl,
                        builder: (_, __) => ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: _listenBarCtrl.value,
                            minHeight: 5,
                            backgroundColor:
                                V3Colors.ruleDark.withValues(alpha: 0.7),
                            valueColor:
                                const AlwaysStoppedAnimation(V3Colors.amber),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _HfButton(
                          key: const ValueKey(WidgetKeys.hfRepeat),
                          icon: Icons.replay_rounded,
                          label: 'quiz.hf_repeat'.tr(),
                          onTap: _hfRepeat,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _HfButton(
                          key: const ValueKey(WidgetKeys.hfSkip),
                          icon: Icons.skip_next_rounded,
                          label: 'quiz.hf_skip'.tr(),
                          onTap: _hfSkip,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Pause overlay.
          if (_hfPaused)
            Positioned.fill(
              child: GestureDetector(
                onTap: _toggleHfPause,
                behavior: HitTestBehavior.opaque,
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.58),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                            _hfAutoPausedSilence
                                ? Icons.hearing_disabled_rounded
                                : Icons.pause_rounded,
                            size: 56,
                            color: V3Colors.inkLight),
                        const SizedBox(height: 10),
                        Text(
                            (_hfAutoPausedSilence
                                    ? 'quiz.hf_paused_silence'
                                    : 'quiz.hf_paused')
                                .tr(),
                            textAlign: TextAlign.center,
                            style: AppTextStyles.grotesk(28, FontWeight.w700)
                                .copyWith(color: V3Colors.inkLight)),
                        const SizedBox(height: 6),
                        Text('quiz.hf_resume_hint'.tr(),
                            style: AppTextStyles.fig(14, FontWeight.w500)
                                .copyWith(color: V3Colors.inkLight70)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _quit() {
    _stt.stopListening();
    unawaited(_whisper.stopListening());
    ref.read(quizProvider.notifier).setListening(false);
    context.go('/home');
  }

  // Answer language code for the current card. Derived from the legacy
  // QuizDirection enum; the generic-language-pairs task replaces this with the
  // list's target langCode.
  String _answerLangCode(QuizCard card) => card.progress.direction.answerLang;

  String _nextReviewText(int scheduledDays, bool correct) {
    if (!correct) return 'quiz.next_review_soon'.tr();
    return scheduledDays <= 1
        ? 'quiz.next_review_tomorrow'.tr()
        : 'quiz.next_review_in_days'
            .tr(namedArgs: {'days': scheduledDays.toString()});
  }

  Future<void> _dismissFlashcard({required bool knew}) async {
    if (_flashcardExiting) return;
    setState(() {
      _flashcardExiting = true;
      _flashcardExitDirection = knew ? 1 : -1;
    });
    HapticFeedback.selectionClick();
    ref
        .read(quizProvider.notifier)
        .gradeFlashcard(knew ? FsrsRating.good : FsrsRating.again);
    await Future<void>.delayed(const Duration(milliseconds: 460));
    if (!mounted) return;
    ref.read(quizProvider.notifier).advance();
    setState(() {
      _flashcardExiting = false;
      _flashcardDragProgress = 0;
    });
  }

  /// Cartes — one stable physical stack: tap to turn, swipe to peel away.
  Widget _buildCartesStudy(BuildContext context, QuizState s, QuizCard card) {
    final questionIsHangul =
        Languages.usesHangul(card.progress.direction.questionLang);
    final answerIsHangul =
        Languages.usesHangul(card.progress.direction.answerLang);

    final showBack = s.isFlipped;
    final dragAmount = _flashcardDragProgress.abs();
    final tint = _flashcardDragProgress < 0
        ? V3Colors.cardAgainTint
        : V3Colors.cardKnownTint;
    final paperColor = Color.lerp(V3Colors.paper, tint, dragAmount * 0.28)!;
    Widget face({required bool back}) {
      final word = back ? card.answerWords.join(' / ') : card.questionWord;
      final wordIsKorean = back ? answerIsHangul : questionIsHangul;
      return Material(
        color: paperColor,
        borderRadius: const BorderRadius.all(V3Radii.card),
        child: InkWell(
          onTap: back || _flashcardExiting
              ? null
              : () => ref.read(quizProvider.notifier).flipCard(),
          borderRadius: const BorderRadius.all(V3Radii.card),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(back ? 'RÉPONSE' : 'PRENDS LA CARTE',
                    style: V3Text.mono(12)),
                const SizedBox(height: 26),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      word,
                      textAlign: TextAlign.center,
                      style:
                          wordIsKorean ? V3Text.korean(40) : V3Text.title(38),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  back
                      ? '← PAS ENCORE     JE SAVAIS →'
                      : 'quiz.card_flip_hint'.tr(),
                  textAlign: TextAlign.center,
                  style: V3Text.body(14, color: V3Colors.ink60),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return V3StudyScaffold(
      remaining: (s.displayTotal - s.position + 1).clamp(1, s.displayTotal),
      onQuit: _quit,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final cardWidth = constraints.maxWidth > 350
                        ? 350.0
                        : constraints.maxWidth;
                    return SizedBox(
                      width: cardWidth,
                      height: 380,
                      child: GestureDetector(
                        onHorizontalDragUpdate: !showBack || _flashcardExiting
                            ? null
                            : (details) => setState(() {
                                  _flashcardDragProgress =
                                      (_flashcardDragProgress +
                                              details.delta.dx / cardWidth)
                                          .clamp(-1.0, 1.0);
                                }),
                        onHorizontalDragCancel: !showBack || _flashcardExiting
                            ? null
                            : () => setState(() => _flashcardDragProgress = 0),
                        onHorizontalDragEnd: !showBack || _flashcardExiting
                            ? null
                            : (details) {
                                final velocity = details.primaryVelocity ?? 0;
                                final progress = _flashcardDragProgress;
                                if (progress.abs() < 0.25 &&
                                    velocity.abs() < 240) {
                                  setState(() => _flashcardDragProgress = 0);
                                  return;
                                }
                                unawaited(
                                  _dismissFlashcard(
                                      knew: progress.abs() >= 0.05
                                          ? progress > 0
                                          : velocity > 0),
                                );
                              },
                        child: V3CardStack(
                          remaining: (s.displayTotal - s.position + 1)
                              .clamp(1, s.displayTotal),
                          total: s.displayTotal,
                          cardId: card.progress.variantId,
                          isExiting: _flashcardExiting,
                          exitDirection: _flashcardExitDirection,
                          dragProgress: _flashcardDragProgress,
                          child: _FlashcardSurface(
                            key: const ValueKey(WidgetKeys.cartesCard),
                            isBack: showBack,
                            front: face(back: false),
                            back: face(back: true),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Écrire — word-in-wave + native text input + Valider, with the flood.
  Widget _buildEcrireStudy(BuildContext context, QuizState s, QuizCard card) {
    final questionIsHangul =
        Languages.usesHangul(card.progress.direction.questionLang);
    final answerIsHangul =
        Languages.usesHangul(card.progress.direction.answerLang);

    if (s.answerState != QuizAnswerState.idle) {
      final correct = s.answerState == QuizAnswerState.correct;
      return StudyFeedbackFlood(
        isCorrect: correct,
        onPlayAudio: card.answerWords.isEmpty
            ? null
            : () => unawaited(ref.read(audioPlayerServiceProvider).speak(
                card.answerWords.first, card.progress.direction.answerLang)),
        label:
            correct ? 'quiz.feedback_correct'.tr() : 'quiz.feedback_wrong'.tr(),
        answer: card.answerWords.join(' / '),
        answerIsKorean: answerIsHangul,
        detail: _nextReviewText(s.scheduledDays, correct),
        continueLabel: 'quiz.continue_button'.tr(),
        onContinue: () => ref.read(quizProvider.notifier).advance(),
      );
    }

    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final cue = 'quiz.write_in_lang'.tr(
      namedArgs: {'lang': 'lang.${_answerLangCode(card)}'.tr()},
    );
    final cueColor = isDark ? AppColors.clayLight : AppColors.clayDeep;

    void submit() {
      ref.read(quizProvider.notifier).submitTextAnswer(_answerCtrl.text);
      _answerCtrl.clear();
    }

    return StudyScaffold(
      current: s.position,
      total: s.displayTotal,
      counterOverride: s.inReviewTail
          ? 'quiz.review_tail'.tr(namedArgs: {
              'n': '${s.reviewPosition}',
              'm': '${s.reviewTotal}',
            })
          : null,
      onQuit: _quit,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: WordInWave(
                  word: card.questionWord,
                  isKorean: questionIsHangul, // question is Korean when KO→FR
                  cue: cue,
                  cueColor: cueColor,
                  waveActive: false,
                ),
              ),
            ),
            // Native keyboard — underlined field, clay caret.
            TextField(
              key: const ValueKey(WidgetKeys.ecrireInput),
              controller: _answerCtrl,
              autofocus: true,
              textAlign: TextAlign.center,
              textInputAction: TextInputAction.done,
              cursorColor: AppColors.clay,
              style: AppTextStyles.fig(22, FontWeight.w600)
                  .copyWith(color: cs.onSurface),
              decoration: InputDecoration(
                filled: false,
                hintText: 'quiz.typing_hint'.tr(),
                border: const UnderlineInputBorder(),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: cs.outline),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.clay, width: 2),
                ),
              ),
              onSubmitted: (_) => submit(),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const ValueKey(WidgetKeys.ecrireValidate),
                onPressed: submit,
                child: Text('quiz.validate'.tr()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Voix — the unified dark study canvas: word-in-wave + mic + escape pills,
  /// with the full-screen flood once answered.
  Widget _buildVoiceStudy(BuildContext context, QuizState s, QuizCard card) {
    final questionIsHangul =
        Languages.usesHangul(card.progress.direction.questionLang);
    final answerIsHangul =
        Languages.usesHangul(card.progress.direction.answerLang);

    if (s.answerState != QuizAnswerState.idle) {
      final correct = s.answerState == QuizAnswerState.correct;
      return StudyFeedbackFlood(
        isCorrect: correct,
        label:
            correct ? 'quiz.feedback_correct'.tr() : 'quiz.feedback_wrong'.tr(),
        answer: card.answerWords.join(' / '),
        answerIsKorean: answerIsHangul, // answer is Korean when FR→KO
        detail: _nextReviewText(s.scheduledDays, correct),
        continueLabel: 'quiz.continue_button'.tr(),
        onContinue: () => ref.read(quizProvider.notifier).advance(),
      );
    }

    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final cue = 'quiz.say_in_lang'.tr(
      namedArgs: {'lang': 'lang.${_answerLangCode(card)}'.tr()},
    );
    final cueColor = isDark ? AppColors.clayLight : AppColors.clayDeep;
    final kbOn = _voiceKbIndex == s.currentIndex;

    return StudyScaffold(
      current: s.position,
      total: s.displayTotal,
      counterOverride: s.inReviewTail
          ? 'quiz.review_tail'.tr(namedArgs: {
              'n': '${s.reviewPosition}',
              'm': '${s.reviewTotal}',
            })
          : null,
      onQuit: _quit,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: WordInWave(
                  word: card.questionWord,
                  isKorean: questionIsHangul, // question is Korean when KO→FR
                  cue: kbOn ? null : cue,
                  cueColor: cueColor,
                  waveActive: s.isListening,
                ),
              ),
            ),
            if (s.partialTranscript.isNotEmpty) ...[
              Text(
                s.partialTranscript,
                textAlign: TextAlign.center,
                style: AppTextStyles.fig(16, FontWeight.w500).copyWith(
                    color: isDark ? AppColors.onDarkMuted : AppColors.muted),
              ),
              const SizedBox(height: 14),
            ],
            if (kbOn)
              _VoiceKeyboardInput(
                controller: _answerCtrl,
                onSubmit: (a) {
                  ref.read(quizProvider.notifier).submitTextAnswer(a);
                  _answerCtrl.clear();
                },
              )
            else ...[
              MicButton(
                key: const Key('mic_button'),
                isListening: s.isListening,
                answerState: s.answerState,
                onTap: () => _startListening(card),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _EscapePill(
                    key: const ValueKey(WidgetKeys.voiceReveal),
                    icon: Icons.visibility_outlined,
                    label: 'quiz.voice_reveal'.tr(),
                    onTap: () {
                      _stt.stopListening();
                      ref.read(quizProvider.notifier).submitVoiceAnswer('');
                    },
                  ),
                  const SizedBox(width: 12),
                  _EscapePill(
                    key: const ValueKey(WidgetKeys.voiceKeyboard),
                    icon: Icons.keyboard_outlined,
                    label: 'quiz.voice_keyboard'.tr(),
                    onTap: () {
                      _stt.stopListening();
                      ref.read(quizProvider.notifier).setListening(false);
                      setState(() => _voiceKbIndex = s.currentIndex);
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Voice escape pill ─────────────────────────────────────────────────────────

class _EscapePill extends StatelessWidget {
  const _EscapePill({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final fg = isDark ? AppColors.onDarkMuted : AppColors.muted;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color:
              cs.surfaceContainerHighest.withValues(alpha: isDark ? 0.5 : 0.7),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: cs.outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 6),
            Text(label,
                style:
                    AppTextStyles.fig(13, FontWeight.w600).copyWith(color: fg)),
          ],
        ),
      ),
    );
  }
}

/// A real two-sided turn: the answer stays hidden until the card passes its
/// edge, rather than swapping text in place.
class _FlashcardSurface extends StatelessWidget {
  const _FlashcardSurface({
    super.key,
    required this.isBack,
    required this.front,
    required this.back,
  });

  final bool isBack;
  final Widget front;
  final Widget back;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(end: isBack ? 1 : 0),
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeInOutCubic,
        builder: (context, value, _) {
          final backFace = value >= 0.5;
          final transform = Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(value * math.pi);
          return Transform(
            alignment: Alignment.center,
            transform: transform,
            child: backFace
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.rotationY(math.pi),
                    child: back,
                  )
                : front,
          );
        },
      );
}

// ── Hands-free oversized control ──────────────────────────────────────────────

class _HfButton extends StatelessWidget {
  const _HfButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 104,
        decoration: BoxDecoration(
          color: V3Colors.block,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: V3Colors.ruleDark),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: V3Colors.inkLight),
            const SizedBox(height: 8),
            Text(label,
                style: AppTextStyles.fig(15, FontWeight.w700)
                    .copyWith(color: V3Colors.inkLight)),
          ],
        ),
      ),
    );
  }
}

// ── Voice "Clavier" text fallback ─────────────────────────────────────────────

class _VoiceKeyboardInput extends StatelessWidget {
  const _VoiceKeyboardInput({required this.controller, required this.onSubmit});
  final TextEditingController controller;
  final ValueChanged<String> onSubmit;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(hintText: 'quiz.typing_hint'.tr()),
            onSubmitted: onSubmit,
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () => onSubmit(controller.text),
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.clay,
              borderRadius: BorderRadius.circular(14),
            ),
            child:
                const Icon(Icons.send_rounded, color: Colors.white, size: 20),
          ),
        ),
      ],
    );
  }
}

// ── Summary screen ────────────────────────────────────────────────────────────

class _SummaryScreen extends StatelessWidget {
  const _SummaryScreen({
    required this.correct,
    required this.total,
    required this.onDone,
    required this.onRestart,
  });
  final int correct;
  final int total;
  final VoidCallback onDone;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0 : (correct / total * 100).round();
    final isGreat = pct >= 80;

    return Scaffold(
      key: const ValueKey(WidgetKeys.summary),
      body: Stack(
        children: [
          const DottedGround(),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Waveform celebration
                    VkWaveform(
                      height: 72,
                      barWidth: 8,
                      gap: 5,
                      isAnimating: isGreat,
                      opacity: isGreat ? 1.0 : 0.4,
                    ),
                    const SizedBox(height: 32),
                    Text('quiz.summary_label'.tr(),
                        style: AppTextStyles.eyebrow
                            .copyWith(color: AppColors.muted)),
                    const SizedBox(height: 12),
                    // Big accuracy
                    Text(
                      '$pct %',
                      style: AppTextStyles.heroNumber.copyWith(
                        color: isGreat ? AppColors.clay : AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'quiz.summary_correct_count'.tr(namedArgs: {
                        'correct': correct.toString(),
                        'total': total.toString()
                      }),
                      style: AppTextStyles.fig(16, FontWeight.w500)
                          .copyWith(color: AppColors.muted),
                    ),
                    const SizedBox(height: 48),
                    // Buttons
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: onRestart,
                            child: Container(
                              height: 52,
                              decoration: BoxDecoration(
                                color: AppColors.line,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Center(
                                child: Text('quiz.summary_restart'.tr(),
                                    style:
                                        AppTextStyles.fig(14, FontWeight.w600)
                                            .copyWith(color: AppColors.muted)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: onDone,
                            child: Container(
                              height: 52,
                              decoration: BoxDecoration(
                                color: AppColors.teal,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Center(
                                child: Text('quiz.summary_home'.tr(),
                                    style:
                                        AppTextStyles.fig(14, FontWeight.w700)
                                            .copyWith(color: Colors.white)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
