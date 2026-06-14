import 'dart:async' show unawaited;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/repositories/progress_repository_impl.dart';
import '../../../domain/entities/variant_progress.dart';
import '../../../domain/repositories/progress_repository.dart';
import '../../../domain/usecases/quiz/get_due_cards_usecase.dart';
import '../../../domain/usecases/quiz/submit_answer_usecase.dart';
import '../../../core/errors/failure.dart';
import '../../../core/utils/answer_validator.dart';
import '../../../core/utils/fsrs_algorithm.dart';
import '../audio/audio_provider.dart';
import '../lists/vocabulary_provider.dart';
import '../auth/auth_provider.dart';
import '../../../services/audio/audio_player_service.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../notifications/notification_provider.dart';

// ─── Domain model ────────────────────────────────────────────────────────────

/// A fully enriched card ready for display in the quiz.
class QuizCard {
  const QuizCard({
    required this.progress,
    required this.questionWord,
    required this.answerWords,
  });

  final VariantProgress progress;

  /// The word shown as the question (French or Korean depending on direction).
  final String questionWord;

  /// Accepted answer words (used for typing / voice validation).
  final List<String> answerWords;
}

// ─── Supporting enums/classes ─────────────────────────────────────────────────

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

enum QuizAnswerState { idle, correct, incorrect }

// ─── Quiz state ───────────────────────────────────────────────────────────────

class QuizState {
  const QuizState({
    this.cards = const [],
    this.currentIndex = 0,
    this.answerState = QuizAnswerState.idle,
    this.userAnswer = '',
    this.partialTranscript = '',
    this.isFlipped = false,
    this.isListening = false,
    this.isLoading = false,
    this.correctCount = 0,
    this.isComplete = false,
    this.errorMessage,
  });

  final List<QuizCard> cards;
  final int currentIndex;
  final QuizAnswerState answerState;
  final String userAnswer;
  final String partialTranscript;
  final bool isFlipped;
  final bool isListening;
  final bool isLoading;
  final int correctCount;
  final bool isComplete;
  final String? errorMessage;

  QuizCard? get currentCard =>
      currentIndex < cards.length ? cards[currentIndex] : null;

  int get total => cards.length;

  double get accuracy => total == 0 ? 0 : correctCount / total;

  QuizState copyWith({
    List<QuizCard>? cards,
    int? currentIndex,
    QuizAnswerState? answerState,
    String? userAnswer,
    String? partialTranscript,
    bool? isFlipped,
    bool? isListening,
    bool? isLoading,
    int? correctCount,
    bool? isComplete,
    String? errorMessage,
  }) =>
      QuizState(
        cards: cards ?? this.cards,
        currentIndex: currentIndex ?? this.currentIndex,
        answerState: answerState ?? this.answerState,
        userAnswer: userAnswer ?? this.userAnswer,
        partialTranscript: partialTranscript ?? this.partialTranscript,
        isFlipped: isFlipped ?? this.isFlipped,
        isListening: isListening ?? this.isListening,
        isLoading: isLoading ?? this.isLoading,
        correctCount: correctCount ?? this.correctCount,
        isComplete: isComplete ?? this.isComplete,
        errorMessage: errorMessage,
      );
}

// ─── Providers ────────────────────────────────────────────────────────────────

final progressRepositoryProvider = Provider<ProgressRepository>((ref) {
  final userId = ref.watch(currentUserProvider)?.id ?? '';
  return ProgressRepositoryImpl(
    ref.watch(progressDaoProvider),
    ref.watch(conceptDaoProvider),
    ref.watch(vocabularyRemoteProvider),
    userId,
  );
});

final getDueCardsUseCaseProvider = Provider<GetDueCardsUseCase>(
  (ref) => GetDueCardsUseCase(ref.watch(progressRepositoryProvider)),
);

final submitAnswerUseCaseProvider = Provider<SubmitAnswerUseCase>(
  (ref) => SubmitAnswerUseCase(ref.watch(progressRepositoryProvider)),
);

final quizProvider =
    NotifierProvider.autoDispose<QuizNotifier, QuizState>(QuizNotifier.new);

// ─── Notifier ─────────────────────────────────────────────────────────────────

class QuizNotifier extends AutoDisposeNotifier<QuizState> {
  late final AudioPlayerService _audio;
  var _questionLang = 'fr';

  @override
  QuizState build() {
    _audio = ref.watch(audioPlayerServiceProvider);
    return const QuizState();
  }

