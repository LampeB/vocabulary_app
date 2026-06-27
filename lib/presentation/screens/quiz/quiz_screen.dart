import 'dart:async' show unawaited;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
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
  late AnimationController _flashCtrl;
  late Animation<Color?> _flashColor;
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
  // Whole-screen warm breathing pulse used during the hands-free reading state.
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _flashCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _flashColor =
        ColorTween(begin: Colors.transparent, end: Colors.transparent)
            .animate(_flashCtrl);
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
                if (ref.read(quizProvider).answerState ==
                    QuizAnswerState.idle) {
                  debugPrint('[HF] ❌ No result arrived in ${waitMs}ms window — submitting empty');
                  ref.read(quizProvider.notifier).submitVoiceAnswer(
                    '',
                    isDrivingMode: true,
                  );
                } else {
                  debugPrint('[HF] ✅ Late onResult arrived before timeout — no action needed');
                }
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
    _flashCtrl.dispose();
    _pulseCtrl.dispose();
    _stt.dispose();
    _sfx.dispose();
    _answerCtrl.dispose();
    super.dispose();
  }

  Future<void> _triggerFlash(bool correct) async {
    _flashColor = ColorTween(
      begin: Colors.transparent,
      end: correct ? AppColors.correctFlash : AppColors.incorrectFlash,
    ).animate(_flashCtrl);
    await _flashCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 700));
    await _flashCtrl.reverse();
  }

  Future<void> _startListening(QuizCard card, {bool isRetry = false}) async {
    if (!isRetry) _listenRetries = 0;
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
        backgroundColor: AppColors.paper,
        body: Center(
          child: CircularProgressIndicator(
              color: AppColors.clay, strokeWidth: 2),
        ),
      );
    }

    if (quizState.errorMessage != null) {
      return Scaffold(
        backgroundColor: AppColors.paper,
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
        backgroundColor: AppColors.paper,
        body: Center(
          child: CircularProgressIndicator(
              color: AppColors.clay, strokeWidth: 2),
        ),
      );
    }

    // Voice mode uses the unified dark study canvas (StudyScaffold + word-in-wave).
    if (widget.args.mode == QuizMode.voice) {
      return _buildVoiceStudy(context, quizState, card);
    }

    // Cartes (flashcard) on the unified study canvas.
    if (widget.args.mode == QuizMode.flashcard) {
      return _buildCartesStudy(context, quizState, card);
    }

    // Écrire (typing) on the unified study canvas (native keyboard).
    if (widget.args.mode == QuizMode.typing) {
      return _buildEcrireStudy(context, quizState, card);
    }

    // Hands-free on the unified study canvas (eyes-off state machine).
    if (widget.args.mode == QuizMode.handsFree) {
      return _buildHandsFreeStudy(context, quizState, card);
    }

    // Dedicated feedback screen for typing mode (flashcard/voice/hands-free handled elsewhere).
    if (quizState.answerState != QuizAnswerState.idle &&
        widget.args.mode != QuizMode.flashcard &&
        widget.args.mode != QuizMode.handsFree) {
      return _AnswerFeedback(
        isCorrect: quizState.answerState == QuizAnswerState.correct,
        card: card,
        direction: card.progress.direction,
        scheduledDays: quizState.scheduledDays,
        currentIndex: quizState.currentIndex + 1,
        total: quizState.total,
        onContinue: () => ref.read(quizProvider.notifier).advance(),
        onClose: () {
          _stt.stopListening();
          ref.read(quizProvider.notifier).setListening(false);
          context.go('/home');
        },
      );
    }

    return AnimatedBuilder(
      animation: _flashCtrl,
      builder: (ctx, child) => ColoredBox(
        color: _flashColor.value ?? Colors.transparent,
        child: child,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            const DottedGround(),
            SafeArea(
              child: Column(
                children: [
                  // Progress header
                  _ProgressHeader(
                    current: quizState.currentIndex + 1,
                    total: quizState.total,
                    onClose: () {
                      _stt.stopListening();
                      ref.read(quizProvider.notifier).setListening(false);
                      context.go('/home');
                    },
                  ),
                  // Card + input
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      child: Column(
                        children: [
                          Expanded(
                            child: _CardView(
                              card: card,
                              isFlipped: quizState.isFlipped,
                              answerState: quizState.answerState,
                              mode: widget.args.mode,
                              isListening: quizState.isListening,
                              onFlip: () =>
                                  ref.read(quizProvider.notifier).flipCard(),
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildInputArea(quizState, card),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
        : (listening
            ? 'quiz.say_in_lang'.tr(
                namedArgs: {'lang': 'lang.${_answerLangCode(card)}'.tr()})
            : 'quiz.hf_reading'.tr());
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

  Widget _buildInputArea(QuizState quizState, QuizCard card) {
    return switch (widget.args.mode) {
      QuizMode.flashcard => _FlashcardRating(
          isFlipped: quizState.isFlipped,
          onRate: (rating) {
            final isCorrect = rating != FsrsRating.again;
            unawaited(_triggerFlash(isCorrect));
            if (isCorrect) { _sfx.playCorrect(); } else { _sfx.playIncorrect(); }
            ref.read(quizProvider.notifier).rateCard(rating);
          },
        ),
      QuizMode.typing => _TypingInput(
          controller: _answerCtrl,
          answerState: quizState.answerState,
          correctAnswers: card.answerWords,
          onSubmit: (answer) {
            ref.read(quizProvider.notifier).submitTextAnswer(answer);
            _answerCtrl.clear();
          },
        ),
      QuizMode.voice || QuizMode.handsFree => _VoiceInput(
          isListening: quizState.isListening,
          partialTranscript: quizState.partialTranscript,
          answerState: quizState.answerState,
          onMicTap: () => _startListening(card),
          isHandsFree: widget.args.mode == QuizMode.handsFree,
        ),
    };
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

// ── Progress header ───────────────────────────────────────────────────────────

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({
    required this.current,
    required this.total,
    required this.onClose,
  });
  final int current;
  final int total;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final progress = total > 0 ? current / total : 0.0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded,
                color: AppColors.muted, size: 22),
            onPressed: onClose,
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: AppColors.line,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.teal),
                minHeight: 6,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${current.toString().padLeft(2, '0')}/${total.toString().padLeft(2, '0')}',
            style: AppTextStyles.counter.copyWith(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

// ── Card view ─────────────────────────────────────────────────────────────────

class _CardView extends StatelessWidget {
  const _CardView({
    required this.card,
    required this.isFlipped,
    required this.answerState,
    required this.mode,
    required this.isListening,
    required this.onFlip,
  });

  final QuizCard card;
  final bool isFlipped;
  final QuizAnswerState answerState;
  final QuizMode mode;
  final bool isListening;
  final VoidCallback onFlip;

  @override
  Widget build(BuildContext context) {
    final isFlashcard = mode == QuizMode.flashcard;
    final isHandsFree = mode == QuizMode.handsFree;
    final isFrToKo    = card.direction == QuizDirection.frToKo;
    final qLabel      = isFrToKo ? 'list_detail.lang_fr'.tr() : 'list_detail.lang_kr'.tr();
    final aLabel      = isFrToKo ? 'list_detail.lang_kr'.tr() : 'list_detail.lang_fr'.tr();
    final qColor      = isFrToKo ? AppColors.tealDark : AppColors.clayDark;
    final aColor      = isFrToKo ? AppColors.clayDark : AppColors.tealDark;
    final answerText  = card.answerWords.join(' / ');
    final isKrAnswer  = isFrToKo; // Korean is the answer when FR→KO

    // Show the answer only after an explicit action — never both sides at once.
    // • Flashcard: after the user taps to flip.
    // • Hands-free: after voice answer is processed (answerState leaves idle).
    // • Typing / voice: feedback screen takes over; card stays question-only.
    final showAnswer = isFlipped ||
        (isHandsFree && answerState != QuizAnswerState.idle);

    return GestureDetector(
      onTap: isFlashcard && !isFlipped ? onFlip : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Container(
          width: double.infinity,
          color: AppColors.inkDark,
          child: Stack(
            children: [
              // Dot grid on dark
              const DottedGround(dark: true),
              // Waveform watermark
              Positioned.fill(
                child: Center(
                  child: VkWaveform(
                    height: 120,
                    barWidth: 10,
                    gap: 6,
                    // Comes alive while the mic is listening; flat and still
                    // otherwise so it doubles as the listening indicator.
                    opacity: isListening ? 0.32 : 0.2,
                    isAnimating: isListening,
                    flatAtRest: true,
                  ),
                ),
              ),
              // Card content
              Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Question side
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(qLabel,
                          style: AppTextStyles.eyebrow
                              .copyWith(color: qColor)),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      card.questionWord,
                      style: isFrToKo
                          ? AppTextStyles.promptWord
                              .copyWith(color: AppColors.onDark)
                          : AppTextStyles.koreanPrompt
                              .copyWith(color: AppColors.onDark),
                      textAlign: TextAlign.center,
                    ),
                    // Answer side
                    if (showAnswer) ...[
                      const SizedBox(height: 28),
                      const Divider(
                          color: Color(0x33FFFFFF), thickness: 1),
                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(aLabel,
                            style: AppTextStyles.eyebrow
                                .copyWith(color: aColor)),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        answerText.isNotEmpty ? answerText : '—',
                        style: isKrAnswer
                            ? AppTextStyles.koreanPrompt.copyWith(
                                fontSize: 40,
                                color: AppColors.onDark)
                            : AppTextStyles.grotesk(
                                    40, FontWeight.w700)
                                .copyWith(color: AppColors.onDark),
                        textAlign: TextAlign.center,
                      ),
                    ] else if (isFlashcard) ...[
                      const SizedBox(height: 40),
                      Text(
                        'quiz.card_flip_hint'.tr(),
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.onDarkFaint),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Flashcard rating ──────────────────────────────────────────────────────────

class _FlashcardRating extends StatelessWidget {
  const _FlashcardRating({required this.isFlipped, required this.onRate});
  final bool isFlipped;
  final ValueChanged<FsrsRating> onRate;

  @override
  Widget build(BuildContext context) {
    if (!isFlipped) {
      return Container(
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.line.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text('quiz.flashcard_rate_hint'.tr(),
              style: AppTextStyles.caption.copyWith(color: AppColors.faint)),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => onRate(FsrsRating.again),
            child: Container(
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.rose,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.close_rounded,
                      color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text('quiz.rate_wrong'.tr(),
                      style: AppTextStyles.fig(15, FontWeight.w700)
                          .copyWith(color: Colors.white)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () => onRate(FsrsRating.good),
            child: Container(
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.teal,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_rounded,
                      color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text('quiz.rate_correct'.tr(),
                      style: AppTextStyles.fig(15, FontWeight.w700)
                          .copyWith(color: Colors.white)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Typing input ──────────────────────────────────────────────────────────────

class _TypingInput extends StatelessWidget {
  const _TypingInput({
    required this.controller,
    required this.answerState,
    required this.correctAnswers,
    required this.onSubmit,
  });
  final TextEditingController controller;
  final QuizAnswerState answerState;
  final List<String> correctAnswers;
  final ValueChanged<String> onSubmit;

  @override
  Widget build(BuildContext context) {
    final isAnswered = answerState != QuizAnswerState.idle;
    final isCorrect  = answerState == QuizAnswerState.correct;
    final feedbackColor = isCorrect ? AppColors.teal : AppColors.rose;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isAnswered) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: feedbackColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(
                  isCorrect
                      ? Icons.check_circle_rounded
                      : Icons.cancel_rounded,
                  color: feedbackColor,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isCorrect
                        ? 'quiz.typing_correct'.tr()
                        : 'quiz.typing_wrong_prefix'.tr() + correctAnswers.join(' / '),
                    style: AppTextStyles.fig(14, FontWeight.w600)
                        .copyWith(color: feedbackColor),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: !isAnswered,
                autofocus: !isAnswered,
                decoration: InputDecoration(
                  hintText: 'quiz.typing_hint'.tr(),
                  fillColor: isAnswered
                      ? feedbackColor.withValues(alpha: 0.06)
                      : null,
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: isAnswered ? null : onSubmit,
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: isAnswered ? null : () => onSubmit(controller.text),
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: isAnswered ? AppColors.line : AppColors.clay,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.send_rounded,
                    color: isAnswered ? AppColors.faint : Colors.white,
                    size: 20),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Voice input ───────────────────────────────────────────────────────────────

class _VoiceInput extends StatelessWidget {
  const _VoiceInput({
    required this.isListening,
    required this.partialTranscript,
    required this.answerState,
    required this.onMicTap,
    required this.isHandsFree,
  });
  final bool isListening;
  final String partialTranscript;
  final QuizAnswerState answerState;
  final VoidCallback onMicTap;
  final bool isHandsFree;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (partialTranscript.isNotEmpty) ...[
          Text(partialTranscript,
              style: AppTextStyles.fig(16, FontWeight.w500)
                  .copyWith(color: AppColors.muted)),
          const SizedBox(height: 12),
        ],
        MicButton(
          key: const Key('mic_button'),
          isListening: isListening,
          answerState: answerState,
          onTap: onMicTap,
        ),
        if (isHandsFree) ...[
          const SizedBox(height: 8),
          Text('quiz.hands_free_label'.tr(),
              style: AppTextStyles.eyebrowSm
                  .copyWith(color: AppColors.faint)),
        ],
      ],
    );
  }
}

// ── Answer feedback screen ────────────────────────────────────────────────────

class _AnswerFeedback extends StatelessWidget {
  const _AnswerFeedback({
    required this.isCorrect,
    required this.card,
    required this.direction,
    required this.scheduledDays,
    required this.currentIndex,
    required this.total,
    required this.onContinue,
    required this.onClose,
  });

  final bool isCorrect;
  final QuizCard card;
  final QuizDirection direction;
  final int scheduledDays;
  final int currentIndex;
  final int total;
  final VoidCallback onContinue;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final accent = isCorrect
        ? (isDark ? AppColors.tealDark : AppColors.teal)
        : (isDark ? AppColors.clayDark : AppColors.clay);
    final label = isCorrect ? 'quiz.feedback_correct'.tr() : 'quiz.feedback_wrong'.tr();

    final nextText = isCorrect
        ? (scheduledDays <= 1
            ? 'quiz.next_review_tomorrow'.tr()
            : 'quiz.next_review_in_days'.tr(namedArgs: {'days': scheduledDays.toString()}))
        : 'quiz.next_review_soon'.tr();

    final isFrToKo = direction == QuizDirection.frToKo;
    final answerText = card.answerWords.join(' / ');
    final isKrAnswer = isFrToKo;
    final qLabel = isFrToKo ? 'list_detail.lang_fr'.tr() : 'list_detail.lang_kr'.tr();
    final aLabel = isFrToKo ? 'list_detail.lang_kr'.tr() : 'list_detail.lang_fr'.tr();
    final qColor = isFrToKo ? AppColors.tealDark : AppColors.clayDark;
    final aColor = isFrToKo ? AppColors.clayDark : AppColors.tealDark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Tinted background
          ColoredBox(
            color: accent.withValues(alpha: isDark ? 0.12 : 0.07),
            child: const SizedBox.expand(),
          ),
          const DottedGround(),
          SafeArea(
            child: Column(
              children: [
                // Progress header (reused)
                _ProgressHeader(
                  current: currentIndex,
                  total: total,
                  onClose: onClose,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Icon badge
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isCorrect
                                ? Icons.check_rounded
                                : Icons.close_rounded,
                            color: accent,
                            size: 38,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(label,
                            style: AppTextStyles.eyebrow
                                .copyWith(color: accent)),
                        const SizedBox(height: 6),
                        Text(nextText,
                            style: AppTextStyles.fig(14, FontWeight.w500)
                                .copyWith(
                                    color: isDark
                                        ? AppColors.onDarkMuted
                                        : AppColors.muted)),
                        const SizedBox(height: 28),
                        // Answer card — same dark card as the quiz
                        ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Container(
                            width: double.infinity,
                            color: AppColors.inkDark,
                            child: Stack(
                              children: [
                                const DottedGround(dark: true),
                                Padding(
                                  padding: const EdgeInsets.all(28),
                                  child: Column(
                                    children: [
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(qLabel,
                                            style: AppTextStyles.eyebrow
                                                .copyWith(color: qColor)),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        card.questionWord,
                                        style: isFrToKo
                                            ? AppTextStyles.promptWord.copyWith(
                                                color: AppColors.onDark,
                                                fontSize: 36)
                                            : AppTextStyles.koreanPrompt
                                                .copyWith(
                                                    color: AppColors.onDark,
                                                    fontSize: 38),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 18),
                                      const Divider(
                                          color: Color(0x33FFFFFF),
                                          thickness: 1),
                                      const SizedBox(height: 16),
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(aLabel,
                                            style: AppTextStyles.eyebrow
                                                .copyWith(color: aColor)),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        answerText.isNotEmpty ? answerText : '—',
                                        style: isKrAnswer
                                            ? AppTextStyles.koreanPrompt
                                                .copyWith(
                                                    color: AppColors.onDark,
                                                    fontSize: 36)
                                            : AppTextStyles.grotesk(
                                                    36, FontWeight.w700)
                                                .copyWith(
                                                    color: AppColors.onDark),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Spacer(),
                        // Continuer button
                        SizedBox(
                          width: double.infinity,
                          child: GestureDetector(
                            onTap: onContinue,
                            child: Container(
                              height: 56,
                              decoration: BoxDecoration(
                                color: accent,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Center(
                                child: Text(
                                  'quiz.continue_button'.tr(),
                                  style: AppTextStyles.fig(16, FontWeight.w700)
                                      .copyWith(color: Colors.white),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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
      backgroundColor: AppColors.paper,
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
