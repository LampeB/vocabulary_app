import 'dart:async' show unawaited;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/quiz/quiz_provider.dart';
import '../../../domain/entities/variant_progress.dart' show QuizDirection;
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/fsrs_algorithm.dart';
import '../../../services/speech/speech_recognition_service.dart';
import '../../../services/audio/sound_effects_service.dart';
import '../../widgets/dotted_ground.dart';
import '../../widgets/vk_waveform.dart';
import '../../widgets/mic_button.dart';

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

  @override
  void initState() {
    super.initState();
    _flashCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _flashColor =
        ColorTween(begin: Colors.transparent, end: Colors.transparent)
            .animate(_flashCtrl);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_kSimulateSpeech.isEmpty) {
        final ok = await _stt.initialize();
        if (!ok && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Microphone non disponible — vérifie les permissions dans les réglages.'),
            behavior: SnackBarBehavior.floating,
          ));
        }
      }
      // When STT finishes (timeout, error, no language pack), sync the quiz state.
      _stt.onListeningDone = () {
        if (mounted) ref.read(quizProvider.notifier).setListening(false);
      };
      if (mounted) ref.read(quizProvider.notifier).loadCards(widget.args);
    });
  }

  @override
  void dispose() {
    _flashCtrl.dispose();
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
    await _flashCtrl.reverse();
    if (correct) {
      _sfx.playCorrect();
    } else {
      _sfx.playIncorrect();
    }
  }

  Future<void> _startListening(QuizCard card) async {
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
        isDrivingMode: widget.args.mode == QuizMode.handsFree,
      );
      return;
    }

    final langCode =
        widget.args.direction == QuizDirection.koToFr ? 'fr' : 'ko';
    final ok = await _stt.startListening(
      langCode: langCode,
      onResult: (text) {
        ref.read(quizProvider.notifier).submitVoiceAnswer(
              text,
              isDrivingMode: widget.args.mode == QuizMode.handsFree,
            );
      },
      onPartial: (text) {
        ref.read(quizProvider.notifier).setPartialTranscript(text);
      },
    );
    // If STT couldn't start (not initialised, no language pack, etc.) reset
    // the listening state so the UI doesn't get permanently stuck.
    if (!ok && mounted) {
      ref.read(quizProvider.notifier).setListening(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final quizState = ref.watch(quizProvider);

    ref.listen<QuizState>(quizProvider, (prev, next) {
      if (prev?.answerState == QuizAnswerState.idle &&
          next.answerState != QuizAnswerState.idle) {
        unawaited(_triggerFlash(next.answerState == QuizAnswerState.correct));
      }
      if (widget.args.mode == QuizMode.handsFree) {
        final cardChanged = prev?.currentIndex != next.currentIndex;
        final justLoaded = prev?.isLoading == true && !next.isLoading;
        final card = next.currentCard;
        if ((cardChanged || justLoaded) && card != null && !next.isComplete) {
          Future.delayed(const Duration(milliseconds: 1500), () {
            if (mounted && !_stt.isListening) {
              unawaited(_startListening(card));
            }
          });
        }
      }
    });

    if (quizState.isLoading) {
      return Scaffold(
        backgroundColor: AppColors.paper,
        body: const Center(
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
                    child: Text('Retour',
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
      return Scaffold(
        backgroundColor: AppColors.paper,
        body: const Center(
          child: CircularProgressIndicator(
              color: AppColors.clay, strokeWidth: 2),
        ),
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
                    onClose: () => context.go('/home'),
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
                              direction: widget.args.direction,
                              isFlipped: quizState.isFlipped,
                              mode: widget.args.mode,
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

  Widget _buildInputArea(QuizState quizState, QuizCard card) {
    return switch (widget.args.mode) {
      QuizMode.flashcard => _FlashcardRating(
          isFlipped: quizState.isFlipped,
          onRate: (rating) {
            unawaited(_triggerFlash(rating != FsrsRating.again));
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
    final progress = total > 0 ? (current - 1) / total : 0.0;
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
    required this.direction,
    required this.isFlipped,
    required this.mode,
    required this.onFlip,
  });

  final QuizCard card;
  final QuizDirection direction;
  final bool isFlipped;
  final QuizMode mode;
  final VoidCallback onFlip;

  @override
  Widget build(BuildContext context) {
    final isFlashcard = mode == QuizMode.flashcard;
    final isFrToKo    = direction == QuizDirection.frToKo;
    final qLabel      = isFrToKo ? 'FR' : 'KR';
    final aLabel      = isFrToKo ? 'KR' : 'FR';
    final qColor      = isFrToKo ? AppColors.tealDark : AppColors.clayDark;
    final aColor      = isFrToKo ? AppColors.clayDark : AppColors.tealDark;
    final answerText  = card.answerWords.join(' / ');
    final isKrAnswer  = isFrToKo; // Korean is the answer when FR→KO

    final showAnswer = !isFlashcard || isFlipped;

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
                    opacity: 0.2,
                    isAnimating: false,
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
                    ] else ...[
                      // Tap hint for flashcard front
                      const SizedBox(height: 40),
                      Text(
                        'Appuyer pour révéler',
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
          child: Text('Retournez la carte pour noter',
              style: AppTextStyles.caption.copyWith(color: AppColors.faint)),
        ),
      );
    }

    return Row(
      children: [
        _RatingPill(
            label: 'Encore',
            color: AppColors.rose,
            onTap: () => onRate(FsrsRating.again)),
        const SizedBox(width: 6),
        _RatingPill(
            label: 'Difficile',
            color: AppColors.clayDeep,
            onTap: () => onRate(FsrsRating.hard)),
        const SizedBox(width: 6),
        _RatingPill(
            label: 'Bien',
            color: AppColors.teal,
            onTap: () => onRate(FsrsRating.good)),
        const SizedBox(width: 6),
        _RatingPill(
            label: 'Facile',
            color: AppColors.tealLight,
            onTap: () => onRate(FsrsRating.easy)),
      ],
    );
  }
}

class _RatingPill extends StatelessWidget {
  const _RatingPill(
      {required this.label, required this.color, required this.onTap});
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Text(label,
                style: AppTextStyles.fig(12, FontWeight.w700)
                    .copyWith(color: Colors.white)),
          ),
        ),
      ),
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
                        ? 'Correct !'
                        : 'Réponse : ${correctAnswers.join(' / ')}',
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
                  hintText: 'Tapez votre réponse…',
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
          Text('MAINS LIBRES',
              style: AppTextStyles.eyebrowSm
                  .copyWith(color: AppColors.faint)),
        ],
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
      backgroundColor: AppColors.inkDark,
      body: Stack(
        children: [
          const DottedGround(dark: true),
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
                    Text('SESSION TERMINÉE',
                        style: AppTextStyles.eyebrow
                            .copyWith(color: AppColors.onDarkFaint)),
                    const SizedBox(height: 12),
                    // Big accuracy
                    Text(
                      '$pct %',
                      style: AppTextStyles.heroNumber.copyWith(
                        color: isGreat
                            ? AppColors.clayDark
                            : AppColors.onDarkMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$correct / $total corrects',
                      style: AppTextStyles.fig(16, FontWeight.w500)
                          .copyWith(color: AppColors.onDarkMuted),
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
                                color: Colors.white
                                    .withValues(alpha: 0.08),
                                borderRadius:
                                    BorderRadius.circular(16),
                                border: Border.all(
                                    color: Colors.white
                                        .withValues(alpha: 0.18)),
                              ),
                              child: Center(
                                child: Text('Recommencer',
                                    style: AppTextStyles
                                        .fig(14, FontWeight.w600)
                                        .copyWith(
                                            color:
                                                AppColors.onDarkMuted)),
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
                                child: Text('Accueil',
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
