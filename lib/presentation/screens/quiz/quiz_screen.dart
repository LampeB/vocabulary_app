import 'dart:async' show unawaited;
import 'dart:math' as math;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/quiz/quiz_provider.dart';
import '../../providers/audio/audio_provider.dart';
import '../../providers/auth/auth_provider.dart';
import '../../../core/languages.dart';
import '../../../core/network/connectivity_status.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/stt_simulator.dart';
import '../../../core/utils/stt_debug_log.dart';
import '../../../core/utils/fsrs_algorithm.dart';
import '../../../core/widget_keys.dart';
import '../../../domain/usecases/quiz/get_due_cards_usecase.dart'
    show QuizSource;
import '../../../services/speech/speech_recognition_service.dart';
import '../../../services/speech/whisper_speech_service.dart';
import '../../../services/speech/elevenlabs_speech_service.dart';
import '../../../services/speech/phone_pcm_recognizer.dart';
import '../../../services/speech/phone_stt_engine.dart';
import '../../../services/speech/shared_pcm_capture.dart';
import '../../../services/speech/stt_engine.dart';
import '../../../services/speech/stt_engine_registry.dart';
import '../../../services/speech/stt_race.dart';
import '../../../services/speech/stt_race_status.dart';
import '../../../services/speech/system_stt_engine.dart';
import '../../../services/speech/whisper_stt_engine.dart';
import '../../../services/speech/elevenlabs_stt_engine.dart';
import '../../../services/quiz_orchestration/audio_director.dart';
import '../../../services/quiz_orchestration/voice_turn_machine.dart';
import '../../providers/settings/audio_settings_provider.dart';
import '../../providers/settings/stt_engine_mode_provider.dart';
import 'hf_cue.dart';
import '../../providers/speech/whisper_speech_provider.dart';
import '../../providers/speech/elevenlabs_speech_provider.dart';
import '../../providers/speech/shared_pcm_capture_provider.dart';
import '../../providers/speech/system_speech_recognition_provider.dart';
import '../../widgets/vk_waveform.dart';
import '../../widgets/mic_button.dart';
import '../../widgets/scroll_affordance.dart';
import '../../widgets/study/study_scaffold.dart';
import '../../widgets/study/word_in_wave.dart';
import '../../widgets/study/stt_status_strip.dart';
import '../../widgets/study/study_feedback_flood.dart';
import '../../design/v3/v3_study_scaffold.dart';
import '../../design/v3/v3_card_stack.dart';
import '../../design/v3/v3_pond.dart';
import '../../design/v3/v3_tokens.dart';

// Under test, animations are frozen so Patrol's pumpAndSettle actually settles
// (a perpetual ticker on any study screen otherwise makes every action wait out
// the settle timeout and intermittently trips mid-layout binding assertions).
const _kTestMode = bool.fromEnvironment('TEST_MODE');

final voiceTurnMachineFactoryProvider = Provider<VoiceTurnMachine Function()>(
  (ref) => VoiceTurnMachine.new,
);

/// Exposes the route containing the shell's nested navigator. The quiz's own
/// route can stay current inside that navigator when a root route covers it.
class QuizRouteVisibility extends StatelessWidget {
  const QuizRouteVisibility({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final route = ModalRoute.of(context);
    return _QuizRouteScope(
      route: route,
      current: route?.isCurrent ?? true,
      child: child,
    );
  }
}

class _QuizRouteScope extends InheritedWidget {
  const _QuizRouteScope({
    required this.route,
    required this.current,
    required super.child,
  });

  final ModalRoute<Object?>? route;
  final bool current;

  @override
  bool updateShouldNotify(_QuizRouteScope oldWidget) =>
      route != oldWidget.route || current != oldWidget.current;
}

class QuizScreen extends ConsumerStatefulWidget {
  const QuizScreen({super.key, required this.args});
  final QuizArgs args;

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _quiz = quizProvider(Object());
  late final SpeechRecognitionService _stt;
  late final bool _usesRealStt;
  // Whisper engine (own capture + own endpointing) — app-lifetime via
  // provider; the model is heavy. Initialized in initState: a lazy `late`
  // here would first resolve in dispose(), where ref is no longer usable.
  late final WhisperSpeechService _whisper;
  late final ElevenLabsSpeechService _elevenLabs;
  final _answerCtrl = TextEditingController();
  final _typingFieldKey = GlobalKey();
  AudioDirector? _sessionDirector;
  SharedPcmCapture? _sharedCapture;
  // Race adapters, created lazily on first race use. They WRAP this screen's
  // existing service instances — never disposed here (the services' own
  // lifecycles are unchanged; see dispose()).
  SystemSttEngine? _raceSystemEngine;
  SystemSttEngine? _systemModeEngine;
  WhisperSttEngine? _raceWhisperEngine;
  ElevenLabsSttEngine? _raceElevenLabsEngine;
  // The phone's recognizer fed with OUR recording (Android 13+ bridge).
  PhoneSttEngine? _racePhoneEngine;

  /// Engines ranked best-first; each attempt activates the best available
  /// ones (see [SttEngineRegistry.select]).
  SttEngineRegistry? _sttRegistry;

  /// The listen attempt in progress. Cancelled whenever a new turn starts,
  /// the card changes or the session pauses, so its timers can never cut
  /// the NEXT attempt's mic (field log 2026-10-02: a stale timer closed a
  /// fresh window 38ms after it opened).
  SttRace? _activeRace;

  /// What the current attempt is doing — drives the cue line and the engine
  /// chips (user feedback 2026-10-02: "je sais pas si ça écoute, si ça
  /// analyse, si ça envoie").
  SttRaceStatus? _sttStatus;
  bool _sttOnline = true;

  // Incremented every time _startListening is called; onListeningDone
  // only acts if the token still matches.
  int _listenToken = 0;
  // Voice "Clavier" escape: when equal to the current card index, that card
  // shows a text-input fallback instead of the mic.
  int? _voiceKbIndex;
  // Hands-free pause state.
  bool _hfPaused = false;
  late bool _appForeground;
  ModalRoute<Object?>? _quizRoute;
  ModalRoute<Object?>? _shellRoute;
  bool _foregroundApplied = true;
  bool get _canInteract =>
      _appForeground &&
      (_quizRoute?.isCurrent ?? true) &&
      (_shellRoute?.isCurrent ?? true);
  bool _quitting = false;
  bool _quitReady = false;
  bool _sessionStarted = false;
  Future<void>? _interruption;
  Future<void>? _hfCorrection;
  AudioDirector? _replacedPromptDirector;
  // Display-only: attempts consumed on the current card, fed by the
  // machine's ShowNotHeard command (the "essai x/3" banner).
  int _notHeardRetries = 0;
  bool _hfNotHeard = false;
  // Hands-free "analyse" phase: mic closed, answer captured, verdict pending.
  // Marked by a low closing tick + pulsing status text so the user knows to
  // stop talking (protocol spec, user request 2026-07-08).
  bool _hfAnalyzing = false;
  String? _hfFailureKey;
  // "3 · 2 · 1" before the mic opens (null = no countdown showing).
  int? _hfCountdown;
  // The "analysis started" bip plays once per listen attempt.
  bool _analysisBipPlayed = false;
  bool _hfAutoPausedSilence = false;
  // Flashcards are self-graded by a directional swipe. Keeping this state in
  // the screen (rather than in the quiz provider) makes the physical exit an
  // animation concern and leaves the stack anchored in one place.
  bool _flashcardExiting = false;
  int _flashcardExitDirection = 1;
  double _flashcardDragProgress = 0;
  // Listening-window countdown bar: fills left→right over the mic's
  // listenFor window; a full bar means the attempt timed out. Restarted on
  // every mic open (retries included).
  late final AnimationController _listenBarCtrl;

