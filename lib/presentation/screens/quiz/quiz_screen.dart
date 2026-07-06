import 'dart:async' show unawaited;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/quiz/quiz_provider.dart';
import '../../providers/audio/audio_provider.dart';
import '../../../domain/entities/variant_progress.dart' show QuizDirection;
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/stt_simulator.dart';
import '../../../core/utils/answer_validator.dart';
import '../../../core/utils/stt_debug_log.dart';
import '../../../core/utils/fsrs_algorithm.dart';
import '../../../core/widget_keys.dart';
import '../../../services/speech/speech_recognition_service.dart';
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
  final _answerCtrl = TextEditingController();
  // Guards against stale STT callbacks firing on a new card.
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
  // Hands-free app-audio pickup guard: wrong results arriving implausibly
  // fast are discarded and the mic re-listens (max twice per card).
  int _noiseRetries = 0;
  // Cards in a row that ended with zero usable speech. At 2 the session
  // auto-pauses (the room is too loud / mic broken) instead of skipping
  // through every card. Reset by any real recognition or manual resume.
  int _consecutiveSilentCards = 0;
  bool _hfAutoPausedSilence = false;
  // Whole-screen warm breathing pulse used during the hands-free reading state.
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1900));
    // Don't run the perpetual breathing pulse under test — it never settles.
    if (!_kTestMode) _pulseCtrl.repeat(reverse: true);
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
      _stt.onListeningDone = () {
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

            // error_client is a permanent engine error (locale unavailable,
            // audio focus totally lost).  Retrying immediately will keep failing;
            // fall through to the delayed empty-submission path instead.
            final wasPermanentError = _stt.lastError == 'error_client' ||
                _stt.lastError == 'error_audio';

            if (!wasPermanentError && !hadRealListen && _listenRetries < 2) {
              // STT stopped instantly — audio-focus race. Retry.
              _listenRetries++;
              sttLog('[HF] 🔁 STT stopped too fast (${elapsed}ms) — retry #$_listenRetries in 700ms');
              Future.delayed(const Duration(milliseconds: 700), () {
                if (!mounted) return;
                final card = ref.read(quizProvider).currentCard;
                if (card != null &&
                    ref.read(quizProvider).answerState ==
                        QuizAnswerState.idle) {
                  unawaited(_startListening(card, isRetry: true));
                }
              });
            } else {
              // STT ran for a real listen duration or retries exhausted.
              // Wait up to 2.5 s for Samsung's late final-result callback;
              // only submit wrong if no answer arrives in that window.
              final waitMs = hadRealListen && !wasPermanentError ? 2500 : 0;
              sttLog('[HF] Waiting ${waitMs}ms for possible late Samsung onResult before submitting empty (elapsed=${elapsed}ms  permanentError=$wasPermanentError  retries=$_listenRetries)');
              _listenRetries = 0;
              Future.delayed(Duration(milliseconds: waitMs), () {
                if (!mounted) return;
                if (ref.read(quizProvider).answerState !=
                    QuizAnswerState.idle) {
                  sttLog('[HF] ✅ Late onResult arrived before timeout');
                  return;
                }
                // "Pas entendu": a real listen heard nothing. Re-listen up to
                // twice with a muted cue before requeuing as à revoir, so
                // silence isn't a hard wrong (ties into the STT-improvement plan).
                if (hadRealListen &&
                    !wasPermanentError &&
                    _notHeardRetries < 2) {
                  _notHeardRetries++;
                  sttLog('[HF] 🔇 Pas entendu — re-listen #$_notHeardRetries');
                  setState(() => _hfNotHeard = true);
                  Future.delayed(const Duration(milliseconds: 900), () {
                    if (!mounted) return;
                    final card = ref.read(quizProvider).currentCard;
                    if (card != null &&
                        ref.read(quizProvider).answerState ==
                            QuizAnswerState.idle) {
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
                  ref.read(quizProvider.notifier).setListening(false);
                  setState(() {
                    _hfAutoPausedSilence = true;
                    _hfPaused = true;
                  });
                  return;
                }
                sttLog('[HF] ❌ No result after retries — skipping WITHOUT grading (silent card #$_consecutiveSilentCards)');
                ref.read(quizProvider.notifier).skipCurrentCard();
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
    _stt.dispose();
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
    // Give the provider's fire-and-forget speak() a beat to actually start.
    await Future.delayed(const Duration(milliseconds: 300));
    final deadline = DateTime.now().add(const Duration(seconds: 8));
    while (mounted &&
        audio.isSpeaking &&
        DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    final speechWaitMs =
        DateTime.now().difference(waitStart).inMilliseconds - 300;
    sttLog('[HF] waited ${speechWaitMs}ms for TTS to finish (isSpeaking=${audio.isSpeaking}) — starting 250ms echo tail');
    // Echo tail: let the room go quiet before the mic opens.
    await Future.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    if (_stt.isListening) {
      // A stale session must not swallow this card's window (it would hear
      // our TTS and validate against the wrong card) — stop it, then start
      // fresh. Never skip: skipping left cards without their own session.
      sttLog('[HF] stale session still open — stopping it before this card\'s listen');
      await _stt.stopListening();
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
    }
    sttLog('[HF] speech finished — calling _startListening');
    unawaited(_startListening(card));
  }

  Future<void> _startListening(QuizCard card, {bool isRetry = false}) async {
    if (!isRetry) {
      _listenRetries = 0;
      _notHeardRetries = 0;
      _noiseRetries = 0;
    }
    if (_hfNotHeard) {
      setState(() => _hfNotHeard = false);
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
    // Retries stay SILENT: the user was already cued for this card, and
    // each replayed earcon re-contested audio focus and killed the young
    // session (the "bips a few times then skips" loop, field log 2026-07-07).
    if (widget.args.mode == QuizMode.handsFree && !_kTestMode && !isRetry) {
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

    // Hands-free is eyes-off: a "your turn" earcon + haptic on listen start.
    if (ok && widget.args.mode == QuizMode.handsFree && !_kTestMode) {
      unawaited(_sfx.playListenCue());
      HapticFeedback.selectionClick();
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
          if (_stt.isListening) {
            sttLog('[HF] stopping stale listen session from previous card');
            unawaited(_stt.stopListening());
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
        total: quizState.total,
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
    ref.read(quizProvider.notifier).skipCurrentCard();
  }

  /// Hands-free (Mains libres) — eyes-off canvas: word in the wave with the
  /// audio-I/O state machine (frozen + screen-pulse while reading vs animated
  /// while listening), oversized Répéter/Passer, tap-centre to pause, and the
  /// transient full-screen flood for grading.
  Widget _buildHandsFreeStudy(BuildContext context, QuizState s, QuizCard card) {
    final isFrToKo = card.progress.direction == QuizDirection.frToKo;

    if (s.answerState != QuizAnswerState.idle) {
      final correct = s.answerState == QuizAnswerState.correct;
      return StudyFeedbackFlood(
        isCorrect: correct,
        label: correct
            ? 'quiz.feedback_correct'.tr()
            : 'quiz.feedback_wrong'.tr(),
        answer: correct ? null : card.answerWords.join(' / '),
        answerIsKorean: isFrToKo,
        // No onContinue → transient; the provider auto-advances (driving mode).
      );
    }

    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final listening = s.isListening && !_hfPaused;

    final cue = _hfPaused
        ? null
        : (_hfNotHeard
            ? 'quiz.hf_not_heard'.tr()
            : (listening
                ? 'quiz.say_in_lang'.tr(
                    namedArgs: {'lang': 'lang.${_answerLangCode(card)}'.tr()})
                : 'quiz.hf_reading'.tr()));
    final cueColor = listening
        ? (isDark ? AppColors.clayLight : AppColors.clayDeep)
        : (isDark ? AppColors.onDarkMuted : AppColors.muted);

    return StudyScaffold(
      current: s.currentIndex + 1,
      total: s.total,
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
                      child: WordInWave(
                        word: card.questionWord,
                        isKorean: !isFrToKo,
                        cue: cue,
                        cueColor: cueColor,
                        waveActive: listening,
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
    final isFrToKo = card.progress.direction == QuizDirection.frToKo;

    if (s.answerState != QuizAnswerState.idle) {
      final correct = s.answerState == QuizAnswerState.correct;
      return StudyFeedbackFlood(
        isCorrect: correct,
        label: correct
            ? 'quiz.feedback_correct'.tr()
            : 'quiz.feedback_wrong'.tr(),
        answer: card.answerWords.join(' / '),
        answerIsKorean: isFrToKo,
        detail: _nextReviewText(s.scheduledDays, correct),
        continueLabel: 'quiz.continue_button'.tr(),
        onContinue: () => ref.read(quizProvider.notifier).advance(),
      );
    }

    final showBack = s.isFlipped;
    final word = showBack ? card.answerWords.join(' / ') : card.questionWord;
    // Front = question (Korean only when KO→FR); back = answer (Korean when FR→KO).
    final wordIsKorean = showBack ? isFrToKo : !isFrToKo;

    return StudyScaffold(
      current: s.currentIndex + 1,
      total: s.total,
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
    final isFrToKo = card.progress.direction == QuizDirection.frToKo;

    if (s.answerState != QuizAnswerState.idle) {
      final correct = s.answerState == QuizAnswerState.correct;
      return StudyFeedbackFlood(
        isCorrect: correct,
        label: correct
            ? 'quiz.feedback_correct'.tr()
            : 'quiz.feedback_wrong'.tr(),
        answer: card.answerWords.join(' / '),
        answerIsKorean: isFrToKo,
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
      current: s.currentIndex + 1,
      total: s.total,
      onQuit: _quit,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: WordInWave(
                  word: card.questionWord,
                  isKorean: !isFrToKo, // question is Korean when KO→FR
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
    final isFrToKo = card.progress.direction == QuizDirection.frToKo;

    if (s.answerState != QuizAnswerState.idle) {
      final correct = s.answerState == QuizAnswerState.correct;
      return StudyFeedbackFlood(
        isCorrect: correct,
        label: correct
            ? 'quiz.feedback_correct'.tr()
            : 'quiz.feedback_wrong'.tr(),
        answer: card.answerWords.join(' / '),
        answerIsKorean: isFrToKo, // answer is Korean when FR→KO
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
      current: s.currentIndex + 1,
      total: s.total,
      onQuit: _quit,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: WordInWave(
                  word: card.questionWord,
                  isKorean: !isFrToKo, // question is Korean when KO→FR
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
