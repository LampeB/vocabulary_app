import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/entities/variant_progress.dart';
import '../../../core/utils/answer_validator.dart';
import '../../../core/utils/fsrs_algorithm.dart';

enum QuizMode { flashcard, typing, voice, handsFree }

class QuizArgs {
  const QuizArgs({
    required this.listId,
    required this.mode,
    required this.direction,
    required this.cardLimit,
  });
  final String listId;
  final QuizMode mode;
  final QuizDirection direction;
  final int cardLimit;
}

enum QuizAnswerState { idle, correct, incorrect, skipped }

class QuizState {
  const QuizState({
    this.cards = const [],
    this.currentIndex = 0,
    this.answerState = QuizAnswerState.idle,
    this.userAnswer = '',
    this.partialTranscript = '',
    this.isFlipped = false,
    this.isListening = false,
    this.isProcessing = false,
    this.correctCount = 0,
    this.isComplete = false,
    this.lastFsrsRating,
  });

  final List<VariantProgress> cards;
  final int currentIndex;
  final QuizAnswerState answerState;
  final String userAnswer;
  final String partialTranscript;
  final bool isFlipped;
  final bool isListening;
  final bool isProcessing;
  final int correctCount;
  final bool isComplete;
  final FsrsRating? lastFsrsRating;

  VariantProgress? get currentCard =>
      currentIndex < cards.length ? cards[currentIndex] : null;

  int get total => cards.length;

  double get accuracy => total == 0 ? 0 : correctCount / total;

  QuizState copyWith({
    List<VariantProgress>? cards,
    int? currentIndex,
    QuizAnswerState? answerState,
    String? userAnswer,
    String? partialTranscript,
    bool? isFlipped,
    bool? isListening,
    bool? isProcessing,
    int? correctCount,
    bool? isComplete,
    FsrsRating? lastFsrsRating,
  }) =>
      QuizState(
        cards: cards ?? this.cards,
        currentIndex: currentIndex ?? this.currentIndex,
        answerState: answerState ?? this.answerState,
        userAnswer: userAnswer ?? this.userAnswer,
        partialTranscript: partialTranscript ?? this.partialTranscript,
        isFlipped: isFlipped ?? this.isFlipped,
        isListening: isListening ?? this.isListening,
        isProcessing: isProcessing ?? this.isProcessing,
        correctCount: correctCount ?? this.correctCount,
        isComplete: isComplete ?? this.isComplete,
        lastFsrsRating: lastFsrsRating ?? this.lastFsrsRating,
      );
}

final quizProvider =
    NotifierProvider.autoDispose<QuizNotifier, QuizState>(QuizNotifier.new);

class QuizNotifier extends AutoDisposeNotifier<QuizState> {
  @override
  QuizState build() => const QuizState();

  void loadCards(List<VariantProgress> cards) {
    state = state.copyWith(cards: cards, currentIndex: 0, isComplete: false);
  }

  void flipCard() {
    state = state.copyWith(isFlipped: !state.isFlipped);
  }

  void rateCard(FsrsRating rating) {
    final isCorrect = rating == FsrsRating.good || rating == FsrsRating.easy;
    _advance(isCorrect: isCorrect, rating: rating);
  }

  void submitTextAnswer(String answer, List<String> acceptedAnswers) {
    final result = AnswerValidator.validate(
      userAnswer: answer,
      acceptedAnswers: acceptedAnswers,
    );
    final rating = result.isCorrect ? FsrsRating.good : FsrsRating.again;
    state = state.copyWith(
      userAnswer: answer,
      answerState: result.isCorrect
          ? QuizAnswerState.correct
          : QuizAnswerState.incorrect,
    );
    Future.delayed(const Duration(seconds: 2),
        () => _advance(isCorrect: result.isCorrect, rating: rating));
  }

  void submitVoiceAnswer(String transcript, List<String> acceptedAnswers,
      {bool isDrivingMode = false}) {
    final result = AnswerValidator.validate(
      userAnswer: transcript,
      acceptedAnswers: acceptedAnswers,
      isDrivingMode: isDrivingMode,
    );
    final rating = result.isCorrect ? FsrsRating.good : FsrsRating.again;
    state = state.copyWith(
      userAnswer: transcript,
      answerState: result.isCorrect
          ? QuizAnswerState.correct
          : QuizAnswerState.incorrect,
      isListening: false,
    );
    Future.delayed(
        Duration(seconds: isDrivingMode ? 1 : 2),
        () => _advance(isCorrect: result.isCorrect, rating: rating));
  }

  void setPartialTranscript(String text) {
    state = state.copyWith(partialTranscript: text);
  }

  void setListening(bool listening) {
    state = state.copyWith(isListening: listening, partialTranscript: '');
  }

  void setProcessing(bool processing) {
    state = state.copyWith(isProcessing: processing);
  }

  void _advance({required bool isCorrect, required FsrsRating rating}) {
    final next = state.currentIndex + 1;
    final newCorrect = state.correctCount + (isCorrect ? 1 : 0);
    if (next >= state.total) {
      state = state.copyWith(
        isComplete: true,
        correctCount: newCorrect,
        answerState: QuizAnswerState.idle,
      );
    } else {
      state = state.copyWith(
        currentIndex: next,
        answerState: QuizAnswerState.idle,
        userAnswer: '',
        partialTranscript: '',
        isFlipped: false,
        isListening: false,
        correctCount: newCorrect,
        lastFsrsRating: rating,
      );
    }
  }
}