  @override
  void initState() {
    super.initState();
    final binding = WidgetsBinding.instance;
    final lifecycle = binding.lifecycleState;
    _appForeground =
        lifecycle == null || lifecycle == AppLifecycleState.resumed;
    binding.addObserver(this);
    _usesRealStt =
        !SttSimulator.isOn &&
        (widget.args.mode == QuizMode.handsFree ||
            widget.args.mode == QuizMode.voice);
    if (_usesRealStt) {
      _stt = ref.read(systemSpeechRecognitionProvider);
      _whisper = ref.read(whisperSpeechProvider);
      _elevenLabs = ref.read(elevenLabsSpeechProvider);
    }
    _listenBarCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _loadSession();
      if (!mounted || _quitting) return;
      if (_usesRealStt && _canInteract && ref.read(_quiz).currentCard != null) {
        final ok = await _stt.initialize();
        if (!mounted || _quitting) return;
        if (!ok && _canInteract) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('quiz.stt_unavailable'.tr()),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    });
  }

  Future<void> _loadSession() {
    _sessionStarted = true;
    _listenToken++;
    _cancelActiveRace();
    _turnMachine = null;
    _answerCtrl.clear();
    _hfPaused = false;
    _hfAutoPausedSilence = false;
    _hfNotHeard = false;
    _hfAnalyzing = false;
    _hfFailureKey = null;
    _hfCountdown = null;
    _voiceKbIndex = null;
    _flashcardExiting = false;
    _flashcardDragProgress = 0;
    _foregroundApplied = _canInteract;
    final quiz = ref.read(_quiz.notifier);
    final loading = quiz.loadCards(
      widget.args,
      promptLocale: uiLocaleCode(context),
    );
    quiz.setForeground(_foregroundApplied);
    return loading;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _listenToken++;
    _listenBarCtrl.dispose();
    _activeRace?.cancel();
    if (_sessionStarted && _foregroundApplied && !_quitting) {
      unawaited(_stopTurnResources(_sessionDirector));
    }
    _answerCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _quizRoute = ModalRoute.of(context);
    _shellRoute = context
        .dependOnInheritedWidgetOfExactType<_QuizRouteScope>()
        ?.route;
    // Apply provider changes outside build. Callbacks independently check the
    // actual route objects so a result cannot win during the transition frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncForeground();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appForeground = state == AppLifecycleState.resumed;
    _syncForeground();
  }

  void _syncForeground() {
    if (_quitting) {
      _finishQuitIfVisible();
      return;
    }
    if (!_sessionStarted || _canInteract == _foregroundApplied) {
      return;
    }
    _foregroundApplied = _canInteract;
    ref.read(_quiz.notifier).setForeground(_foregroundApplied);
    if (!_foregroundApplied) {
      unawaited(_interruptTurn());
    } else if (widget.args.mode == QuizMode.handsFree && !_hfPaused) {
      unawaited(_resumeHandsFree());
    }
  }

  Future<void> _interruptTurn() {
    _listenToken++; // every in-flight STT completion is now stale
    _hfCorrection = null;
    _cancelActiveRace();
    _listenBarCtrl.stop();
    setState(() {
      _hfAnalyzing = false;
      _hfFailureKey = null;
      _hfNotHeard = false;
      _hfCountdown = null;
    });
    ref.read(_quiz.notifier).setListening(false);
    return _interruption = _stopTurnResources(
      ref.read(audioDirectorProvider),
      pending: _interruption,
    );
  }

  /// Both capture modes must release before either can open on the next turn.
  /// The app-scoped services retain any unconfirmed native stop across routes.
  Future<void> _releaseTurnMicrophone() async {
    _raceSystemEngine?.detachSessionEnd();
    _systemModeEngine?.detachSessionEnd();
    final capture = _sharedCapture;
    await Future.wait<void>([
      if (capture != null)
        Future.sync(capture.stop).timeout(sttMicReleaseTimeout),
      if (_usesRealStt) _stt.stopListening(),
    ]);
  }

  /// Can run during disposal using cached services only.
  Future<void> _stopTurnResources(
    AudioDirector? director, {
    Future<void>? pending,
  }) async {
    try {
      await Future.wait<void>([
        ?pending,
        _releaseTurnMicrophone(),
        if (_usesRealStt) ...[
          Future.sync(_whisper.stopListening),
          Future.sync(_elevenLabs.stopListening),
        ],
        if (director != null) Future.sync(director.stopAll),
      ]);
    } catch (error) {
      sttLog('[QUIZ] audio or microphone stop failed: $error');
    }
  }

  Future<void> _resumeHandsFree({bool retryRelease = false}) async {
    final card = ref.read(_quiz).currentCard;
    if (card == null) return;
    final token = _listenToken;
    final pending = _interruption;
    if (pending != null) await pending;
    if (_turnStale(token, card)) return;
    await _readPromptAndListen(card, retryRelease: retryRelease);
  }

  /// Owns playback of the current hands-free prompt and waits for it before
  /// recognizer preflight, countdown and microphone hand-off can begin.
  Future<void> _readPromptAndListen(
    QuizCard card, {
    bool retryRelease = false,
  }) async {
    final token = _listenToken;
    bool stale() => _turnStale(token, card);
    if (stale()) return;
    if (!_kTestMode) {
      if (!await _playCurrentPrompt(card, stale, retryRelease: retryRelease)) {
        return;
      }
    }
    if (stale()) return;
    // Echo tail: let the room go quiet before the mic opens.
    await Future.delayed(const Duration(milliseconds: 250));
    if (stale()) return;
    sttLog('[HF] speech finished — calling _startListening');
    unawaited(_startListening(card));
  }

  Future<bool> _playCurrentPrompt(
    QuizCard card,
    bool Function() stale, {
    required bool retryRelease,
  }) async {
    var previousSpeech = _hfCorrection;
    _hfCorrection = null;
    while (!stale()) {
      final replaced = _replacedPromptDirector;
      if (replaced != null) {
        try {
          await replaced.waitForPlayerRelease(retry: retryRelease);
        } catch (error) {
          sttLog('[QUIZ] replaced prompt player release failed: $error');
          if (!stale()) _showReleaseFailure(audio: true);
          return false;
        }
        if (stale()) return false;
        _replacedPromptDirector = null;
      }
      retryRelease = false;

      final director = ref.read(audioDirectorProvider);
      final grammarPrompt = card.grammarAudioPrompt;
      final result = await (grammarPrompt == null
          ? director.speakVocabularyPrompt(
              word: card.questionWord,
              wordLang: card.direction.questionLang,
              audioPath: card.questionAudioPath,
              previousSpeech: previousSpeech,
              keepGoing: () => !stale(),
            )
          : director.speakGrammarPrompt(
              instruction: grammarPrompt.instruction,
              instructionLang: grammarPrompt.locale,
              word: grammarPrompt.word,
              wordLang: card.direction.answerLang,
              previousSpeech: previousSpeech,
              keepGoing: () => !stale(),
            ));
      if (stale()) return false;
      if (result == StudyPromptResult.completed) return true;
      if (result == StudyPromptResult.cancelled &&
          !identical(director, ref.read(audioDirectorProvider))) {
        _replacedPromptDirector = director;
        previousSpeech = null;
        continue;
      }
      setState(() => _hfFailureKey = 'quiz.grammar_prompt_failed');
      return false;
    }
    return false;
  }

  /// Serializes mic starts: multiple recovery paths (not-heard, stopped-too-
  /// fast, noise-guard) schedule delayed retries, and two firing close
  /// together used to start OVERLAPPING sessions — the second killed the
  /// first, spawning death events, another retry, and another of Samsung's
  /// own recognizer chimes ("1 to 3 bips" per card, field log 2026-07-07).
  int? _listenStartInFlight;

  /// Enters the hands-free "analyse" phase: the mic captured speech (or
  /// closed after a real listen) and the verdict is pending. Plays the low
  /// closing tick so the user knows to stop talking. Idempotent per phase —
  /// reset when a new listen or card starts.
  void _enterAnalyzing() {
    if (_hfAnalyzing || widget.args.mode != QuizMode.handsFree) return;
    _listenBarCtrl.stop(); // mic closed — freeze the countdown
    _playAnalysisBip();
    if (mounted) setState(() => _hfAnalyzing = true);
  }

