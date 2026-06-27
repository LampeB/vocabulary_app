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
import '../../../core/utils/fsrs_algorithm.dart';
import '../../../services/speech/speech_recognition_service.dart';
import '../../../services/audio/sound_effects_service.dart';
import '../../widgets/dotted_ground.dart';
import '../../widgets/vk_waveform.dart';
import '../../widgets/mic_button.dart';
import '../../widgets/study/study_scaffold.dart';
import '../../widgets/study/word_in_wave.dart';
import '../../widgets/study/study_feedback_flood.dart';

const _kSimulateSpeech = String.fromEnvironment('SIMULATE_SPEECH');

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
  // Whole-screen warm breathing pulse used during the hands-free reading state.
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1900))
      ..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_kSimulateSpeech.isEmpty) {
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
      _stt.onError = (msg) {
        if (!mounted) return;
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
        debugPrint('[HF] onListeningDone  capturedToken=$capturedToken  currentToken=$_listenToken  elapsed=${elapsed}ms  answerState=${state.answerState}  retries=$_listenRetries');
        ref.read(quizProvider.notifier).setListening(false);

        if (state.answerState == QuizAnswerState.idle) {
          if (widget.args.mode == QuizMode.handsFree) {
            // If the token changed, this callback is stale (a new listen
            // session already started) — ignore it to avoid double-penalising.
            if (capturedToken != _listenToken) {
              debugPrint('[HF] ⚠️ Stale callback (token mismatch) — ignoring');
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
              debugPrint('[HF] 🔁 STT stopped too fast (${elapsed}ms) — retry #$_listenRetries in 700ms');
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
              debugPrint('[HF] Waiting ${waitMs}ms for possible late Samsung onResult before submitting empty (elapsed=${elapsed}ms  permanentError=$wasPermanentError  retries=$_listenRetries)');
              _listenRetries = 0;
              Future.delayed(Duration(milliseconds: waitMs), () {
                if (!mounted) return;
                if (ref.read(quizProvider).answerState !=
                    QuizAnswerState.idle) {
                  debugPrint('[HF] ✅ Late onResult arrived before timeout');
                  return;
                }
                // "Pas entendu": a real listen heard nothing. Re-listen up to
                // twice with a muted cue before requeuing as à revoir, so
                // silence isn't a hard wrong (ties into the STT-improvement plan).
                if (hadRealListen &&
                    !wasPermanentError &&
                    _notHeardRetries < 2) {
                  _notHeardRetries++;
                  debugPrint('[HF] 🔇 Pas entendu — re-listen #$_notHeardRetries');
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
                debugPrint('[HF] ❌ No result after retries — requeue (à revoir)');
                ref.read(quizProvider.notifier).submitVoiceAnswer(
                      '',
                      isDrivingMode: true,
                    );
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
          debugPrint('[HF] onListeningDone: answerState already ${state.answerState} — no action needed');
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

  Future<void> _startListening(QuizCard card, {bool isRetry = false}) async {
    if (!isRetry) {
      _listenRetries = 0;
      _notHeardRetries = 0;
    }
    if (_hfNotHeard) setState(() => _hfNotHeard = false);
    _listenToken++;
    debugPrint('[HF] _startListening  token=$_listenToken  isRetry=$isRetry  question="${card.questionWord}"  answerWords=${card.answerWords}');
    ref.read(quizProvider.notifier).setListening(true);

    if (_kSimulateSpeech.isNotEmpty) {
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      final answer = switch (_kSimulateSpeech) {
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
    debugPrint('[HF] Triggering audio stop + 300ms focus-handover wait');
    unawaited(ref.read(audioPlayerServiceProvider).stop());
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    final currentDir = ref.read(quizProvider).currentCard?.progress.direction;
    final langCode =
        currentDir == QuizDirection.koToFr ? 'fr' : 'ko';
    // Capture token so late-arriving onResult from this session is ignored
    // once a new session (next card) has started.
    final sessionToken = _listenToken;
    debugPrint('[HF] Calling stt.startListening  langCode=$langCode  token=$sessionToken');
    final ok = await _stt.startListening(
      langCode: langCode,
      onResult: (text) {
        // Samsung STT can fire the final onResult 1-2s AFTER notListening.
        // Guard with the captured token so a late result from card N isn't
        // applied to card N+1.
        debugPrint('[HF] onResult: "$text"  sessionToken=$sessionToken  currentToken=$_listenToken  match=${sessionToken == _listenToken}');
        if (mounted && sessionToken == _listenToken) {
          ref.read(quizProvider.notifier).submitVoiceAnswer(
                text,
                isDrivingMode: widget.args.mode == QuizMode.handsFree ||
                widget.args.mode == QuizMode.voice,
              );
        } else if (sessionToken != _listenToken) {
          debugPrint('[HF] Late onResult discarded (stale token)');
        }
      },
      onPartial: (text) {
        debugPrint('[HF] partial: "$text"');
        if (mounted && sessionToken == _listenToken) {
          ref.read(quizProvider.notifier).setPartialTranscript(text);
        }
      },
    );
    debugPrint('[HF] stt.startListening returned ok=$ok  token=$_listenToken');
    if (!ok && mounted) {
      debugPrint('[HF] ❌ STT failed to start — clearing listening state');
      ref.read(quizProvider.notifier).setListening(false);
      return;
    }

    // Hands-free is eyes-off: a "your turn" earcon + haptic on listen start.
    if (ok && widget.args.mode == QuizMode.handsFree) {
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
        debugPrint('[HF] ⏰ Failsafe timeout for token=$sessionToken — stopping STT');
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
        // Sound effect for every mode.
        if (correct) { _sfx.playCorrect(); } else { _sfx.playIncorrect(); }
        // Hands-free is eyes-off: pair the earcon with a distinct haptic.
        if (widget.args.mode == QuizMode.handsFree) {
          if (correct) {
            HapticFeedback.mediumImpact();
          } else {
            HapticFeedback.heavyImpact();
          }
        }
        // Auto-speak the revealed answer (typing / voice modes).
        // In hands-free mode only speak when wrong — the user just said the
        // word correctly, no need to repeat it; but for a wrong answer they
        // need to hear the correct pronunciation before moving on.
        final shouldSpeak = widget.args.mode != QuizMode.flashcard &&
            (widget.args.mode != QuizMode.handsFree || !correct);
        if (shouldSpeak) {
          final card = next.currentCard;
          if (card != null && card.answerWords.isNotEmpty) {
            final answerLang =
                card.progress.direction == QuizDirection.frToKo ? 'ko' : 'fr';
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
          debugPrint('[HF] Card trigger: cardChanged=$cardChanged justLoaded=$justLoaded cardsJustAppeared=$cardsJustAppeared  idx=${next.currentIndex}  question="${card.questionWord}"  answers=${card.answerWords}');
          debugPrint('[HF] Scheduling _startListening in 300ms...');
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted && !_stt.isListening) {
              debugPrint('[HF] 300ms elapsed — calling _startListening');
              unawaited(_startListening(card));
            } else {
              debugPrint('[HF] 300ms elapsed but mounted=$mounted stt.isListening=${_stt.isListening} — skipping');
            }
          });
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
    setState(() => _hfPaused = !_hfPaused);
    if (_hfPaused) {
      _stt.stopListening();
      ref.read(quizProvider.notifier).setListening(false);
      unawaited(ref.read(audioPlayerServiceProvider).stop());
    } else {
      final card = ref.read(quizProvider).currentCard;
      if (card != null) unawaited(_startListening(card));
    }
  }

  void _hfRepeat() {
    final card = ref.read(quizProvider).currentCard;
    if (card == null) return;
    final questionLang =
        card.progress.direction == QuizDirection.frToKo ? 'fr' : 'ko';
    unawaited(ref
        .read(audioPlayerServiceProvider)
        .speak(card.questionWord, questionLang));
    unawaited(_startListening(card));
  }

  void _hfSkip() {
    _stt.stopListening();
    ref.read(quizProvider.notifier).submitVoiceAnswer('', isDrivingMode: true);
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
          // Reading state: whole-canvas warm breathing pulse.
          if (!listening && !_hfPaused)
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
                          icon: Icons.replay_rounded,
                          label: 'quiz.hf_repeat'.tr(),
                          onTap: _hfRepeat,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _HfButton(
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
                        Icon(Icons.pause_rounded,
                            size: 56, color: cs.onSurface),
                        const SizedBox(height: 10),
                        Text('quiz.hf_paused'.tr(),
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
      card.progress.direction == QuizDirection.frToKo ? 'ko' : 'fr';

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
                    icon: Icons.visibility_outlined,
                    label: 'quiz.voice_reveal'.tr(),
                    onTap: () {
                      _stt.stopListening();
                      ref.read(quizProvider.notifier).submitVoiceAnswer('');
                    },
                  ),
                  const SizedBox(width: 12),
                  _EscapePill(
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
            Text(label,
                style: AppTextStyles.fig(15, FontWeight.w700)
                    .copyWith(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

// ── Hands-free oversized control ──────────────────────────────────────────────

class _HfButton extends StatelessWidget {
  const _HfButton({
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
