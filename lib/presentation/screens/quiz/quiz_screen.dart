import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/quiz/quiz_provider.dart';
import '../../../domain/entities/variant_progress.dart' show QuizDirection;
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/fsrs_algorithm.dart';
import '../../../services/speech/speech_recognition_service.dart';
import '../../../services/audio/sound_effects_service.dart';
import '../../widgets/mic_button.dart';

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
    _flashColor = ColorTween(begin: Colors.transparent, end: Colors.transparent)
        .animate(_flashCtrl);
    _stt.initialize();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(quizProvider.notifier).loadCards([]);
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

  Future<void> _startListening(List<String> acceptedAnswers) async {
    ref.read(quizProvider.notifier).setListening(true);
    final langCode =
        widget.args.direction == QuizDirection.koToFr ? 'fr' : 'ko';
    await _stt.startListening(
      langCode: langCode,
      onResult: (text) {
        ref.read(quizProvider.notifier).submitVoiceAnswer(
              text,
              acceptedAnswers,
              isDrivingMode: widget.args.mode == QuizMode.handsFree,
            );
      },
      onPartial: (text) {
        ref.read(quizProvider.notifier).setPartialTranscript(text);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final quizState = ref.watch(quizProvider);
    final tt = Theme.of(context).textTheme;

    if (quizState.isComplete) {
      return _SummaryScreen(
        correct: quizState.correctCount,
        total: quizState.total,
        onDone: () => context.go('/home'),
      );
    }

    final card = quizState.currentCard;
    if (card == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return AnimatedBuilder(
      animation: _flashCtrl,
      builder: (ctx, child) => Container(
        color: _flashColor.value,
        child: child,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => context.go('/home'),
          ),
          title: LinearProgressIndicator(
            value: quizState.currentIndex / quizState.total,
            backgroundColor: AppColors.grey300,
            valueColor:
                const AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '${quizState.currentIndex + 1}/${quizState.total}',
                  style: tt.bodyMedium,
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Expanded(
                  child: _CardView(
                    card: card,
                    direction: widget.args.direction,
                    isFlipped: quizState.isFlipped,
                    mode: widget.args.mode,
                    onFlip: () => ref.read(quizProvider.notifier).flipCard(),
                  ),
                ),
                const SizedBox(height: 24),
                _buildInputArea(quizState, []),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea(QuizState quizState, List<String> acceptedAnswers) {
    return switch (widget.args.mode) {
      QuizMode.flashcard => _FlashcardRating(
          isFlipped: quizState.isFlipped,
          onRate: (rating) {
            _triggerFlash(rating != FsrsRating.again);
            ref.read(quizProvider.notifier).rateCard(rating);
          },
        ),
      QuizMode.typing => _TypingInput(
          controller: _answerCtrl,
          answerState: quizState.answerState,
          onSubmit: (answer) {
            ref
                .read(quizProvider.notifier)
                .submitTextAnswer(answer, acceptedAnswers);
            _answerCtrl.clear();
          },
        ),
      QuizMode.voice || QuizMode.handsFree => _VoiceInput(
          isListening: quizState.isListening,
          partialTranscript: quizState.partialTranscript,
          answerState: quizState.answerState,
          onMicTap: () => _startListening(acceptedAnswers),
          isHandsFree: widget.args.mode == QuizMode.handsFree,
        ),
    };
  }
}

class _CardView extends StatelessWidget {
  const _CardView({
    required this.card,
    required this.direction,
    required this.isFlipped,
    required this.mode,
    required this.onFlip,
  });

  final dynamic card;
  final QuizDirection direction;
  final bool isFlipped;
  final QuizMode mode;
  final VoidCallback onFlip;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final questionLang =
        direction == QuizDirection.frToKo ? '🇫🇷 French' : '🇰🇷 Korean';

    return GestureDetector(
      onTap: mode == QuizMode.flashcard ? onFlip : null,
      child: Card(
        elevation: 4,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(questionLang,
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: AppColors.grey500)),
                const SizedBox(height: 16),
                Text(
                  '...',
                  style: tt.displayMedium,
                  textAlign: TextAlign.center,
                ),
                if (mode == QuizMode.flashcard && !isFlipped) ...[
                  const SizedBox(height: 24),
                  const Text('Tap to reveal',
                      style: TextStyle(color: AppColors.grey500)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FlashcardRating extends StatelessWidget {
  const _FlashcardRating({required this.isFlipped, required this.onRate});
  final bool isFlipped;
  final ValueChanged<FsrsRating> onRate;

  @override
  Widget build(BuildContext context) {
    if (!isFlipped) return const SizedBox.shrink();
    return Row(
      children: [
        Expanded(
            child: _RatingButton(
                label: 'Again',
                color: AppColors.secondary,
                onTap: () => onRate(FsrsRating.again))),
        const SizedBox(width: 8),
        Expanded(
            child: _RatingButton(
                label: 'Hard',
                color: AppColors.warning,
                onTap: () => onRate(FsrsRating.hard))),
        const SizedBox(width: 8),
        Expanded(
            child: _RatingButton(
                label: 'Good',
                color: AppColors.success,
                onTap: () => onRate(FsrsRating.good))),
        const SizedBox(width: 8),
        Expanded(
            child: _RatingButton(
                label: 'Easy',
                color: AppColors.primary,
                onTap: () => onRate(FsrsRating.easy))),
      ],
    );
  }
}

class _RatingButton extends StatelessWidget {
  const _RatingButton(
      {required this.label, required this.color, required this.onTap});
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      style: FilledButton.styleFrom(backgroundColor: color),
      onPressed: onTap,
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}

class _TypingInput extends StatelessWidget {
  const _TypingInput({
    required this.controller,
    required this.answerState,
    required this.onSubmit,
  });
  final TextEditingController controller;
  final QuizAnswerState answerState;
  final ValueChanged<String> onSubmit;

  @override
  Widget build(BuildContext context) {
    final isAnswered = answerState != QuizAnswerState.idle;
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            enabled: !isAnswered,
            decoration: InputDecoration(
              hintText: 'Type your answer...',
              fillColor: switch (answerState) {
                QuizAnswerState.correct =>
                  AppColors.success.withOpacity(0.1),
                QuizAnswerState.incorrect =>
                  AppColors.secondary.withOpacity(0.1),
                _ => null,
              },
            ),
            onSubmitted: onSubmit,
          ),
        ),
        const SizedBox(width: 12),
        IconButton.filled(
          onPressed: isAnswered ? null : () => onSubmit(controller.text),
          icon: const Icon(Icons.send),
        ),
      ],
    );
  }
}

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
      children: [
        if (partialTranscript.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(partialTranscript,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: AppColors.grey700)),
          ),
        MicButton(
          isListening: isListening,
          answerState: answerState,
          onTap: onMicTap,
        ),
        if (isHandsFree) ...[
          const SizedBox(height: 8),
          const Text('Hands-Free',
              style: TextStyle(color: AppColors.grey500, fontSize: 12)),
        ],
      ],
    );
  }
}

class _SummaryScreen extends StatelessWidget {
  const _SummaryScreen(
      {required this.correct, required this.total, required this.onDone});
  final int correct;
  final int total;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0 : (correct / total * 100).round();
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.celebration,
                    size: 72, color: AppColors.success),
                const SizedBox(height: 24),
                Text('Quiz Complete!', style: tt.headlineLarge),
                const SizedBox(height: 16),
                Text('$correct / $total correct', style: tt.headlineMedium),
                const SizedBox(height: 8),
                Text('$pct% accuracy',
                    style: tt.titleMedium
                        ?.copyWith(color: AppColors.grey500)),
                const SizedBox(height: 40),
                FilledButton.icon(
                  onPressed: onDone,
                  icon: const Icon(Icons.home),
                  label: const Text('Back to Home'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