  /// The bip that says "your answer is being analysed" — once per attempt,
  /// after the mic closes with a verdict still pending.
  void _playAnalysisBip() {
    if (_analysisBipPlayed || widget.args.mode != QuizMode.handsFree) return;
    _analysisBipPlayed = true;
    if (!_kTestMode) {
      unawaited(ref.read(audioDirectorProvider).playListenDone());
    }
  }

  /// A quick "3 · 2 · 1" so the learner knows exactly when to speak (user
  /// request 2026-10-02). Returns false when the turn went stale meanwhile.
  Future<bool> _runCountdown(bool Function() stale) async {
    if (widget.args.mode != QuizMode.handsFree || _kTestMode) return !stale();
    for (final n in const [3, 2, 1]) {
      if (stale()) return false;
      if (mounted) setState(() => _hfCountdown = n);
      HapticFeedback.selectionClick();
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
    if (stale()) return false;
    setState(() => _hfCountdown = null);
    return true;
  }

  Future<void> _startListening(QuizCard card) async {
    if (_turnStale(_listenToken, card)) return;
    if (_listenStartInFlight == _listenToken) {
      sttLog('[HF] _startListening skipped — another start is in flight');
      return;
    }
    final token = ++_listenToken;
    _listenStartInFlight = token;
    try {
      final pending = _interruption;
      if (pending != null) await pending;
      await _startListeningInner(card, token);
    } finally {
      if (_listenStartInFlight == token) _listenStartInFlight = null;
    }
  }

  /// Abandons the listen attempt in progress (see [_activeRace]).
  void _cancelActiveRace() {
    _activeRace?.cancel();
    _activeRace = null;
    if (_sttStatus != null && mounted) setState(() => _sttStatus = null);
  }

  /// Local-first pipeline: the registry prefers the ready phone recognizer
  /// or local decoders. Shared decoders consume the same recorded utterance;
  /// network decoders receive it only after local recognition fails. Every
  /// guess is validated inside [SttRace] against the card's accepted
  /// answers, the first match wins, and the card is graded EXACTLY once —
  /// the race returns a single outcome (this also structurally prevents the
  /// triple-grade >100% score bug of 2026-07-19).
  // The per-session turn machine (race mode). Owns grade-once, the
  // not-heard ladder, retry pacing and the consecutive-silence auto-pause —
  // one instance per screen so the silence streak spans the whole session.
  VoiceTurnMachine? _turnMachine;
  late bool _turnCourseMode;

  Future<void> _startRaceListening(
    QuizCard card,
    String langCode,
    int sessionToken,
    SttEngineMode mode,
  ) async {
    _raceSystemEngine ??= SystemSttEngine(_stt, onDevice: true);
    _systemModeEngine ??= SystemSttEngine(_stt, onDevice: false);
    _raceWhisperEngine ??= WhisperSttEngine(_whisper);
    _raceElevenLabsEngine ??= ElevenLabsSttEngine(_elevenLabs);
    _racePhoneEngine ??= PhoneSttEngine(
      const MethodChannelPhonePcmRecognizer(),
    );
    // Compatible shared decoders use one recording. The registry prefers that
    // lane when a local decoder is ready and otherwise can use the system mic.
    _sttRegistry ??= SttEngineRegistry()
      ..register(_raceElevenLabsEngine!)
      ..register(_racePhoneEngine!)
      ..register(_raceSystemEngine!)
      ..register(_raceWhisperEngine!);
    final courseMode = mode == SttEngineMode.race;
    await (courseMode ? _raceSystemEngine! : _systemModeEngine!).prepare();
    if (_turnStale(sessionToken, card)) return;
    if (courseMode) {
      await _racePhoneEngine!.prepare();
      if (_turnStale(sessionToken, card)) return;
    }
    // Whisper becomes available for local decoding once its model is ready;
    // kick the download in the background on first use. This is enabled
    // for debug APKs too: field tests must exercise the same hybrid pipeline
    // as the version we plan to ship.
    if (courseMode && !_whisper.isReady && !_kTestMode) {
      unawaited(_whisper.ensureModel());
    }

    // Schedule the attempt after prompt playback and audio hand-off. The
    // command handler preflights each lane before the actual countdown and cue.
    final m = _turnMachine ??= ref.read(voiceTurnMachineFactoryProvider)();
    _turnCourseMode = courseMode;
    m.on(TurnStarted(sessionToken));
    m.on(SlateClean(sessionToken));
    m.on(PromptFinished(sessionToken));
    await _runTurnCommands(m.on(CueFinished(sessionToken)), card, langCode);
  }

  void _showReleaseFailure({bool audio = false}) {
    _listenBarCtrl.stop();
    ref.read(_quiz.notifier).setListening(false);
    if (widget.args.mode == QuizMode.handsFree) {
      setState(() {
        _hfAnalyzing = false;
        _hfNotHeard = false;
        _hfFailureKey = audio
            ? 'quiz.audio_release_failed_hf'
            : 'quiz.mic_release_failed_hf';
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            (audio ? 'quiz.audio_release_failed' : 'quiz.mic_release_failed')
                .tr(),
          ),
        ),
      );
    }
  }

  /// True when the machine's turn no longer matches reality — unmounted, a
  /// newer listen session, another card, or a verdict already landed. The
  /// machine's own turn/terminal guards back this up.
  bool _turnStale(int turn, QuizCard card) {
    if (!mounted ||
        !_canInteract ||
        _hfPaused ||
        _quitting ||
        turn != _listenToken) {
      return true;
    }
    final quiz = ref.read(_quiz);
    return !identical(quiz.currentCard, card) ||
        quiz.isComplete ||
        (widget.args.mode == QuizMode.voice &&
            _voiceKbIndex == quiz.currentIndex) ||
        quiz.answerState != QuizAnswerState.idle;
  }

