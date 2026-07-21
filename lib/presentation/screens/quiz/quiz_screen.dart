import 'dart:async' show unawaited;
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/quiz/quiz_provider.dart';
import '../../providers/audio/audio_provider.dart';
import '../../../domain/usecases/quiz/get_due_cards_usecase.dart'
    show QuizSource;
import '../../../core/languages.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/stt_simulator.dart';
import '../../../core/utils/answer_validator.dart';
import '../../../core/utils/stt_debug_log.dart';
import '../../../core/utils/fsrs_algorithm.dart';
import '../../../core/widget_keys.dart';
import '../../../services/speech/speech_recognition_service.dart';
import '../../../services/speech/whisper_speech_service.dart';
import '../../../services/speech/stt_race.dart';
import '../../../services/speech/system_stt_engine.dart';
import '../../../services/speech/whisper_stt_engine.dart';
import '../../providers/settings/stt_engine_mode_provider.dart';
import '../../providers/speech/whisper_speech_provider.dart';
import '../../../services/audio/sound_effects_service.dart';
import '../../widgets/dotted_ground.dart';
import '../../widgets/vk_waveform.dart';
import '../../widgets/mic_button.dart';
import '../../widgets/study/study_scaffold.dart';
import '../../widgets/study/word_in_wave.dart';
import '../../widgets/study/study_feedback_flood.dart';

// Under test, animations are frozen so Patrol's pumpAndSettle actually settles
// (a perpetual ticker on any study screen otherwise makes every action wait out
// the settle timeout and intermittently trips mid-layout binding assertions).
const _kTestMode = bool.fromEnvironment('TEST_MODE');

// Hands-free engine priority. Field evidence 2026-07-19 (device logs): the
// platform recognizer nailed "un thé" @0.93 in ~2s while Whisper produced
// garbage over 8-16s and only ran as rescue #2 (~17s in). So the system
// recognizer is now PRIMARY in hands-free too (voice mode already was); Whisper
// returns as a proper parallel racer via the SttRace framework (next step).
// Flip back to true to restore the 2026-07-09 Whisper-primary behaviour.
bool _handsFreeWhisperPrimary = false;