  Future<void> loadCards(QuizArgs args) async {
    _questionLang = args.direction == QuizDirection.frToKo ? 'fr' : 'ko';
    state = state.copyWith(isLoading: true, errorMessage: null);

    final userId = ref.read(currentUserProvider)?.id ?? '';
    final result = await ref.read(getDueCardsUseCaseProvider).call(
          userId: userId,
          listId: args.listId,
          direction: args.direction,
          limit: args.cardLimit,
        );

    if (result.isFailure) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: result.exceptionOrNull?.message ?? 'Failed to load cards',
      );
      return;
    }

    final progressList = result.valueOrNull ?? [];
    if (progressList.isEmpty) {
      state = state.copyWith(isLoading: false, isComplete: true);
      return;
    }

    // Enrich each VariantProgress with question/answer word text.
    final conceptDao = ref.read(conceptDaoProvider);
    final answerLang = args.direction == QuizDirection.frToKo ? 'ko' : 'fr';

    final questionVariantIds = progressList.map((p) => p.variantId).toList();

    // Batch: look up question variants by ID
    final questionVariantMap = <String, String>{}; // variantId → word
    final conceptIdMap = <String, String>{}; // variantId → conceptId
    for (final id in questionVariantIds) {
      final row = await conceptDao.getVariantById(id);
      if (row != null) {
        questionVariantMap[id] = row.word;
        conceptIdMap[id] = row.conceptId;
      }
    }

    // Batch: get answer variants for all concepts at once
    final allConceptIds = conceptIdMap.values.toSet().toList();
    final answerRows = await conceptDao.getVariantsByConceptIds(
        allConceptIds, answerLang);
    final answerByConceptId = <String, List<String>>{};
    for (final v in answerRows) {
      (answerByConceptId[v.conceptId] ??= []).add(v.word);
    }

    // Assemble QuizCards, dropping any whose variant can't be resolved.
    final quizCards = <QuizCard>[];
    for (final p in progressList) {
      final q = questionVariantMap[p.variantId];
      final cId = conceptIdMap[p.variantId];
      if (q == null || cId == null) continue;
      quizCards.add(QuizCard(
        progress: p,
        questionWord: q,
        answerWords: answerByConceptId[cId] ?? [],
      ));
    }

    state = state.copyWith(
      cards: quizCards,
      currentIndex: 0,
      isLoading: false,
      isComplete: quizCards.isEmpty,
    );

    if (quizCards.isNotEmpty) {
      unawaited(_audio.speak(quizCards.first.questionWord, _questionLang));
    }
  }

  void flipCard() {
    final flipped = !state.isFlipped;
    state = state.copyWith(isFlipped: flipped);
    if (flipped) {
      final card = state.currentCard;
      if (card != null && card.answerWords.isNotEmpty) {
        final answerLang = _questionLang == 'fr' ? 'ko' : 'fr';
        unawaited(_audio.speak(card.answerWords.first, answerLang));
      }
    }
  }

  void rateCard(FsrsRating rating) {
    final card = state.currentCard;
    if (card == null) return;
    unawaited(_persistRating(card.progress, rating));
    final isCorrect = rating == FsrsRating.good || rating == FsrsRating.easy;
    _advance(isCorrect: isCorrect);
  }

  void submitTextAnswer(String answer) {
    final card = state.currentCard;
    if (card == null) return;
    final result = AnswerValidator.validate(
      userAnswer: answer,
      acceptedAnswers: card.answerWords,
    );
    final rating = result.isCorrect ? FsrsRating.good : FsrsRating.again;
    unawaited(_persistRating(card.progress, rating));
    state = state.copyWith(
      userAnswer: answer,
      answerState: result.isCorrect
          ? QuizAnswerState.correct
          : QuizAnswerState.incorrect,
    );
    Future.delayed(
      const Duration(seconds: 2),
      () => _advance(isCorrect: result.isCorrect),
    );
  }

  void submitVoiceAnswer(String transcript, {bool isDrivingMode = false}) {
    final card = state.currentCard;
    if (card == null) return;
    final result = AnswerValidator.validate(
      userAnswer: transcript,
      acceptedAnswers: card.answerWords,
      isDrivingMode: isDrivingMode,
    );
    final rating = result.isCorrect ? FsrsRating.good : FsrsRating.again;
    unawaited(_persistRating(card.progress, rating));
    state = state.copyWith(
      userAnswer: transcript,
      answerState: result.isCorrect
          ? QuizAnswerState.correct
          : QuizAnswerState.incorrect,
      isListening: false,
    );
    Future.delayed(
      Duration(seconds: isDrivingMode ? 1 : 2),
      () => _advance(isCorrect: result.isCorrect),
    );
  }

  void setPartialTranscript(String text) =>
      state = state.copyWith(partialTranscript: text);

  void setListening(bool listening) =>
      state = state.copyWith(isListening: listening, partialTranscript: '');

  Future<void> _onSessionComplete() async {
    await ref.read(authRepositoryProvider).updateStreak();
    await ref.read(authStateProvider.notifier).reloadProfile();
    // User just studied — cancel any streak-at-risk warning for today.
    await ref.read(notificationServiceProvider).cancelStreakWarning();
  }

  Future<void> _persistRating(
      VariantProgress progress, FsrsRating rating) async {
    await ref
        .read(submitAnswerUseCaseProvider)
        .call(progress: progress, rating: rating);
  }

  void _advance({required bool isCorrect}) {
    final next = state.currentIndex + 1;
    final newCorrect = state.correctCount + (isCorrect ? 1 : 0);
    if (next >= state.total) {
      state = state.copyWith(
        isComplete: true,
        correctCount: newCorrect,
        answerState: QuizAnswerState.idle,
      );
      unawaited(_onSessionComplete());
    } else {
      state = state.copyWith(
        currentIndex: next,
        answerState: QuizAnswerState.idle,
        userAnswer: '',
        partialTranscript: '',
        isFlipped: false,
        isListening: false,
        correctCount: newCorrect,
      );
      final nextCard = state.currentCard;
      if (nextCard != null) {
        unawaited(_audio.speak(nextCard.questionWord, _questionLang));
      }
    }
  }
}