  /// Executes the machine's commands for race mode (step 4 of the
  /// voice-orchestration refactor): policy lives in [VoiceTurnMachine], this
  /// is pure mechanism.
  Future<void> _runTurnCommands(
    List<TurnCommand> cmds,
    QuizCard card,
    String langCode,
  ) async {
    final m = _turnMachine!;
    final turn = m.turn;
    if (_turnStale(turn, card)) return;
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
          ref.read(_quiz.notifier).setListening(false);
          if (widget.args.mode == QuizMode.handsFree) {
            if (mounted) {
              setState(() {
                _notHeardRetries = attempt; // "essai ${attempt+1}/max" banner
                _hfNotHeard = true;
                _hfAnalyzing = false; // retry prompt outranks "analyse"
              });
            }
          } else if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('quiz.stt_not_recognised'.tr()),
                duration: const Duration(seconds: 3),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        case WaitThenRetry(:final duration):
          // Voice mode has no auto-retry protocol — the user re-taps the mic
          // (a fresh turn supersedes this one).
          if (widget.args.mode != QuizMode.handsFree) break;
          Future.delayed(duration, () {
            if (_turnStale(turn, card)) return;
            unawaited(
              _runTurnCommands(m.on(WaitElapsed(turn)), card, langCode),
            );
          });
        case GradeCorrect(:final candidate):
          _listenBarCtrl.stop();
          sttLog('[RACE][HF] ✅ "$candidate" validated — grading correct');
          ref
              .read(_quiz.notifier)
              .submitVoiceAnswer(candidate, isDrivingMode: true);
        case GradeWrong(:final transcript):
          _listenBarCtrl.stop();
          sttLog('[RACE][HF] ❌ "$transcript" never validated — grading wrong');
          ref
              .read(_quiz.notifier)
              .submitVoiceAnswer(transcript, isDrivingMode: true);
        case SkipCard():
          _listenBarCtrl.stop();
          sttLog('[RACE][HF] ⏭ silence — skipping WITHOUT grading');
          ref.read(_quiz.notifier).setListening(false);
          ref.read(_quiz.notifier).skipCurrentCard();
        case PauseSession():
          sttLog('[RACE][HF] 🔇🔇 consecutive silent cards — auto-pausing');
          setState(() {
            _hfAutoPausedSilence = true;
            _hfPaused = true;
          });
          ref.read(_quiz.notifier).setPaused(true);
          unawaited(_interruptTurn());
      }
    }
  }

  /// One listen attempt. Outcomes go back to the machine for grading,
  /// retries, skipping or pausing.
  Future<void> _runRaceLanes(
    QuizCard card,
    String langCode, {
    required bool rescue,
  }) async {
    final m = _turnMachine!;
    final turn = m.turn;
    final userId = ref.read(currentUserProvider)?.id;
    bool stale() =>
        _turnStale(turn, card) || ref.read(currentUserProvider)?.id != userId;
    if (stale()) return;
    try {
      await _runRaceAttempt(card, langCode, m, stale, rescue: rescue);
    } catch (error) {
      sttLog('[QUIZ] voice attempt failed: $error');
      if (stale()) return;
      // The detached attempt may have reached native mic startup. Join
      // release before any retry can start, including a retry during cleanup.
      await (_interruption = _recoverRaceAttempt(stale));
    }
  }

  Future<bool> _raceNetworkAvailable() async {
    try {
      return !isOffline(await Connectivity().checkConnectivity());
    } catch (error) {
      sttLog('[QUIZ] connectivity unknown; using local speech engines: $error');
      return false;
    }
  }

  Future<void> _recoverRaceAttempt(bool Function() stale) async {
    _cancelActiveRace();
    _listenBarCtrl.stop();
    try {
      await _releaseTurnMicrophone();
    } catch (error) {
      sttLog('[QUIZ] failed attempt could not release the microphone: $error');
      if (!stale()) _showReleaseFailure();
      return;
    }
    if (!mounted || stale()) return;
    ref.read(_quiz.notifier).setListening(false);
    const key = 'quiz.voice_prepare_failed';
    if (widget.args.mode == QuizMode.handsFree) {
      setState(() {
        _hfCountdown = null;
        _hfAnalyzing = false;
        _hfNotHeard = false;
        _hfFailureKey = key;
      });
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(key.tr())));
    }
  }

  Future<void> _runRaceAttempt(
    QuizCard card,
    String langCode,
    VoiceTurnMachine m,
    bool Function() stale, {
    required bool rescue,
  }) async {
    final turn = m.turn;
    // System mode has no external speech service to check.
    final online = !_turnCourseMode || await _raceNetworkAvailable();
    if (stale()) return;
    final engines = _turnCourseMode
        ? _sttRegistry!.select(
            langCode: langCode,
            online: online,
            rescue: rescue,
          )
        : [if (_systemModeEngine!.isReady) _systemModeEngine!];
    final recorder =
        _sharedCapture ?? ref.read<SharedPcmCapture>(sharedPcmCaptureProvider);
    _sharedCapture = recorder;
    try {
      await _releaseTurnMicrophone();
    } catch (error) {
      sttLog('[HF] microphone release preflight failed: $error');
      if (!stale()) _showReleaseFailure();
      return;
    }
    if (stale()) return;
    final shared = engines.any(
      (engine) => engine.capture == SttCapture.sharedPcm,
    );
    final canOpen =
        engines.isNotEmpty && (!shared || await recorder.ensurePermission());
    if (stale()) return;
    if (!canOpen) {
      await _runTurnCommands(
        m.on(NothingHeard(turn, hadRealWindow: false)),
        card,
        langCode,
      );
      return;
    }

    // All lanes are ready before the learner hears the opening cue. The
    // microphone opens only after the cue has cleared.
    if (widget.args.mode == QuizMode.handsFree && !_kTestMode) {
      if (!await _runCountdown(stale)) return;
      if (stale()) return;
      HapticFeedback.selectionClick();
      try {
        await ref.read(audioDirectorProvider).listenCue();
      } catch (error) {
        sttLog('[QUIZ] opening cue failed: $error');
        if (!stale()) {
          setState(() => _hfFailureKey = 'quiz.listen_cue_failed');
        }
        return;
      }
      if (stale()) return;
    }

    m.on(MicOpened(turn));
    ref.read(_quiz.notifier).setListening(true);

    if (m.attempt == 0) {
      _prefetchFollowingCard(ref.read(_quiz).nextCard);
    }
    void runBar() {
      if (!_kTestMode) {
        _listenBarCtrl
          ..reset()
          ..forward();
      }
    }

    sttLog(
      '[RACE][HF] engines=${engines.map((e) => e.id).join("+")} '
      'online=$online turn=$turn attempt=${m.attempt} rescue=$rescue '
      'lang=$langCode',
    );
    _activeRace?.cancel(); // never two attempts alive at once
    final race = SttRace(engines, capture: shared ? recorder : null);
    _activeRace = race;
    _analysisBipPlayed = false;
    // User-tunable (Réglages → Temps d'écoute). The bar drains over exactly
    // this window, starting when the mic is really open.
    final listenWindow = Duration(
      seconds: ref.read(audioSettingsProvider).listenSeconds,
    );
    _listenBarCtrl
      ..stop()
      ..reset()
      ..duration = listenWindow;
    var barStarted = false;
    if (mounted) {
      setState(() {
        _sttOnline = online;
        _sttStatus = null;
      });
    }
    final outcome = await race.run(
      langCode: langCode,
      acceptedAnswers: card.answerWords,
      preserveGrammar: widget.args.source == QuizSource.grammar,
      promptHints: card.answerWords,
      // Shared capture: time to START answering — the window never cuts a
      // learner mid-word and awaits every analysis in flight. The phone
      // recognizer ends its own session after one utterance, so its window
      // is only an upper bound.
      timeout: listenWindow,
      restartOnSessionEnd: false,
      onStatus: (status) {
        if (!identical(_activeRace, race) || stale()) return;
        final micOpen =
            status.phase == SttPhase.listening ||
            status.phase == SttPhase.speaking;
        if (micOpen && !barStarted) {
          barStarted = true;
          runBar();
        }
        setState(() => _sttStatus = status);
      },
      onMicClosedPending: () {
        if (!identical(_activeRace, race) || stale()) return;
        unawaited(
          _runTurnCommands(m.micClosedPendingVerdict(turn), card, langCode),
        );
      },
      onPartial: (h) {
        if (!stale()) {
          ref.read(_quiz.notifier).setPartialTranscript(h.transcript);
        }
      },
    );
    if (identical(_activeRace, race)) _activeRace = null;
    if (outcome.cancelled || stale()) return;
    if (outcome.micReleaseFailed) {
      _showReleaseFailure();
      return;
    }
    final hadReal = outcome.hadRealSession;

    _listenBarCtrl.stop();
    final heard = outcome.bestTranscript;
    final TurnEvent verdictEvent = outcome.matched
        ? MatchHeard(turn, outcome.matchedCandidate!)
        : (heard != null && heard.trim().isNotEmpty)
        ? WrongHeard(turn, heard)
        : NothingHeard(turn, hadRealWindow: hadReal);
    await _runTurnCommands(m.on(verdictEvent), card, langCode);
  }

  Future<void> _startListeningInner(QuizCard card, int token) async {
    bool stale() => _turnStale(token, card);
    if (stale()) return;
    if (_hfNotHeard || _hfAnalyzing) {
      setState(() {
        _hfNotHeard = false;
        _hfAnalyzing = false;
      });
    }
    _cancelActiveRace(); // the previous attempt's timers must not touch this one
    sttLog(
      '[HF] _startListening  token=$token  question="${card.questionWord}"  answerWords=${card.answerWords}',
    );
    if (SttSimulator.isOn) {
      ref.read(_quiz.notifier).setListening(true);
      await Future.delayed(const Duration(milliseconds: 800));
      if (stale()) return;
      final answer = switch (SttSimulator.mode) {
        'correct' => card.answerWords.isNotEmpty ? card.answerWords.first : '',
        'wrong' => '__wrong__',
        _ => '',
      };
      ref
          .read(_quiz.notifier)
          .submitVoiceAnswer(
            answer,
            isDrivingMode:
                widget.args.mode == QuizMode.handsFree ||
                widget.args.mode == QuizMode.voice,
          );
      return;
    }

    final mode = await ref.read(sttEngineModeProvider.notifier).restored;
    if (stale()) return;

    // Wait for the question player to stop, then let Android settle the audio
    // route before STT grabs the mic. A fire-and-forget stop let late TTS
    // buffers overlap the first recognition frames on Samsung.
    sttLog('[HF] Triggering audio stop + verified focus-handover wait');
    try {
      await ref.read(audioDirectorProvider).handOffToMic();
    } catch (error) {
      sttLog('[HF] audio release failed: $error');
      if (!stale()) _showReleaseFailure(audio: true);
      return;
    }
    if (stale()) return;

    // Refactor 4c: EVERY voice turn — vocab AND grammar — runs on the
    // VoiceTurnMachine. Système is a system-only lane, Course adds the
    // offline Whisper lane. The legacy streaming path is gone; grammar's
    // short generated answers grade exactly like vocab through the race.
    await _startRaceListening(card, card.direction.answerLang, token, mode);
  }

  /// Warm the following voice and cache its clips while the learner answers.
  void _prefetchFollowingCard(QuizCard? card) {
    if (card == null || card.grammarAudioPrompt != null || _kTestMode) return;
    final audio = ref.read(audioPlayerServiceProvider);
    unawaited(audio.warmUp(card.progress.direction.questionLang));
    unawaited(
      audio.prefetch(
        card.questionWord,
        card.progress.direction.questionLang,
        audioPath: card.questionAudioPath,
      ),
    );
    if (card.answerWords.isNotEmpty) {
      unawaited(
        audio.prefetch(
          card.answerWords.first,
          card.progress.direction.answerLang,
          audioPath: card.answerAudioPath,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final quizState = ref.watch(_quiz);
    _sessionDirector = ref.watch(audioDirectorProvider);

    ref.listen(currentUserProvider.select((user) => user?.id), (_, _) {
      if (!_quitting && _foregroundApplied) unawaited(_interruptTurn());
    });
    ref.listen<QuizState>(_quiz, (prev, next) {
      if (_canInteract &&
          prev?.answerState == QuizAnswerState.idle &&
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
        final shouldSpeak =
            !_kTestMode &&
            shouldSpeakAnswer(widget.args.mode, correct: correct);
        if (shouldSpeak) {
          final card = next.currentCard;
          if (card != null && card.answerWords.isNotEmpty) {
            final answerLang = card.progress.direction.answerLang;
            final handsFree = widget.args.mode == QuizMode.handsFree;
            final speech = ref
                .read(audioDirectorProvider)
                .speak(
                  card.answerWords.first,
                  answerLang,
                  audioPath: card.answerAudioPath,
                  requirePlayback: handsFree,
                )
                .catchError((Object error) {
                  sttLog('[QUIZ] correction playback failed: $error');
                });
            if (handsFree) _hfCorrection = speech;
            unawaited(speech);
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
        final cardsJustAppeared =
            !justLoaded &&
            (prev?.cards.isEmpty ?? true) &&
            next.cards.isNotEmpty;
        final card = next.currentCard;
        if ((cardChanged || justLoaded || cardsJustAppeared) &&
            card != null &&
            !next.isComplete) {
          sttLog(
            '[HF] Card trigger: cardChanged=$cardChanged justLoaded=$justLoaded cardsJustAppeared=$cardsJustAppeared  idx=${next.currentIndex}  question="${card.questionWord}"  answers=${card.answerWords}',
          );
          // Invalidate the previous card's session NOW: a session left open
          // across the transition hears the new card's TTS question and
          // grades it against the old card (field log 2026-07-06 — "mouton"
          // spoken by the app's own voice failed the 양 card).
          _listenToken++;
          _cancelActiveRace();
          if (_usesRealStt &&
              (_stt.isListening ||
                  _whisper.isListening ||
                  _elevenLabs.isListening)) {
            sttLog('[HF] stopping stale listen session from previous card');
            unawaited(_stopTurnResources(null));
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
          if (_hfAnalyzing ||
              _hfFailureKey != null ||
              _hfNotHeard ||
              _hfCountdown != null) {
            setState(() {
              _hfAnalyzing = false;
              _hfFailureKey = null;
              _hfNotHeard = false;
              _hfCountdown = null;
            });
          }
          unawaited(_readPromptAndListen(card));
        }
      }
    });

    if (!_sessionStarted || quizState.isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: AppColors.clay,
            strokeWidth: 2,
          ),
        ),
      );
    }

    if (quizState.errorMessage case final error?) {
      final key = switch (error) {
        _ when error == 'quiz.account_changed'.tr() => 'quiz.account_changed',
        _ when error == 'grammar.written_only'.tr() => 'grammar.written_only',
        _ => 'quiz.load_failed',
      };
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 48,
                    color: AppColors.rose,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    key.tr(),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _quit,
                    child: Text('common.back'.tr()),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (quizState.isEmpty) {
      return Scaffold(
        body: SafeArea(
          child: ScrollAffordance(
            hint: 'v3.scroll_hint'.tr(),
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.inbox_outlined, size: 48),
                const SizedBox(height: 16),
                Text(
                  'quiz.no_cards_available'.tr(),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _loadSession,
                  child: Text('common.retry'.tr()),
                ),
                TextButton(onPressed: _quit, child: Text('common.back'.tr())),
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
        onDone: _quit,
        onRestart: _loadSession,
      );
    }

    final card = quizState.currentCard;
    if (card == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: AppColors.clay,
            strokeWidth: 2,
          ),
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
    ref.read(_quiz.notifier).setPaused(_hfPaused);
    if (_hfPaused) {
      unawaited(_interruptTurn());
    } else {
      // Manual resume = the user says the environment is OK again.
      _turnMachine?.resetSilenceStreak();
      unawaited(_resumeHandsFree());
    }
  }

  void _hfRepeat() {
    unawaited(_interruptTurn());
    unawaited(_resumeHandsFree(retryRelease: true));
  }

  Future<void> _hfSkip() async {
    // A deliberate skip is not a wrong answer: nothing is graded, the card
    // returns later in the session.
    final card = ref.read(_quiz).currentCard;
    if (card == null) return;
    final stopped = _interruptTurn();
    final token = _listenToken;
    await stopped;
    if (_turnStale(token, card)) return;
    ref.read(_quiz.notifier).skipCurrentCard();
  }

  /// Hands-free (Mains libres) — eyes-off canvas: word in the wave with the
  /// audio-I/O state machine (frozen + screen-pulse while reading vs animated
  /// while listening), oversized Répéter/Passer, tap-centre to pause, and the
  /// transient full-screen flood for grading.
  Widget _buildHandsFreeStudy(
    BuildContext context,
    QuizState s,
    QuizCard card,
  ) {
    final questionIsHangul = Languages.usesHangul(
      card.progress.direction.questionLang,
    );
    final answerIsHangul = Languages.usesHangul(
      card.progress.direction.answerLang,
    );

    if (s.answerState != QuizAnswerState.idle) {
      final correct = s.answerState == QuizAnswerState.correct;
      return StudyFeedbackFlood(
        isCorrect: correct,
        label: correct
            ? 'quiz.feedback_correct'.tr()
            : 'quiz.feedback_wrong'.tr(),
        answer: correct ? null : card.answerWords.join(' / '),
        answerIsKorean: answerIsHangul,
        // No onContinue → transient; the provider auto-advances (driving mode).
      );
    }

    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final listening = s.isListening && !_hfPaused;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final foreground = dark ? V3Colors.inkLight : V3Colors.ink;
    final muted = dark ? V3Colors.inkLight70 : V3Colors.ink60;
    final rule = dark ? V3Colors.ruleDark : V3Colors.edge2;

    // What to tell the learner — see hfCueFor for the sequence and its
    // priorities (user requests 2026-10-02).
    final phase = _sttStatus?.phase;
    final hfCue = hfCueFor(
      paused: _hfPaused,
      countdown: _hfCountdown,
      micRequested: listening,
      phase: phase,
      verdictPending: _hfAnalyzing,
      notHeard: _hfNotHeard,
    );
    final micLive = hfBarVisible(
      paused: _hfPaused,
      countdown: _hfCountdown,
      micRequested: listening,
      phase: phase,
      verdictPending: _hfAnalyzing,
    );
    final langName = 'lang.${_answerLangCode(card)}'.tr();
    final cue = switch (hfCue) {
      HfCue.none => null,
      HfCue.reading => 'quiz.hf_reading'.tr(),
      HfCue.countdown => 'quiz.stt_get_ready'.tr(),
      HfCue.opening => 'quiz.stt_opening'.tr(),
      HfCue.listening => 'quiz.stt_listening'.tr(namedArgs: {'lang': langName}),
      HfCue.hearing => 'quiz.stt_hearing'.tr(),
      HfCue.analyzing => 'quiz.hf_analyzing'.tr(),
      HfCue.notHeard => 'quiz.hf_not_heard_retry'.tr(
        namedArgs: {'attempt': '${_notHeardRetries + 1}', 'total': '3'},
      ),
    };
    final accent = dark ? V3Colors.amber : V3Colors.terraInk;
    final cueColor = micLive || hfCue == HfCue.countdown ? accent : muted;

    final failure = _hfFailureKey;
    return V3StudyScaffold(
      remaining: (s.displayTotal - s.position + 1).clamp(1, s.displayTotal),
      onQuit: _quit,
      child: _hfPaused
          ? _buildPausedHandsFree(foreground)
          : Stack(
              children: [
                if (hfCue == HfCue.reading && failure == null && _canInteract)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: reduceMotion || _kTestMode
                          ? _ReadingGlow(progress: 0.5)
                          : const _ReadingPulse(),
                    ),
                  ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final textScale =
                        MediaQuery.textScalerOf(context).scale(16) / 16;
                    final short = constraints.maxHeight < 360 * textScale;
                    final prompt = Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: _toggleHfPause,
                          excludeFromSemantics: true,
                          child: WordInWave(
                            word: card.questionWord,
                            isKorean: questionIsHangul,
                            cue: failure == null ? cue : null,
                            wordColor: foreground,
                            cueColor: cueColor,
                            waveActive: micLive,
                          ),
                        ),
                        if (failure != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Semantics(
                              liveRegion: true,
                              child: Text(
                                failure.tr(),
                                style: V3Text.body(14, color: muted),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    );
                    final body = Column(
                      children: [
                        if (short)
                          prompt
                        else
                          Expanded(child: _ScrollablePrompt(child: prompt)),
                        if (_hfCountdown != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              '$_hfCountdown',
                              key: const ValueKey('hf_countdown'),
                              style: AppTextStyles.grotesk(
                                short ? 42 : 64,
                                FontWeight.w700,
                              ).copyWith(color: accent),
                            ),
                          ),
                        if (listening || !_sttOnline)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: SttStatusStrip(
                              status: _sttStatus,
                              online: _sttOnline,
                              labels: _sttLabels(),
                            ),
                          ),
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: micLive ? 1.0 : 0.0,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: AnimatedBuilder(
                              animation: _listenBarCtrl,
                              builder: (_, _) => ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: LinearProgressIndicator(
                                  value: 1 - _listenBarCtrl.value,
                                  minHeight: 5,
                                  backgroundColor: rule.withValues(alpha: 0.7),
                                  valueColor: AlwaysStoppedAnimation(accent),
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
                            const SizedBox(width: 12),
                            Expanded(
                              child: _HfButton(
                                key: const ValueKey(WidgetKeys.hfPause),
                                icon: Icons.pause_rounded,
                                label: 'quiz.hf_pause'.tr(),
                                onTap: _toggleHfPause,
                              ),
                            ),
                            const SizedBox(width: 12),
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
                    );
                    const padding = EdgeInsets.fromLTRB(24, 8, 24, 28);
                    if (short) {
                      return ScrollAffordance(
                        key: const ValueKey(WidgetKeys.quizPrompt),
                        hint: 'v3.scroll_hint'.tr(),
                        padding: padding,
                        fillViewport: true,
                        child: body,
                      );
                    }
                    return Padding(padding: padding, child: body);
                  },
                ),
              ],
            ),
    );
  }

  Widget _buildPausedHandsFree(Color foreground) => ScrollAffordance(
    hint: 'v3.scroll_hint'.tr(),
    padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
    fillViewport: true,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          _hfAutoPausedSilence
              ? Icons.hearing_disabled_rounded
              : Icons.pause_rounded,
          size: 56,
          color: foreground,
        ),
        const SizedBox(height: 10),
        Text(
          (_hfAutoPausedSilence ? 'quiz.hf_paused_silence' : 'quiz.hf_paused')
              .tr(),
          textAlign: TextAlign.center,
          style: AppTextStyles.grotesk(
            28,
            FontWeight.w700,
          ).copyWith(color: foreground),
        ),
        const SizedBox(height: 18),
        FilledButton(
          key: const ValueKey(WidgetKeys.hfResume),
          autofocus: true,
          onPressed: _toggleHfPause,
          child: Text('quiz.hf_resume'.tr(), textAlign: TextAlign.center),
        ),
      ],
    ),
  );

  Future<void> _quit() async {
    if (_quitting || !_canInteract) return;
    _quitting = true;
    ref.read(_quiz.notifier).setForeground(false);
    await _interruptTurn();
    if (!mounted) return;
    _quitReady = true;
    _finishQuitIfVisible();
  }

  void _finishQuitIfVisible() {
    if (!_quitReady || !_canInteract) return;
    _quitReady = false;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  // Answer language code for the current card. Derived from the legacy
  // QuizDirection enum; the generic-language-pairs task replaces this with the
  // list's target langCode.
  String _answerLangCode(QuizCard card) => card.progress.direction.answerLang;

  SttStatusLabels _sttLabels() => SttStatusLabels(
    engineName: (id) => switch (id) {
      'elevenlabs' => 'ElevenLabs',
      'whisper' => 'Whisper',
      'system' || 'phone' => 'quiz.stt_engine_system'.tr(),
      _ => id,
    },
    waiting: 'quiz.stt_engine_waiting'.tr(),
    sending: 'quiz.stt_engine_sending'.tr(),
    analyzing: 'quiz.stt_engine_analyzing'.tr(),
    empty: 'quiz.stt_engine_empty'.tr(),
    failed: 'quiz.stt_engine_failed'.tr(),
    offline: 'quiz.stt_offline'.tr(),
    noEngine: 'quiz.stt_no_engine'.tr(),
  );

  String? _nextReviewText(int? scheduledDays) => switch (scheduledDays) {
    null => null,
    0 => 'quiz.next_review_soon'.tr(),
    1 => 'quiz.next_review_tomorrow'.tr(),
    final days => 'quiz.next_review_in_days'.tr(namedArgs: {'days': '$days'}),
  };

  Future<void> _dismissFlashcard({required bool knew}) async {
    final quiz = ref.read(_quiz);
    if (_flashcardExiting ||
        _quitting ||
        !quiz.isFlipped ||
        quiz.answerState != QuizAnswerState.idle) {
      return;
    }
    setState(() {
      _flashcardExiting = true;
      _flashcardExitDirection = knew ? 1 : -1;
    });
    HapticFeedback.selectionClick();
    ref
        .read(_quiz.notifier)
        .gradeFlashcard(knew ? FsrsRating.good : FsrsRating.again);
    await Future<void>.delayed(const Duration(milliseconds: 460));
    if (!mounted || _quitting) return;
    final current = ref.read(_quiz);
    if (identical(current.currentCard, quiz.currentCard) &&
        current.currentIndex == quiz.currentIndex) {
      ref.read(_quiz.notifier).advance();
    }
    setState(() {
      _flashcardExiting = false;
      _flashcardDragProgress = 0;
    });
  }

  /// Cartes — one stable physical stack: tap to turn, swipe to peel away.
  Widget _buildCartesStudy(BuildContext context, QuizState s, QuizCard card) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final questionIsHangul = Languages.usesHangul(
      card.progress.direction.questionLang,
    );
    final answerIsHangul = Languages.usesHangul(
      card.progress.direction.answerLang,
    );

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
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: back || _flashcardExiting
              ? null
              : () => ref.read(_quiz.notifier).flipCard(),
          borderRadius: const BorderRadius.all(V3Radii.card),
          child: LayoutBuilder(
            builder: (context, constraints) => Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(
                primary: true,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          back ? 'v3.card_answer'.tr() : 'v3.card_take'.tr(),
                          textAlign: TextAlign.center,
                          style: V3Text.mono(12),
                        ),
                        const SizedBox(height: 26),
                        Text(
                          word,
                          textAlign: TextAlign.center,
                          style: wordIsKorean
                              ? V3Text.korean(40)
                              : V3Text.title(38),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          back
                              ? 'v3.card_grade_hint'.tr()
                              : 'quiz.card_flip_hint'.tr(),
                          textAlign: TextAlign.center,
                          style: V3Text.body(14, color: V3Colors.ink60),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
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
                      height: math.min(380, constraints.maxHeight),
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
                                        : velocity > 0,
                                  ),
                                );
                              },
                        child: V3CardStack(
                          remaining: (s.displayTotal - s.position + 1).clamp(
                            1,
                            s.displayTotal,
                          ),
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
            if (showBack) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: const ValueKey(WidgetKeys.gradeAgain),
                      onPressed: _flashcardExiting
                          ? null
                          : () => unawaited(_dismissFlashcard(knew: false)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: dark
                            ? V3Colors.inkLight
                            : V3Colors.ink,
                        backgroundColor: dark
                            ? V3Colors.block
                            : V3Colors.paperPanel,
                        side: BorderSide(
                          color: dark ? V3Colors.ruleDark : V3Colors.edge2,
                        ),
                      ),
                      child: Text(
                        'v3.card_again'.tr(),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      key: const ValueKey(WidgetKeys.gradeKnew),
                      onPressed: _flashcardExiting
                          ? null
                          : () => unawaited(_dismissFlashcard(knew: true)),
                      child: Text(
                        'v3.card_knew'.tr(),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Écrire — word-in-wave + native text input + Valider, with the flood.
  Widget _buildEcrireStudy(BuildContext context, QuizState s, QuizCard card) {
    final questionIsHangul = Languages.usesHangul(
      card.progress.direction.questionLang,
    );
    final answerIsHangul = Languages.usesHangul(
      card.progress.direction.answerLang,
    );

    if (s.answerState != QuizAnswerState.idle) {
      final correct = s.answerState == QuizAnswerState.correct;
      return StudyFeedbackFlood(
        isCorrect: correct,
        onPlayAudio: card.answerWords.isEmpty
            ? null
            : () => unawaited(
                ref
                    .read(audioPlayerServiceProvider)
                    .speak(
                      card.answerWords.first,
                      card.progress.direction.answerLang,
                      audioPath: card.answerAudioPath,
                    ),
              ),
        label: correct
            ? 'quiz.feedback_correct'.tr()
            : 'quiz.feedback_wrong'.tr(),
        answer: card.answerWords.join(' / '),
        answerIsKorean: answerIsHangul,
        detail: _nextReviewText(s.scheduledDays),
        continueLabel: 'quiz.continue_button'.tr(),
        onContinue: () => ref.read(_quiz.notifier).advance(),
      );
    }

    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final cue = 'quiz.write_in_lang'.tr(
      namedArgs: {'lang': 'lang.${_answerLangCode(card)}'.tr()},
    );
    final cueColor = isDark ? AppColors.clayLight : AppColors.clayDeep;

    void submit() {
      ref.read(_quiz.notifier).submitTextAnswer(_answerCtrl.text);
      _answerCtrl.clear();
    }

    final prompt = WordInWave(
      word: card.questionWord,
      isKorean: questionIsHangul,
      cue: cue,
      cueColor: cueColor,
      waveActive: false,
    );
    // Retain the editable element and its keyboard connection when the inset
    // switches this layout between its anchored and scrolling controls.
    final input = KeyedSubtree(
      key: _typingFieldKey,
      child: TextField(
        key: const ValueKey(WidgetKeys.ecrireInput),
        controller: _answerCtrl,
        autofocus: true,
        textAlign: TextAlign.center,
        textInputAction: TextInputAction.done,
        cursorColor: AppColors.clay,
        style: AppTextStyles.fig(
          22,
          FontWeight.w600,
        ).copyWith(color: cs.onSurface),
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
    );
    final validate = FilledButton(
      key: const ValueKey(WidgetKeys.ecrireValidate),
      onPressed: submit,
      child: Text('quiz.validate'.tr()),
    );

    return StudyScaffold(
      current: s.position,
      total: s.displayTotal,
      counterOverride: s.inReviewTail
          ? 'quiz.review_tail'.tr(
              namedArgs: {'n': '${s.reviewPosition}', 'm': '${s.reviewTotal}'},
            )
          : null,
      onQuit: _quit,
      child: _KeyboardStudyLayout(
        prompt: prompt,
        input: input,
        validate: validate,
      ),
    );
  }

  /// Voix — the unified dark study canvas: word-in-wave + mic + escape pills,
  /// with the full-screen flood once answered.
  Widget _buildVoiceStudy(BuildContext context, QuizState s, QuizCard card) {
    final questionIsHangul = Languages.usesHangul(
      card.progress.direction.questionLang,
    );
    final answerIsHangul = Languages.usesHangul(
      card.progress.direction.answerLang,
    );

    if (s.answerState != QuizAnswerState.idle) {
      final correct = s.answerState == QuizAnswerState.correct;
      return StudyFeedbackFlood(
        isCorrect: correct,
        label: correct
            ? 'quiz.feedback_correct'.tr()
            : 'quiz.feedback_wrong'.tr(),
        answer: card.answerWords.join(' / '),
        answerIsKorean: answerIsHangul, // answer is Korean when FR→KO
        detail: _nextReviewText(s.scheduledDays),
        continueLabel: 'quiz.continue_button'.tr(),
        onContinue: () => ref.read(_quiz.notifier).advance(),
      );
    }

    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final cue = 'quiz.say_in_lang'.tr(
      namedArgs: {'lang': 'lang.${_answerLangCode(card)}'.tr()},
    );
    final cueColor = isDark ? AppColors.clayLight : AppColors.clayDeep;
    final kbOn = _voiceKbIndex == s.currentIndex;
    final prompt = WordInWave(
      word: card.questionWord,
      isKorean: questionIsHangul,
      cue: kbOn ? null : cue,
      cueColor: cueColor,
      waveActive: s.isListening,
    );
    void submit() {
      ref.read(_quiz.notifier).submitTextAnswer(_answerCtrl.text);
      _answerCtrl.clear();
    }

    return StudyScaffold(
      current: s.position,
      total: s.displayTotal,
      counterOverride: s.inReviewTail
          ? 'quiz.review_tail'.tr(
              namedArgs: {'n': '${s.reviewPosition}', 'm': '${s.reviewTotal}'},
            )
          : null,
      onQuit: _quit,
      child: kbOn
          ? _KeyboardStudyLayout(
              prompt: prompt,
              input: KeyedSubtree(
                key: _typingFieldKey,
                child: TextField(
                  key: const ValueKey(WidgetKeys.voiceInput),
                  controller: _answerCtrl,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    hintText: 'quiz.typing_hint'.tr(),
                  ),
                  onSubmitted: (_) => submit(),
                ),
              ),
              validate: FilledButton(
                key: const ValueKey(WidgetKeys.voiceValidate),
                onPressed: submit,
                child: Text('quiz.validate'.tr()),
              ),
            )
          : ScrollAffordance(
              key: const ValueKey(WidgetKeys.quizPrompt),
              hint: 'v3.scroll_hint'.tr(),
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
              fillViewport: true,
              child: Column(
                children: [
                  Expanded(child: prompt),
                  if (s.isListening || !_sttOnline)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SttStatusStrip(
                        status: _sttStatus,
                        online: _sttOnline,
                        labels: _sttLabels(),
                      ),
                    ),
                  if (s.partialTranscript.isNotEmpty) ...[
                    Text(
                      s.partialTranscript,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.fig(16, FontWeight.w500).copyWith(
                        color: isDark ? AppColors.onDarkMuted : AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  MicButton(
                    key: const ValueKey(WidgetKeys.micButton),
                    label: 'quiz.voice_start_microphone'.tr(),
                    isListening: s.isListening,
                    answerState: s.answerState,
                    onTap: () => _startListening(card),
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      _EscapePill(
                        key: const ValueKey(WidgetKeys.voiceReveal),
                        icon: Icons.visibility_outlined,
                        label: 'quiz.voice_reveal'.tr(),
                        onTap: () => unawaited(_revealVoiceAnswer(card)),
                      ),
                      _EscapePill(
                        key: const ValueKey(WidgetKeys.voiceKeyboard),
                        icon: Icons.keyboard_outlined,
                        label: 'quiz.voice_keyboard'.tr(),
                        onTap: () {
                          setState(() => _voiceKbIndex = s.currentIndex);
                          unawaited(_interruptTurn());
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Future<void> _revealVoiceAnswer(QuizCard card) async {
    final stopped = _interruptTurn();
    final token = _listenToken;
    await stopped;
    if (_turnStale(token, card)) return;
    ref.read(_quiz.notifier).submitVoiceAnswer('');
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
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        foregroundColor: fg,
        backgroundColor: cs.surfaceContainerHighest.withValues(
          alpha: isDark ? 0.5 : 0.7,
        ),
        shape: const StadiumBorder(),
        side: BorderSide(color: cs.outline),
        textStyle: AppTextStyles.fig(13, FontWeight.w600),
      ),
      icon: Icon(icon, size: 16),
      label: Text(label, textAlign: TextAlign.center),
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

/// A short prompt stays centred. The scrollbar appears when a long prompt or
/// larger system text needs more room, leaving the answer controls in place.
class _ScrollablePrompt extends StatelessWidget {
  const _ScrollablePrompt({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Scrollbar(
      thumbVisibility: true,
      child: SingleChildScrollView(
        key: const ValueKey(WidgetKeys.quizPrompt),
        primary: true,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(child: child),
        ),
      ),
    ),
  );
}

class _ReadingPulse extends StatefulWidget {
  const _ReadingPulse();

  @override
  State<_ReadingPulse> createState() => _ReadingPulseState();
}

class _ReadingPulseState extends State<_ReadingPulse>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1900),
  )..repeat(reverse: true);

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _pulse,
    builder: (_, _) => _ReadingGlow(progress: _pulse.value),
  );

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }
}

class _ReadingGlow extends StatelessWidget {
  const _ReadingGlow({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: RadialGradient(
        radius: 1.1,
        colors: [
          AppColors.clay.withValues(alpha: 0.04 + 0.10 * progress),
          Colors.transparent,
        ],
      ),
    ),
  );
}

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
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surface = dark ? V3Colors.block : V3Colors.paperPanel;
    final foreground = dark ? V3Colors.inkLight : V3Colors.ink;
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: foreground,
        backgroundColor: surface,
        minimumSize: const Size(0, 104),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide(color: dark ? V3Colors.ruleDark : V3Colors.edge2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 32),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.fig(15, FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// Keeps keyboard actions anchored when they fit and scrolls the entire body
/// when the keyboard or text scaling takes away that space.
class _KeyboardStudyLayout extends StatelessWidget {
  const _KeyboardStudyLayout({
    required this.prompt,
    required this.input,
    required this.validate,
  });
  final Widget prompt;
  final Widget input;
  final Widget validate;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scaledInputText = MediaQuery.textScalerOf(context).scale(22);
      final stackedControls = [
        input,
        const SizedBox(height: 18),
        SizedBox(width: double.infinity, child: validate),
      ];
      if (constraints.maxHeight < 148 + scaledInputText) {
        return ScrollAffordance(
          key: const ValueKey(WidgetKeys.quizPrompt),
          hint: 'v3.scroll_hint'.tr(),
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
          child: Column(
            children: [
              prompt,
              const SizedBox(height: 12),
              if (constraints.maxWidth >= 420)
                Row(
                  children: [
                    Expanded(flex: 2, child: input),
                    const SizedBox(width: 12),
                    Expanded(child: validate),
                  ],
                )
              else
                ...stackedControls,
            ],
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
        child: Column(
          children: [
            Expanded(child: _ScrollablePrompt(child: prompt)),
            ...stackedControls,
          ],
        ),
      );
    },
  );
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
    final dark = Theme.of(context).brightness == Brightness.dark;
    final foreground = dark ? V3Colors.inkLight : V3Colors.ink;
    final muted = dark ? V3Colors.inkLight70 : V3Colors.ink60;
    final surface = dark ? V3Colors.block : V3Colors.paperPanel;
    final accent = dark ? V3Colors.amber : V3Colors.terraInk;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );
    const padding = EdgeInsets.symmetric(vertical: 12, horizontal: 8);
    const buttonSize = Size(0, 52);

    return Scaffold(
      key: const ValueKey(WidgetKeys.summary),
      backgroundColor: dark ? V3Colors.app : V3Colors.paper,
      body: V3Pond(
        child: SafeArea(
          child: Center(
            child: ScrollAffordance(
              hint: 'v3.scroll_hint'.tr(),
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  VkWaveform(
                    height: 72,
                    barWidth: 8,
                    gap: 5,
                    isAnimating: isGreat,
                    opacity: isGreat ? 1.0 : 0.4,
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'quiz.summary_label'.tr(),
                    style: V3Text.mono(12, color: muted),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '$pct %',
                    style: V3Text.title(
                      64,
                      color: isGreat ? accent : foreground,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'quiz.summary_correct_count'.tr(
                      namedArgs: {
                        'correct': correct.toString(),
                        'total': total.toString(),
                      },
                    ),
                    style: AppTextStyles.fig(
                      16,
                      FontWeight.w500,
                    ).copyWith(color: muted),
                  ),
                  const SizedBox(height: 48),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          key: const ValueKey(WidgetKeys.summaryRestart),
                          onPressed: onRestart,
                          style: OutlinedButton.styleFrom(
                            minimumSize: buttonSize,
                            padding: padding,
                            shape: shape,
                            backgroundColor: surface,
                            foregroundColor: foreground,
                            side: BorderSide(
                              color: dark ? V3Colors.ruleDark : V3Colors.edge2,
                            ),
                          ),
                          child: Text(
                            'quiz.summary_restart'.tr(),
                            textAlign: TextAlign.center,
                            style: AppTextStyles.fig(14, FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          key: const ValueKey(WidgetKeys.summaryDone),
                          onPressed: onDone,
                          style: FilledButton.styleFrom(
                            minimumSize: buttonSize,
                            padding: padding,
                            shape: shape,
                            backgroundColor: V3Colors.terra,
                            foregroundColor: Colors.white,
                          ),
                          child: Text(
                            (context.canPop()
                                    ? 'common.back'
                                    : 'quiz.summary_home')
                                .tr(),
                            textAlign: TextAlign.center,
                            style: AppTextStyles.fig(14, FontWeight.w700),
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
      ),
    );
  }
}