class QuizScreen extends ConsumerStatefulWidget {
  const QuizScreen({super.key, required this.args});
  final QuizArgs args;

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen>
    with TickerProviderStateMixin {
  final _stt = SpeechRecognitionService();
  final _sfx = SoundEffectsService();
  // Whisper engine (own capture + own endpointing) — app-lifetime via
  // provider; the model is heavy. Initialized in initState: a lazy `late`
  // here would first resolve in dispose(), where ref is no longer usable.
  late final WhisperSpeechService _whisper;
  final _answerCtrl = TextEditingController();
  // Guards against stale STT callbacks firing on a new card.
  // True while the current listen session is managed by the SttRace pipeline
  // (Settings → Moteur vocal → Course). The legacy _stt callbacks
  // (onListeningDone / onError retry ladder) must stand down for race-managed
  // sessions — the race owns timeout, fallback and grading.
  bool _raceActive = false;

  // Race adapters, created lazily on first race use. They WRAP this screen's
  // existing service instances — never disposed here (the services' own
  // lifecycles are unchanged; see dispose()).
  SystemSttEngine? _raceSystemEngine;
  WhisperSttEngine? _raceWhisperEngine;

  // Incremented every time _startListening is called; onListeningDone
  // only acts if the token still matches.
  int _listenToken = 0;
  // Tracks successive early-termination retries to avoid infinite loops.
  int _listenRetries = 0;
  // Voice "Clavier" escape: when equal to the current card index, that card
  // shows a text-input fallback instead of the mic.
  int? _voiceKbIndex;
  // Hands-free pause state.
  bool _hfPaused = false;
  // Hands-free "pas entendu" recovery: re-listen up to twice before requeuing.
  int _notHeardRetries = 0;
  bool _hfNotHeard = false;
  // Hands-free "analyse" phase: mic closed, answer captured, verdict pending.
  // Marked by a low closing tick + pulsing status text so the user knows to
  // stop talking (protocol spec, user request 2026-07-08).
  bool _hfAnalyzing = false;
  // Hands-free app-audio pickup guard: wrong results arriving implausibly
  // fast are discarded and the mic re-listens (max twice per card).
  int _noiseRetries = 0;
  // Hands-free "je n'ai pas compris" prompt: a captured utterance came
  // back as junk/borderline — the mic reopens and the user should repeat.
  // Distinct from not-heard (which means NO speech was captured at all).
  bool _hfMisheard = false;
  int _misheardRetries = 0;
  // Consecutive low-score (clearly-wrong) transcripts on the current card —
  // grading wrong requires two (garbage-transcription protection).
  int _lowScoreStrikes = 0;
  // A borderline transcript was seen on this card: probably a garbled
  // CORRECT answer — strikes may not grade the card wrong anymore.
  bool _sawBorderline = false;
  // Whisper window generation: repeat prompts re-arm a fresh 10s window
  // (aligned with the restarted countdown bar); stale timers no-op.
  int _whisperWindowGen = 0;
  // Armed by the not-heard ladder for the LAST retry of a vocab card:
  // that attempt runs on the SYSTEM recognizer as a rescue — a second
  // opinion with different failure modes than the Whisper primary.
  bool _systemRescueAttempt = false;
  // Cards in a row that ended with zero usable speech. At 2 the session
  // auto-pauses (the room is too loud / mic broken) instead of skipping
  // through every card. Reset by any real recognition or manual resume.
  int _consecutiveSilentCards = 0;
  bool _hfAutoPausedSilence = false;
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
    _listenBarCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 10));
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Constrained-engine models (vocab hands-free only): download/load in
      // the background; per-card routing checks isReady and falls back to
      // the system recognizer until then. First run downloads ~40-80MB per
      // language over the network.
      if (_handsFreeWhisperPrimary &&
          widget.args.mode == QuizMode.handsFree &&
          widget.args.source != QuizSource.grammar &&
          !SttSimulator.isOn &&
          !_kTestMode) {
        unawaited(_whisper.ensureModel()); // one multilingual model
      }
      if (!SttSimulator.isOn) {
        final ok = await _stt.initialize();
        if (!ok && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('quiz.stt_unavailable'.tr()),
            behavior: SnackBarBehavior.floating,
          ));
        }
      }
      // Real hardware/network errors (not error_no_match, which is normal
      // "no speech recognised" and is handled by onListeningDone instead).
      // Transient engine hiccups — timeouts, audio-focus races, busy engine —
      // recover on their own via the retry paths; surfacing them just spams
      // "mic error" banners while the mic works fine (user report 2026-07-05).
      const transientSttErrors = {
        'error_speech_timeout',
        'error_busy',
        'error_audio',
        'error_client',
      };
      _stt.onError = (msg) {
        if (_raceActive) return; // race-managed session — race handles errors
        if (!mounted || transientSttErrors.contains(msg)) return;
        // Hands-free is eyes-off and self-recovering — never banner it.
        if (widget.args.mode == QuizMode.handsFree) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('quiz.stt_error'.tr(namedArgs: {'msg': msg})),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ));
      };

      // Called exactly once per listen session (debounced in SpeechRecognitionService).
      // answerState is still idle → no result was recognised this round.
      _stt.onListeningDone = () async {
        if (_raceActive) {
          // Race-managed session: the race owns timeout/fallback/grading —
          // the legacy retry ladder must not fire on top of it.
          sttLog('[HF][RACE] onListeningDone swallowed (race manages session)');
          return;
        }
        if (!mounted) return;
        final capturedToken = _listenToken;
        final elapsed = _stt.listenElapsedMs;
        final state = ref.read(quizProvider);
        sttLog('[HF] onListeningDone  capturedToken=$capturedToken  currentToken=$_listenToken  elapsed=${elapsed}ms  answerState=${state.answerState}  retries=$_listenRetries');
        ref.read(quizProvider.notifier).setListening(false);

        if (state.answerState == QuizAnswerState.idle) {
          if (widget.args.mode == QuizMode.handsFree) {
            // If the token changed, this callback is stale (a new listen
            // session already started) — ignore it to avoid double-penalising.
            if (capturedToken != _listenToken) {
              sttLog('[HF] ⚠️ Stale callback (token mismatch) — ignoring');
              return;
            }

            // Samsung STT fires notListening/done BEFORE delivering the final
            // onResult (observed 1-2s delay on Galaxy S22 Ultra).  If STT ran
            // for a meaningful amount of time it may have heard something — wait
            // up to 2.5 s for the late result before declaring it wrong.
            final hadRealListen = elapsed >= 1500;
            if (hadRealListen) _hadRealWindowThisCard = true;

            // The engine's error verdict (error_client etc.) arrives ~1-5ms
            // AFTER the notListening status that got us here — deciding
            // immediately always saw lastError=null and retried blind
            // (field log 2026-07-07: an error_client retry storm at 700ms
            // cadence, each restart re-throttled by Android). Sense first.
            await Future.delayed(const Duration(milliseconds: 250));
            if (!mounted || capturedToken != _listenToken) return;
            if (ref.read(quizProvider).answerState != QuizAnswerState.idle) {
              return; // a late result graded the card while we sensed
            }

            // error_client/error_busy = Android throttling rapid restarts;
            // it needs a real cooldown, not a faster hammer.
            final err = _stt.lastError;
            final wasThrottled = err == 'error_client' || err == 'error_busy';
            final wasPermanentError = err == 'error_audio';

            // Throttle storms (error_client at ~15ms) can eat every retry
            // before the mic was EVER live for this card — which then skipped
            // the card unanswered (field logs 2026-07-19: half the quiz
            // auto-skipped). A card may only give up after at least one real
            // listen window happened, with a bigger budget while throttled.
            final retryLimit = _hadRealWindowThisCard ? 2 : 4;
            if (!wasPermanentError && !hadRealListen &&
                _listenRetries < retryLimit) {
              // STT stopped instantly — back off, much longer if throttled
              // (Android's cooldown outlasts 2s; 4s clears it reliably).
              _listenRetries++;
              final backoffMs = wasThrottled ? 4000 : 1200;
              sttLog('[HF] 🔁 STT stopped too fast (${elapsed}ms, err=$err) — retry #$_listenRetries/$retryLimit in ${backoffMs}ms');
              Future.delayed(Duration(milliseconds: backoffMs), () {
                if (!mounted || capturedToken != _listenToken) return;
                final card = ref.read(quizProvider).currentCard;
                if (card != null &&
                    ref.read(quizProvider).answerState ==
                        QuizAnswerState.idle) {
                  unawaited(_startListening(card, isRetry: true));
                }
              });
            } else {
              // STT ran for a real listen duration or retries exhausted.
              // Wait up to 2.5 s for Samsung's late final-result callback —
              // but ONLY after a clean session end (err == null): an explicit
              // error_speech_timeout / error_no_match means the engine gave up
              // and no late result is coming, and showing the analyse phase
              // then reads as "it thought I said something" (field report
              // 2026-07-19).
              final waitMs =
                  hadRealListen && !wasPermanentError && err == null
                      ? 2500
                      : 0;
              sttLog('[HF] Waiting ${waitMs}ms for possible late Samsung onResult before submitting empty (elapsed=${elapsed}ms  permanentError=$wasPermanentError  retries=$_listenRetries)');
              // Mic is closed and a result may still land: that IS the
              // "analyse" phase from the user's perspective.
              if (waitMs > 0) _enterAnalyzing();
              _listenRetries = 0;
              Future.delayed(Duration(milliseconds: waitMs), () {
                if (!mounted) return;
                // answerState alone isn't enough: if the card was answered
                // AND advanced during the wait, the NEW card is idle again
                // and would be declared "pas entendu" (field log 2026-07-07:
                // card 1's timer re-listened over card 2's TTS).
                if (capturedToken != _listenToken) {
                  sttLog('[HF] Empty-wait timer stale (token moved on) — dropping');
                  return;
                }
                if (ref.read(quizProvider).answerState !=
                    QuizAnswerState.idle) {
                  sttLog('[HF] ✅ Late onResult arrived before timeout');
                  return;
                }
                _notHeardLadder(capturedToken,
                    canRetry: hadRealListen && !wasPermanentError);
              });
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('quiz.stt_not_recognised'.tr()),
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ));
          }
        } else {
          sttLog('[HF] onListeningDone: answerState already ${state.answerState} — no action needed');
        }
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
    _sfx.dispose();
    _answerCtrl.dispose();
    super.dispose();
  }

  String? _firstCorrectCandidate(List<String> candidates, QuizCard card) =>
      AnswerValidator.firstCorrect(
        candidates: candidates,
        acceptedAnswers: card.answerWords,
        isDrivingMode: true,
      );

  /// Opens the mic only AFTER the app has finished talking (question TTS,
  /// and on a new card after a mistake, the KO correction still in flight).
  /// The old fixed 300ms delay cut speech mid-word via the mic's audio-stop
  /// AND let the recognizer transcribe the app's own voice as the user's
  /// answer (user feedback 2026-07-05).
  Future<void> _waitForSpeechThenListen(QuizCard card) async {
    final audio = ref.read(audioPlayerServiceProvider);
    final waitStart = DateTime.now();
    // Speech at a card boundary is a CHAIN, not one utterance: the previous
    // card's correction replay may still be playing with the question queued
    // behind it (_speakWhenQuiet). A single start→end wait latched onto the
    // replay and the mic path's audio-stop CUT OFF the question (field log
    // 2026-07-10: 'fruit' truncated mid-word). Up to 3 cycles of
    // [wait-for-start → wait-for-end]; a cycle with no new speech ends it.
    for (var cycle = 0; cycle < 3; cycle++) {
      // First cycle waits generously for the question TTS to spin up; the
      // follow-up checks are just "did another utterance queue behind it?"
      // — a full 2.5s there added dead air to EVERY card (waited ~4s while
      // speech ended ~1.5s in — field log 2026-07-10 01:20).
      final startDeadline = DateTime.now()
          .add(Duration(milliseconds: cycle == 0 ? 2500 : 400));
      while (mounted &&
          !audio.isSpeaking &&
          DateTime.now().isBefore(startDeadline)) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      if (!audio.isSpeaking) break; // chain over — nothing new started
      final deadline = DateTime.now().add(const Duration(seconds: 8));
      while (mounted &&
          audio.isSpeaking &&
          DateTime.now().isBefore(deadline)) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
    final speechWaitMs =
        DateTime.now().difference(waitStart).inMilliseconds;
    sttLog('[HF] waited ${speechWaitMs}ms for TTS chain (isSpeaking=${audio.isSpeaking}) — starting 250ms echo tail');
    // Echo tail: let the room go quiet before the mic opens.
    await Future.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    if (_stt.isListening) {
      // A stale session must not swallow this card's window (it would hear
      // our TTS and validate against the wrong card) — stop it, then start
      // fresh. Never skip: skipping left cards without their own session.
      sttLog('[HF] stale session still open — stopping it before this card\'s listen');
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

  /// Starts a Whisper listen for [card]: raw mic capture, our segmenter's
  /// endpointing (pre-roll included), per-segment on-device transcription
  /// in the card's answer language. Open vocabulary: correct answers grade
  /// correct, real wrong words grade wrong, noise/hallucinations are
  /// filtered in the service and never reach grading.
  /// Returns false if the engine could not start (caller falls back).
  Future<bool> _startWhisperListening(
      QuizCard card, String langCode, int sessionToken) async {
    sttLog('[HF][WSP] using whisper engine  langCode=$langCode  token=$sessionToken  answers=${card.answerWords}');

    bool sameCard() =>
        ref.read(quizProvider).currentCard?.progress.variantId ==
        card.progress.variantId;

    // The listening window and the countdown bar must move TOGETHER: the
    // repeat prompt restarts the bar, so it must also re-arm a fresh window
    // — the original timer kept running and expired mid-bar ("progress bar
    // stuck", field logs 2026-07-09/10). Generation counter voids stale
    // timers.
    void armWindow() {
      final gen = ++_whisperWindowGen;
      Future.delayed(const Duration(seconds: 10), () async {
        if (!mounted || sessionToken != _listenToken) return;
        if (gen != _whisperWindowGen) return; // re-armed since — stale
        if (!_whisper.isListening) return;
        if (ref.read(quizProvider).answerState != QuizAnswerState.idle) {
          return;
        }
        sttLog('[HF][WSP] window expired with no accepted answer');
        await _whisper.stopListening(keepPendingTranscripts: true);
        // A segment captured near the deadline may still be in inference —
        // give it a beat before declaring "not heard".
        await Future.delayed(const Duration(milliseconds: 1000));
        if (!mounted || sessionToken != _listenToken) return;
        if (gen != _whisperWindowGen) return;
        if (ref.read(quizProvider).answerState != QuizAnswerState.idle) {
          return;
        }
        ref.read(quizProvider.notifier).setListening(false);
        _notHeardLadder(sessionToken, canRetry: true);
      });
    }

    // Junk/borderline transcripts reopen the attempt with an explicit
    // "répète" prompt — silently staying in listening was indistinguishable
    // from "didn't hear you" (user report 2026-07-10). Capped so a noisy
    // loop degrades into the regular not-heard ladder.
    void promptRepeat(String why) {
      if (!mounted || sessionToken != _listenToken) return;
      if (_misheardRetries >= 3) {
        sttLog('[HF][WSP] mishears exhausted — handing to not-heard ladder');
        unawaited(_whisper.stopListening());
        ref.read(quizProvider.notifier).setListening(false);
        _notHeardLadder(sessionToken, canRetry: true);
        return;
      }
      _misheardRetries++;
      sttLog('[HF][WSP] 🔁 repeat prompt #$_misheardRetries ($why)');
      setState(() {
        _hfAnalyzing = false;
        _hfMisheard = true;
      });
      if (!_kTestMode) {
        unawaited(_sfx.playListenCue()); // mic is live again — your turn
        HapticFeedback.selectionClick();
      }
      _listenBarCtrl
        ..reset()
        ..forward();
      armWindow(); // fresh 10s window, aligned with the restarted bar
    }

    final ok = await _whisper.startListening(
      langCode: langCode,
      // Prompt hints RE-ENABLED with whisper.cpp v1.9.1: the old 2023-era
      // engine mangled initial_prompt ("먹다"→"목사", counting
      // hallucinations — 2026-07-10); the modern implementation is the
      // main accuracy lever for a known-answer quiz.
      promptHints: card.answerWords,
      // The utterance is captured and inference is running: low tick +
      // pulsing "Analyse…" — the moment the user can stop talking.
      onSegment: _enterAnalyzing,
      onFinal: (text, segmentMs) {
        if (!mounted || !sameCard()) return;
        if (ref.read(quizProvider).answerState != QuizAnswerState.idle) return;
        // Show what was heard (there are no streaming partials — the
        // transcript IS the display).
        if (sessionToken == _listenToken) {
          ref.read(quizProvider.notifier).setPartialTranscript(text);
        }
        final correct = _firstCorrectCandidate([text], card);
        if (correct != null) {
          sttLog('[HF][WSP] ✅ accepted "$text" (${segmentMs}ms segment)');
          unawaited(_whisper.stopListening());
          _enterAnalyzing();
          _consecutiveSilentCards = 0; // real speech reached us
          ref
              .read(quizProvider.notifier)
              .submitVoiceAnswer(correct, isDrivingMode: true);
          return;
        }
        // Open vocabulary, but grading wrong is CONSERVATIVE (field log
        // 2026-07-09: "délicieux" transcribed as "Désliez-le" was graded
        // wrong and the surprise correction audio overlapped the next
        // question). Three tiers by validation score:
        //  - correct → accepted above;
        //  - borderline (≥0.35): probably a mis-transcribed CORRECT answer
        //    → keep the window open, let the user repeat;
        //  - clearly different short answer → a real wrong answer, grade.
        // Long transcripts are ambient speech/hallucination, never answers.
        if (sessionToken != _listenToken) {
          sttLog('[HF][WSP] wrong transcript from stale window — discarded');
          return;
        }
        // Junk-length is ANSWER-RELATIVE: Korean single-syllable answers
        // ("밥") are one character — a fixed <2 gate made those cards
        // unanswerable (field log 2026-07-10 01:21).
        final minAnswerLen = card.answerWords
            .map((a) => AnswerValidator.stripAnnotations(a).length)
            .fold<int>(99, (m, l) => l < m ? l : m);
        if (text.split(' ').length > 3) {
          // Ambient conversation, not an answer — ignore WITHOUT burning a
          // repeat prompt (two people talking spammed the mishear ladder,
          // field 2026-07-13). The window stays open for the real answer.
          sttLog('[HF][WSP] conversation-length transcript "$text" ignored');
          return;
        }
        if (text.length < (minAnswerLen <= 1 ? 1 : 2)) {
          sttLog('[HF][WSP] junk-length transcript "$text" — asking to repeat');
          promptRepeat('junk length');
          return;
        }
        final v = AnswerValidator.validate(
          userAnswer: text,
          acceptedAnswers: card.answerWords,
          isDrivingMode: true,
        );
        if (v.score >= 0.35) {
          // Borderline = evidence the user is probably RIGHT but garbled by
          // transcription. Shield the card: strikes can no longer grade it
          // wrong (field log 2026-07-10: "mauvais" → Mauvi 0.60 borderline,
          // then two garbles → strike-2 failed a correct answer).
          _sawBorderline = true;
          sttLog('[HF][WSP] borderline "$text" (score=${v.score.toStringAsFixed(2)}) — likely mis-heard correct answer, asking to repeat');
          promptRepeat('borderline ${v.score.toStringAsFixed(2)}');
          return;
        }
        // Two-strike wrong grading: a single low-score transcript can be a
        // garbage transcription of a CORRECT answer (field log 2026-07-10:
        // "먹다" heard as "목사" scored 0.00 and failed the card). First
        // strike asks to repeat; only a second consecutive low-score
        // transcript grades wrong.
        if (segmentMs > 3200) {
          // Too long to be an answer — ambient speech; never a strike.
          sttLog('[HF][WSP] long-segment (${segmentMs}ms) low-score "$text" ignored as ambient');
          return;
        }
        _lowScoreStrikes++;
        if (_lowScoreStrikes < 2 || _sawBorderline) {
          sttLog('[HF][WSP] ⚠️ low-score "$text" (${v.score.toStringAsFixed(2)}) — strike $_lowScoreStrikes${_sawBorderline ? " (borderline shield)" : ""}, asking to repeat');
          promptRepeat('low-score strike $_lowScoreStrikes');
          return;
        }
        sttLog('[HF][WSP] ❌ wrong answer "$text" (score=${v.score.toStringAsFixed(2)}, strike 2) — grading');
        unawaited(_whisper.stopListening());
        _enterAnalyzing();
        _consecutiveSilentCards = 0;
        ref
            .read(quizProvider.notifier)
            .submitVoiceAnswer(text, isDrivingMode: true);
      },
    );
    if (!ok) return false;

    // WE own the window (no OS endpointing): 10s, mirroring the countdown
    // bar, then the shared not-heard ladder — re-armed by every repeat
    // prompt so the bar and the window always agree.
    armWindow();
    return true;
  }

  /// Shared "nothing captured this window" ladder for BOTH engines
  /// (system STT and constrained/Vosk): up to two cued re-listens with the
  /// "try x/3" prompt, then skip WITHOUT grading — silence is never a wrong
  /// answer (user rule 2026-07-06) — auto-pausing after two silent cards in
  /// a row.
  void _notHeardLadder(int capturedToken, {required bool canRetry}) {
    if (canRetry && _notHeardRetries < 2) {
      _notHeardRetries++;
      // Last chance (attempt 3/3): hand the mic to the system recognizer —
      // Whisper heard nothing twice, so a different engine's ears beat
      // skipping the card outright.
      _systemRescueAttempt = _notHeardRetries >= 2;
      sttLog('[HF] 🔇 Pas entendu — re-listen #$_notHeardRetries${_systemRescueAttempt ? " (system rescue)" : ""}');
      setState(() {
        _hfNotHeard = true;
        _hfAnalyzing = false; // retry prompt outranks "analyse"
      });
      Future.delayed(const Duration(milliseconds: 900), () {
        if (!mounted || capturedToken != _listenToken) return;
        final card = ref.read(quizProvider).currentCard;
        if (card != null &&
            ref.read(quizProvider).answerState == QuizAnswerState.idle) {
          unawaited(_startListening(card, isRetry: true));
        }
      });
      return;
    }
    _notHeardRetries = 0;
    // Nothing heard after all retries. NEVER a wrong answer —
    // the user didn't speak (user feedback 2026-07-06). Skip
    // without grading; the card comes back later in the session.
    _consecutiveSilentCards++;
    if (_consecutiveSilentCards >= 2) {
      // Two cards in a row with zero usable speech: the
      // environment can't support hands-free right now. Pause
      // instead of burning through the whole session.
      sttLog('[HF] 🔇🔇 $_consecutiveSilentCards consecutive silent cards — auto-pausing session');
      _stt.stopListening();
      unawaited(_whisper.stopListening());
      ref.read(quizProvider.notifier).setListening(false);
      setState(() {
        _hfAutoPausedSilence = true;
        _hfPaused = true;
      });
      return;
    }
    sttLog('[HF] ❌ No result after retries — skipping WITHOUT grading (silent card #$_consecutiveSilentCards)');
    ref.read(quizProvider.notifier).skipCurrentCard();
  }

  /// Enters the hands-free "analyse" phase: the mic captured speech (or
  /// closed after a real listen) and the verdict is pending. Plays the low
  /// closing tick so the user knows to stop talking. Idempotent per phase —
  /// reset when a new listen or card starts.
  void _enterAnalyzing() {
    if (_hfAnalyzing || widget.args.mode != QuizMode.handsFree) return;
    _listenBarCtrl.stop(); // mic closed — freeze the countdown
    if (!_kTestMode) unawaited(_sfx.playListenDone());
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
  Future<void> _startRaceListening(
      QuizCard card, String langCode, int sessionToken) async {
    final handsFree = widget.args.mode == QuizMode.handsFree;
    _raceSystemEngine ??= SystemSttEngine(_stt);
    _raceWhisperEngine ??= WhisperSttEngine(_whisper);
    await _raceSystemEngine!.prepare(); // idempotent — already initialised
    // Whisper joins lane 2 once its model is ready; kick the download in the
    // background on first race use (it was skipped while system-primary).
    // Debug builds skip whisper entirely: unoptimized inference takes ~16s
    // per clip — it produced 0 hypotheses in the 8s lane every time (field
    // log 2026-07-19) while holding ~142MB of RAM in the Dev app.
    final whisperEligible = !kDebugMode;
    if (whisperEligible && !_whisper.isReady && !_kTestMode) {
      unawaited(_whisper.ensureModel());
    }

    // A race result is stale when the session, card, or verdict moved on.
    bool stale() =>
        !mounted ||
        sessionToken != _listenToken ||
        ref.read(quizProvider).currentCard?.progress.variantId !=
            card.progress.variantId ||
        ref.read(quizProvider).answerState != QuizAnswerState.idle;

    // The countdown bar tracks each lane's window (it froze during legacy
    // retries — field report 2026-07-19).
    void runBar() {
      if (!_kTestMode) {
        _listenBarCtrl
          ..reset()
          ..forward();
      }
    }

    sttLog('[RACE][HF] lane 1 (system)  token=$sessionToken  lang=$langCode');
    runBar();
    var outcome = await SttRace([_raceSystemEngine!]).run(
      langCode: langCode,
      acceptedAnswers: card.answerWords,
      promptHints: card.answerWords,
      timeout: const Duration(seconds: 10),
      onPartial: (h) {
        if (!stale()) {
          ref.read(quizProvider.notifier).setPartialTranscript(h.transcript);
        }
      },
    );
    if (stale()) return;

    if (!outcome.matched && whisperEligible && _whisper.isReady) {
      sttLog('[RACE][HF] lane 2 (whisper)  token=$sessionToken');
      if (handsFree) _enterAnalyzing();
      runBar();
      outcome = await SttRace([_raceWhisperEngine!]).run(
        langCode: langCode,
        acceptedAnswers: card.answerWords,
        promptHints: card.answerWords,
        timeout: const Duration(seconds: 8),
      );
      if (stale()) return;
    }

    _listenBarCtrl.stop();
    ref.read(quizProvider.notifier).setListening(false);

    if (outcome.matched) {
      sttLog('[RACE][HF] ✅ "${outcome.matchedCandidate}" won via ${outcome.winnerEngineId}');
      _consecutiveSilentCards = 0; // real speech reached us
      ref
          .read(quizProvider.notifier)
          .submitVoiceAnswer(outcome.matchedCandidate!, isDrivingMode: true);
      return;
    }
    final heard = outcome.bestTranscript;
    if (heard != null && heard.trim().isNotEmpty) {
      // Heard something that never validated — grade it wrong, exactly once.
      sttLog('[RACE][HF] ❌ no lane validated — grading "$heard" wrong');
      _consecutiveSilentCards = 0;
      ref
          .read(quizProvider.notifier)
          .submitVoiceAnswer(heard, isDrivingMode: true);
      return;
    }
    sttLog('[RACE][HF] 🔇 nothing heard in any lane');
    if (handsFree) {
      _notHeardLadder(sessionToken, canRetry: true);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('quiz.stt_not_recognised'.tr()),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  // When the last mic session opened — drives the retry pacing guard.
  DateTime? _lastMicOpen;

  // Whether at least one REAL listen window (≥1.5s of live mic) opened for the
  // current card. Throttle storms (error_client after ~15ms) must not exhaust
  // a card's retries before the user ever had a mic (field logs 2026-07-19).
  bool _hadRealWindowThisCard = false;

  Future<void> _startListeningInner(QuizCard card,
      {required bool isRetry}) async {
    // Pacing guard: with the system recognizer being near-instant, failed
    // sessions can recycle every ~2.3s — six earcons in 15s felt frantic
    // ("trips over itself", field report 2026-07-19). Retries wait until at
    // least 3.5s since the previous mic open; fresh cards are not delayed.
    if (isRetry && _lastMicOpen != null && !_kTestMode) {
      final sinceLast = DateTime.now().difference(_lastMicOpen!);
      const minGap = Duration(milliseconds: 3500);
      if (sinceLast < minGap) {
        final wait = minGap - sinceLast;
        sttLog('[HF] ⏳ pacing guard — delaying retry ${wait.inMilliseconds}ms');
        await Future.delayed(wait);
        if (!mounted ||
            ref.read(quizProvider).answerState != QuizAnswerState.idle) {
          return; // answered (or gone) while breathing
        }
      }
    }
    _lastMicOpen = DateTime.now();

    if (!isRetry) {
      _listenRetries = 0;
      _notHeardRetries = 0;
      _noiseRetries = 0;
      _hadRealWindowThisCard = false;
    }
    if (!isRetry) {
      _systemRescueAttempt = false;
      _misheardRetries = 0;
      _lowScoreStrikes = 0;
      _sawBorderline = false;
    }
    // Fresh listens reset the banner to "speak now"; retry listens KEEP the
    // "try x/3" / "répète" prompts visible — they already say what to do.
    if ((_hfNotHeard && !isRetry) || (_hfMisheard && !isRetry) || _hfAnalyzing) {
      setState(() {
        _hfNotHeard = _hfNotHeard && isRetry;
        _hfMisheard = _hfMisheard && isRetry;
        _hfAnalyzing = false;
      });
    }
    _listenToken++;
    sttLog('[HF] _startListening  token=$_listenToken  isRetry=$isRetry  question="${card.questionWord}"  answerWords=${card.answerWords}');
    ref.read(quizProvider.notifier).setListening(true);

    if (SttSimulator.isOn) {
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      final answer = switch (SttSimulator.mode) {
        'correct' => card.answerWords.isNotEmpty ? card.answerWords.first : '',
        'wrong'   => '__wrong__',
        _         => '',
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
    unawaited(ref.read(audioPlayerServiceProvider).stop());
    await Future.delayed(const Duration(milliseconds: 300));
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
      unawaited(_sfx.playListenCue());
      HapticFeedback.selectionClick();
      await Future.delayed(const Duration(milliseconds: 250));
      if (!mounted) return;
    }

    final currentDir = ref.read(quizProvider).currentCard?.progress.direction;
    final langCode = currentDir?.answerLang ?? widget.args.langB;
    // Capture token so late-arriving onResult from this session is ignored
    // once a new session (next card) has started.
    final sessionToken = _listenToken;

    // Experimental race pipeline (Settings → Moteur vocal → Course): the
    // SttRace framework runs a system-recognizer lane, then an offline
    // Whisper lane on a miss, grading exactly once. Kept fully separate from
    // the battle-tested legacy path below — flip the setting to fall back.
    _raceActive = ref.read(sttEngineModeProvider) == SttEngineMode.race &&
        widget.args.source != QuizSource.grammar;
    if (_raceActive) {
      await _startRaceListening(card, langCode, sessionToken);
      return;
    }

    // Engine routing, v4 (2026-07-19): the system recognizer is PRIMARY in
    // hands-free (see [_handsFreeWhisperPrimary]) — it's faster and more
    // accurate for supported languages per device logs. The Whisper-primary
    // path below is kept behind the flag and returns as a parallel racer via
    // SttRace; grammar always uses the system recognizer (streaming partials).
    if (_handsFreeWhisperPrimary &&
        !_systemRescueAttempt &&
        widget.args.mode == QuizMode.handsFree &&
        widget.args.source != QuizSource.grammar &&
        _whisper.isReady) {
      final started =
          await _startWhisperListening(card, langCode, sessionToken);
      if (started) return;
      sttLog('[HF] whisper failed to start — falling back to system STT');
    }

    sttLog('[HF] Calling stt.startListening  langCode=$langCode  token=$sessionToken');
    final ok = await _stt.startListening(
      langCode: langCode,
      onResult: (text, candidates) {
        // Samsung STT can fire the final onResult 1-2s AFTER notListening,
        // and retries rotate sessions fast. Gate by CARD identity, not
        // session: a correct answer for the card on screen is accepted no
        // matter which listen session delivered it (field log 2026-07-06:
        // "poussin" heard at 0.93 was discarded twice for a stale token).
        // WRONG results are held to the stricter same-session gate so a
        // stale session can't fail the current card.
        final sameCard = ref.read(quizProvider).currentCard?.progress
                .variantId ==
            card.progress.variantId;
        sttLog('[HF] onResult: "$text"  candidates=$candidates  sessionToken=$sessionToken  currentToken=$_listenToken  sameSession=${sessionToken == _listenToken}  sameCard=$sameCard');
        if (!mounted || !sameCard) {
          if (!sameCard) sttLog('[HF] Late onResult discarded (card changed)');
          return;
        }
        if (widget.args.mode == QuizMode.handsFree && candidates.isNotEmpty) {
          if (ref.read(quizProvider).answerState != QuizAnswerState.idle) {
            return; // already graded (e.g. by a partial)
          }
          // ANY candidate transcript counts — the engine's top pick is
          // often wrong while an alternate is the user's actual word.
          final correct = _firstCorrectCandidate(candidates, card);
          if (correct != null) {
            _stt.stopListening();
            _enterAnalyzing();
            _consecutiveSilentCards = 0; // real speech reached us
            ref
                .read(quizProvider.notifier)
                .submitVoiceAnswer(correct, isDrivingMode: true);
            return;
          }
          // Wrong results: only the CURRENT session may fail the card, and
          // implausibly fast ones are treated as app-audio pickup.
          if (sessionToken != _listenToken) {
            sttLog('[HF] wrong result from a stale session — discarded');
            return;
          }
          final elapsed = _stt.listenElapsedMs;
          if (elapsed < 800 && _noiseRetries < 2) {
            _noiseRetries++;
            sttLog('[HF] 🔇 wrong result after only ${elapsed}ms — treating as app-audio pickup, re-listen #$_noiseRetries');
            _stt.stopListening();
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted &&
                  ref.read(quizProvider).answerState ==
                      QuizAnswerState.idle) {
                unawaited(_startListening(card, isRetry: true));
              }
            });
            return;
          }
          _stt.stopListening();
          _enterAnalyzing();
          _consecutiveSilentCards = 0; // real speech reached us
          ref
              .read(quizProvider.notifier)
              .submitVoiceAnswer(text, isDrivingMode: true);
        } else if (widget.args.mode == QuizMode.handsFree) {
          // Empty final result: the engine heard something but recognized
          // no words (parasitic speech, noise). NOT an answer — the
          // not-heard recovery owns this case. Submitting it graded the
          // card wrong through no fault of the user (found by the acoustic
          // harness, 2026-07-06: French speech near the phone failed the
          // card before the user spoke).
          sttLog('[HF] empty final result ignored — not-heard recovery owns it');
        } else if (sessionToken == _listenToken) {
          ref.read(quizProvider.notifier).submitVoiceAnswer(
                text,
                isDrivingMode: widget.args.mode == QuizMode.voice,
              );
        }
      },
      onPartial: (text, candidates) {
        // Same card-identity gate as onResult: a correct partial for the
        // card on screen counts even if delivered by a retry's session.
        final sameCard = ref.read(quizProvider).currentCard?.progress
                .variantId ==
            card.progress.variantId;
        sttLog('[HF] partial: "$text"  candidates=$candidates  sameCard=$sameCard');
        if (mounted && sameCard) {
          if (sessionToken == _listenToken) {
            ref.read(quizProvider.notifier).setPartialTranscript(text);
          }
          // Hands-free: an exact partial match IS the answer — grade it now
          // instead of sitting through STT's end-of-speech silence timer.
          // Only exact matches short-circuit (fuzzy ones wait for the final
          // result), and only correctness can fire early — a partial is
          // never graded wrong, since the user may still be speaking.
          // Checked across ALL candidates, not just the engine's top pick.
          if (widget.args.mode == QuizMode.handsFree &&
              ref.read(quizProvider).answerState == QuizAnswerState.idle) {
            for (final candidate in candidates) {
              final early = AnswerValidator.validate(
                userAnswer: candidate,
                acceptedAnswers: card.answerWords,
                isDrivingMode: true,
              );
              if (early.isCorrect &&
                  early.type == ValidationResultType.exact) {
                sttLog('[HF] ⚡ exact partial match ("$candidate") — grading immediately');
                _stt.stopListening();
                _enterAnalyzing();
                _consecutiveSilentCards = 0; // real speech reached us
                ref
                    .read(quizProvider.notifier)
                    .submitVoiceAnswer(candidate, isDrivingMode: true);
                break;
              }
            }
          }
        }
      },
    );
    sttLog('[HF] stt.startListening returned ok=$ok  token=$_listenToken');
    if (!ok && mounted) {
      sttLog('[HF] ❌ STT failed to start — clearing listening state');
      ref.read(quizProvider.notifier).setListening(false);
      return;
    }

    // No earcon here: the "your turn" cue already played BEFORE the mic
    // opened (see above). A second cue after startListening plays into the
    // live recognizer — the "double bip" field report of 2026-07-07.

    // Restart the listening-window countdown bar for this attempt.
    if (!_kTestMode) {
      _listenBarCtrl
        ..reset()
        ..forward();
    }

    // Pre-warm the NEXT card's voice while the user answers: switching
    // fr↔ko on the shared native TTS engine costs 1–3.7s (field log
    // 2026-07-07 22:30 — "singe" took 3.7s to become audible after a
    // Korean utterance). Loading it now, during the listening window,
    // makes the next question start near-instantly. Produces no audio.
    final upcoming = ref.read(quizProvider).nextCard;
    if (upcoming != null) {
      final audio = ref.read(audioPlayerServiceProvider);
      unawaited(audio.warmUp(upcoming.progress.direction.questionLang));
      // Premium voices: a word's FIRST ElevenLabs render is a 1-4s network
      // round-trip ("some words take seconds to start", 2026-07-21).
      // Prefetch the next card's question + answer into the cache now, so
      // its audio starts instantly when the card arrives.
      unawaited(audio.prefetch(upcoming.questionWord,
          upcoming.progress.direction.questionLang));
      if (upcoming.answerWords.isNotEmpty) {
        unawaited(audio.prefetch(upcoming.answerWords.first,
            upcoming.progress.direction.answerLang));
      }
    }

    // Failsafe: if the STT callbacks never fire (device bug / audio focus
    // held by another app), reset listening state after listenFor + buffer.
    // IMPORTANT: capture sessionToken so this timer only affects THIS session.
    // Without the token check, a stale timer from card N fires 12 s later and
    // stops card N+1's session — the primary cause of premature termination.
    Future.delayed(const Duration(seconds: 12), () {
      if (mounted && _stt.isListening && sessionToken == _listenToken) {
        sttLog('[HF] ⏰ Failsafe timeout for token=$sessionToken — stopping STT');
        _stt.stopListening();
        ref.read(quizProvider.notifier).setListening(false);
      }
    });
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
          if (correct) { _sfx.playCorrect(); } else { _sfx.playIncorrect(); }
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
            !_kTestMode && shouldSpeakAnswer(widget.args.mode, correct: correct);
        if (shouldSpeak) {
          final card = next.currentCard;
          if (card != null && card.answerWords.isNotEmpty) {
            final answerLang =
                card.progress.direction.answerLang;
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
            (prev?.cards.isEmpty ?? true) && next.cards.isNotEmpty;
        final card = next.currentCard;
        if ((cardChanged || justLoaded || cardsJustAppeared) && card != null && !next.isComplete) {
          sttLog('[HF] Card trigger: cardChanged=$cardChanged justLoaded=$justLoaded cardsJustAppeared=$cardsJustAppeared  idx=${next.currentIndex}  question="${card.questionWord}"  answers=${card.answerWords}');
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
          if (_hfAnalyzing || _hfNotHeard || _hfMisheard) {
            setState(() {
              _hfAnalyzing = false;
              _hfNotHeard = false;
              _hfMisheard = false;
            });
          }
          unawaited(_waitForSpeechThenListen(card));
        }
      }
    });

    if (quizState.isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
              color: AppColors.clay, strokeWidth: 2),
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
          child: CircularProgressIndicator(
              color: AppColors.clay, strokeWidth: 2),
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
      _consecutiveSilentCards = 0;
      final card = ref.read(quizProvider).currentCard;
      if (card != null) unawaited(_startListening(card));
    }
  }

  void _hfRepeat() {
    final card = ref.read(quizProvider).currentCard;
    if (card == null) return;
    final questionLang =
        card.progress.direction.questionLang;
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
  Widget _buildHandsFreeStudy(BuildContext context, QuizState s, QuizCard card) {
    final questionIsHangul =
        Languages.usesHangul(card.progress.direction.questionLang);
    final answerIsHangul =
        Languages.usesHangul(card.progress.direction.answerLang);

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

    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final listening = s.isListening && !_hfPaused;

    // Phase priority: paused > analyzing (mic closed, verdict pending) >
    // not-heard (retry prompt with attempt count) > listening (speak now) >
    // reading the word.
    final cue = _hfPaused
        ? null
        : (_hfAnalyzing
            ? 'quiz.hf_analyzing'.tr()
            : (_hfMisheard
                ? 'quiz.hf_misheard'.tr()
                : (_hfNotHeard
                ? 'quiz.hf_not_heard_retry'.tr(namedArgs: {
                    'attempt': '${_notHeardRetries + 1}',
                    'total': '3',
                  })
                : (listening
                    ? 'quiz.say_in_lang'.tr(namedArgs: {
                        'lang': 'lang.${_answerLangCode(card)}'.tr()
                      })
                    : 'quiz.hf_reading'.tr()))));
    final cueColor = listening && !_hfAnalyzing
        ? (isDark ? AppColors.clayLight : AppColors.clayDeep)
        : (isDark ? AppColors.onDarkMuted : AppColors.muted);

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
      showProgress: false,
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
                            cueColor:
                                cueColor.withValues(alpha: fade),
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
                                cs.onSurface.withValues(alpha: 0.08),
                            valueColor: AlwaysStoppedAnimation(isDark
                                ? AppColors.clayLight
                                : AppColors.clayDeep),
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
                  color: (isDark ? Colors.black : Colors.white)
                      .withValues(alpha: 0.45),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                            _hfAutoPausedSilence
                                ? Icons.hearing_disabled_rounded
                                : Icons.pause_rounded,
                            size: 56,
                            color: cs.onSurface),
                        const SizedBox(height: 10),
                        Text(
                            (_hfAutoPausedSilence
                                    ? 'quiz.hf_paused_silence'
                                    : 'quiz.hf_paused')
                                .tr(),
                            textAlign: TextAlign.center,
                            style: AppTextStyles.grotesk(28, FontWeight.w700)
                                .copyWith(color: cs.onSurface)),
                        const SizedBox(height: 6),
                        Text('quiz.hf_resume_hint'.tr(),
                            style: AppTextStyles.fig(14, FontWeight.w500)
                                .copyWith(
                                    color: isDark
                                        ? AppColors.onDarkMuted
                                        : AppColors.muted)),
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
  String _answerLangCode(QuizCard card) =>
      card.progress.direction.answerLang;

  String _nextReviewText(int scheduledDays, bool correct) {
    if (!correct) return 'quiz.next_review_soon'.tr();
    return scheduledDays <= 1
        ? 'quiz.next_review_tomorrow'.tr()
        : 'quiz.next_review_in_days'
            .tr(namedArgs: {'days': scheduledDays.toString()});
  }

  /// Cartes — flip card on the unified study canvas; self-grade shows the flood.
  Widget _buildCartesStudy(BuildContext context, QuizState s, QuizCard card) {
    final questionIsHangul =
        Languages.usesHangul(card.progress.direction.questionLang);
    final answerIsHangul =
        Languages.usesHangul(card.progress.direction.answerLang);

    if (s.answerState != QuizAnswerState.idle) {
      final correct = s.answerState == QuizAnswerState.correct;
      return StudyFeedbackFlood(
        isCorrect: correct,
        label: correct
            ? 'quiz.feedback_correct'.tr()
            : 'quiz.feedback_wrong'.tr(),
        answer: card.answerWords.join(' / '),
        answerIsKorean: answerIsHangul,
        detail: _nextReviewText(s.scheduledDays, correct),
        continueLabel: 'quiz.continue_button'.tr(),
        onContinue: () => ref.read(quizProvider.notifier).advance(),
      );
    }

    final showBack = s.isFlipped;
    final word = showBack ? card.answerWords.join(' / ') : card.questionWord;
    // Front = question (Korean only when KO→FR); back = answer (Korean when FR→KO).
    final wordIsKorean = showBack ? answerIsHangul : questionIsHangul;

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
              child: GestureDetector(
                key: const ValueKey(WidgetKeys.cartesCard),
                onTap: showBack
                    ? null
                    : () => ref.read(quizProvider.notifier).flipCard(),
                behavior: HitTestBehavior.opaque,
                child: Center(
                  child: WordInWave(
                    word: word,
                    isKorean: wordIsKorean,
                    cue: showBack ? null : 'quiz.card_flip_hint'.tr(),
                    waveActive: false,
                  ),
                ),
              ),
            ),
            if (showBack)
              Row(
                children: [
                  Expanded(
                    child: _GradeButton(
                      key: const ValueKey(WidgetKeys.gradeAgain),
                      label: 'quiz.flashcard_again'.tr(),
                      icon: Icons.refresh_rounded,
                      color: AppColors.feedbackWrong,
                      onTap: () => ref
                          .read(quizProvider.notifier)
                          .gradeFlashcard(FsrsRating.again),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _GradeButton(
                      key: const ValueKey(WidgetKeys.gradeKnew),
                      label: 'quiz.flashcard_knew'.tr(),
                      icon: Icons.check_rounded,
                      color: AppColors.feedbackCorrect,
                      onTap: () => ref
                          .read(quizProvider.notifier)
                          .gradeFlashcard(FsrsRating.good),
                    ),
                  ),
                ],
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
            : () => unawaited(ref
                .read(audioPlayerServiceProvider)
                .speak(card.answerWords.first,
                    card.progress.direction.answerLang)),
        label: correct
            ? 'quiz.feedback_correct'.tr()
            : 'quiz.feedback_wrong'.tr(),
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
        label: correct
            ? 'quiz.feedback_correct'.tr()
            : 'quiz.feedback_wrong'.tr(),
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
          color: cs.surfaceContainerHighest
              .withValues(alpha: isDark ? 0.5 : 0.7),
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

// ── Cartes self-grade button ──────────────────────────────────────────────────

class _GradeButton extends StatelessWidget {
  const _GradeButton({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            // Flexible: the half-width grade buttons clip long labels on
            // narrow (360dp) screens instead of overflowing.
            Flexible(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.fig(15, FontWeight.w700)
                      .copyWith(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
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
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final fg = cs.onSurface;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 104,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest
              .withValues(alpha: isDark ? 0.4 : 0.7),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cs.outline),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: fg),
            const SizedBox(height: 8),
            Text(label,
                style:
                    AppTextStyles.fig(15, FontWeight.w700).copyWith(color: fg)),
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
    final pct    = total == 0 ? 0 : (correct / total * 100).round();
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
                      'quiz.summary_correct_count'.tr(namedArgs: {'correct': correct.toString(), 'total': total.toString()}),
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
                                borderRadius:
                                    BorderRadius.circular(16),
                              ),
                              child: Center(
                                child: Text('quiz.summary_restart'.tr(),
                                    style: AppTextStyles
                                        .fig(14, FontWeight.w600)
                                        .copyWith(
                                            color: AppColors.muted)),
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
                                borderRadius:
                                    BorderRadius.circular(16),
                              ),
                              child: Center(
                                child: Text('quiz.summary_home'.tr(),
                                    style: AppTextStyles
                                        .fig(14, FontWeight.w700)
                                        .copyWith(
                                            color: Colors.white)),
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
