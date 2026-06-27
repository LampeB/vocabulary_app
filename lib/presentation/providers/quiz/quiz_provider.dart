import 'dart:async' show unawaited;
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../../data/datasources/local/app_database.dart';
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
import '../notifications/notification_provider.dart';

const _uuid = Uuid();

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

  /// Derived from progress.direction — available as a convenience.
  QuizDirection get direction => progress.direction;
}

// ─── Supporting enums/classes ─────────────────────────────────────────────────

enum QuizMode { flashcard, typing, voice, handsFree }

/// UI-level direction choice. `both` means load cards in both FR→KR and KR→FR
/// directions — each individual card still has a single concrete direction.
/// Never stored in the DB; only used in QuizArgs.
enum QuizDirectionChoice { frToKo, koToFr, both }

class QuizArgs {
  const QuizArgs({
    required this.listId,
    required this.mode,
    required this.direction,
    required this.cardLimit,
  });
  final String listId;
  final QuizMode mode;
  final QuizDirectionChoice direction;
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
    this.scheduledDays = 0,
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
  /// FSRS-computed interval for the last answered card — used by the feedback screen.
  final int scheduledDays;

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
    int? scheduledDays,
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
        scheduledDays: scheduledDays ?? this.scheduledDays,
      );
}

// Injected by test env files; false in production.
const _kTestMode = bool.fromEnvironment('TEST_MODE');

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
  // Not late final: Riverpod re-calls build() when audioPlayerServiceProvider
  // rebuilds (e.g. when audioSettingsProvider loads from SharedPreferences).
  AudioPlayerService? _audio;
  var _alive = true;
  // Eagerly mirrored in the state setter so build() can restore it after a
  // dependency-triggered rebuild. Riverpod resets internal state to
  // "uninitialized" before firing onDispose, so reading state there throws.
  QuizState _preserved = const QuizState();
  QuizArgs? _lastArgs;
  DateTime? _sessionStartTime;

  @override
  set state(QuizState value) {
    _preserved = value;
    super.state = value;
  }

  @override
  QuizState build() {
    _alive = true; // rebuild ≠ disposal; reset so _onSessionComplete can run
    _audio = ref.watch(audioPlayerServiceProvider);
    ref.onDispose(() => _alive = false);
    return _preserved;
  }

  Future<void> loadCards(QuizArgs args) async {
    _lastArgs = args;
    _sessionStartTime = DateTime.now();
    state = state.copyWith(isLoading: true, isComplete: false, errorMessage: null);

    final userId = ref.read(currentUserProvider)?.id ?? '';
    final getDueCards = ref.read(getDueCardsUseCaseProvider);

    // Fetch progress entries — one or two calls depending on direction choice.
    List<VariantProgress> progressList;
    if (args.direction == QuizDirectionChoice.both) {
      final halfLimit = (args.cardLimit + 1) ~/ 2;
      final frResult = await getDueCards.call(
        userId: userId,
        listId: args.listId,
        direction: QuizDirection.frToKo,
        limit: halfLimit,
      );
      final koResult = await getDueCards.call(
        userId: userId,
        listId: args.listId,
        direction: QuizDirection.koToFr,
        limit: halfLimit,
      );
      if (frResult.isFailure && koResult.isFailure) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: frResult.exceptionOrNull?.message ?? 'Failed to load cards',
        );
        return;
      }
      final frCards = frResult.valueOrNull ?? [];
      final koCards = koResult.valueOrNull ?? [];
      // Interleave FR and KO cards: FR, KO, FR, KO, …
      progressList = [];
      final maxLen = frCards.length > koCards.length ? frCards.length : koCards.length;
      for (int i = 0; i < maxLen; i++) {
        if (i < frCards.length) progressList.add(frCards[i]);
        if (i < koCards.length) progressList.add(koCards[i]);
      }
      if (progressList.length > args.cardLimit) {
        progressList = progressList.take(args.cardLimit).toList();
      }
    } else {
      final direction = args.direction == QuizDirectionChoice.frToKo
          ? QuizDirection.frToKo
          : QuizDirection.koToFr;
      final result = await getDueCards.call(
        userId: userId,
        listId: args.listId,
        direction: direction,
        limit: args.cardLimit,
      );
      if (result.isFailure) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: result.exceptionOrNull?.message ?? 'Failed to load cards',
        );
        return;
      }
      progressList = result.valueOrNull ?? [];
    }

    if (progressList.isEmpty) {
      state = state.copyWith(isLoading: false, isComplete: true);
      return;
    }

    // Enrich each VariantProgress with question/answer word text.
    final conceptDao = ref.read(conceptDaoProvider);
    final questionVariantIds = progressList.map((p) => p.variantId).toSet().toList();

    // Look up question variants by ID (deduplicated).
    final questionVariantMap = <String, String>{}; // variantId → word
    final conceptIdMap = <String, String>{}; // variantId → conceptId
    for (final id in questionVariantIds) {
      final row = await conceptDao.getVariantById(id);
      if (row != null) {
        questionVariantMap[id] = row.word;
        conceptIdMap[id] = row.conceptId;
      }
    }

    // Fetch answer variants for both langs — needed for mixed-direction "both" mode.
    final allConceptIds = conceptIdMap.values.toSet().toList();
    final answerByConceptAndLang = <String, Map<String, List<String>>>{};
    for (final langCode in ['fr', 'ko']) {
      final rows = await conceptDao.getVariantsByConceptIds(allConceptIds, langCode);
      for (final v in rows) {
        ((answerByConceptAndLang[v.conceptId] ??= {})[langCode] ??= []).add(v.word);
      }
    }

    // Assemble QuizCards, dropping any whose variant can't be resolved.
    final quizCards = <QuizCard>[];
    for (final p in progressList) {
      final q = questionVariantMap[p.variantId];
      final cId = conceptIdMap[p.variantId];
      if (q == null || cId == null) continue;
      final answerLang = p.direction == QuizDirection.frToKo ? 'ko' : 'fr';
      quizCards.add(QuizCard(
        progress: p,
        questionWord: q,
        answerWords: answerByConceptAndLang[cId]?[answerLang] ?? [],
      ));
    }

    // Pad to the requested limit by repeating cards cyclically.
    if (quizCards.isNotEmpty && quizCards.length < args.cardLimit) {
      final base = List.of(quizCards);
      while (quizCards.length < args.cardLimit) {
        quizCards.add(base[quizCards.length % base.length]);
      }
    }

    state = state.copyWith(
      cards: quizCards,
      currentIndex: 0,
      isLoading: false,
      isComplete: quizCards.isEmpty,
      correctCount: 0,
    );

    if (quizCards.isNotEmpty && !_kTestMode) {
      final first = quizCards.first;
      final firstLang = first.progress.direction == QuizDirection.frToKo ? 'fr' : 'ko';
      unawaited(_audio?.speak(first.questionWord, firstLang));
    }
  }

  void flipCard() {
    final flipped = !state.isFlipped;
    state = state.copyWith(isFlipped: flipped);
    if (flipped) {
      final card = state.currentCard;
      if (card != null && card.answerWords.isNotEmpty) {
        final answerLang = card.progress.direction == QuizDirection.frToKo ? 'ko' : 'fr';
        unawaited(_audio?.speak(card.answerWords.first, answerLang));
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

  /// Cartes self-grade on the unified study canvas: persist + set the answer
  /// state (so the full-screen feedback flood shows), then Continuer advances.
  void gradeFlashcard(FsrsRating rating) {
    final card = state.currentCard;
    if (card == null) return;
    unawaited(_persistRating(card.progress, rating));
    final isCorrect = rating == FsrsRating.good || rating == FsrsRating.easy;
    state = state.copyWith(
      answerState:
          isCorrect ? QuizAnswerState.correct : QuizAnswerState.incorrect,
      scheduledDays: _computeScheduledDays(card.progress, rating),
    );
  }

  /// Called by the "Continuer" button on the feedback screen.
  void advance() {
    _advance(isCorrect: state.answerState == QuizAnswerState.correct);
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
      scheduledDays: _computeScheduledDays(card.progress, rating),
    );
    // Advance is triggered by user tapping "Continuer" on the feedback screen.
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
      scheduledDays: _computeScheduledDays(card.progress, rating),
    );
    if (isDrivingMode) {
      // Correct: short pause for the flash/sound then move on (no TTS plays).
      // Wrong: longer pause so the answer TTS has time to finish speaking
      // before the next card appears and the mic opens.
      final delay = result.isCorrect
          ? const Duration(milliseconds: 800)
          : const Duration(milliseconds: 3000);
      Future.delayed(delay, () => _advance(isCorrect: result.isCorrect));
    }
    // Otherwise: advance is triggered by "Continuer" on the feedback screen.
  }

  int _computeScheduledDays(VariantProgress progress, FsrsRating rating) {
    final fsrsCard = FsrsCard(
      stability: progress.stability,
      difficulty: progress.difficulty,
      elapsedDays: progress.elapsedDays,
      scheduledDays: progress.scheduledDays,
      reps: progress.reps,
      lapses: progress.lapses,
      state: progress.state,
      lastReview: progress.lastReview,
      nextReview: progress.nextReview,
    );
    return AppFsrs.schedule(fsrsCard, rating, DateTime.now()).scheduledDays;
  }

  void setPartialTranscript(String text) =>
      state = state.copyWith(partialTranscript: text);

  void setListening(bool listening) =>
      state = state.copyWith(isListening: listening, partialTranscript: '');

  Future<void> _onSessionComplete() async {
    if (_kTestMode || !_alive) return;
    unawaited(_recordSession());
    await ref.read(authRepositoryProvider).updateStreak();
    if (!_alive) return;
    await ref.read(authStateProvider.notifier).reloadProfile();
    if (!_alive) return;
    await ref.read(notificationServiceProvider).cancelStreakWarning();
    unawaited(_maybeRequestReview());
  }

  Future<void> _recordSession() async {
    final args = _lastArgs;
    if (args == null) return;
    final userId = ref.read(currentUserProvider)?.id ?? '';
    if (userId.isEmpty) return;

    final duration = _sessionStartTime == null
        ? 0
        : DateTime.now().difference(_sessionStartTime!).inSeconds;

    // Look up list name from the DAO.
    final listRow = await ref
        .read(vocabularyListDaoProvider)
        .getById(args.listId);
    final listName = listRow?.name ?? '';

    // Snapshot total mastered-word count at session end.
    final masteredResult = await ref
        .read(progressRepositoryProvider)
        .getMasteredVariants(userId);
    final masteredCount = (masteredResult.valueOrNull ?? []).length;

    try {
      final dao = ref.read(appDatabaseProvider).quizSessionDao;
      await dao.insertSession(QuizSessionsTableCompanion.insert(
        id: _uuid.v4(),
        userId: userId,
        listId: Value(args.listId),
        listName: listName,
        mode: args.mode.name,
        direction: args.direction.name,
        cardCount: state.total,
        correctCount: state.correctCount,
        durationSeconds: duration,
        masteredWordCount: masteredCount,
        completedAt: DateTime.now(),
      ));
    } catch (_) {
      // Session recording is best-effort; never crash the quiz.
    }
  }

  static const _prefKeySessionCount = 'quiz_session_count';

  Future<void> _maybeRequestReview() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final count = (prefs.getInt(_prefKeySessionCount) ?? 0) + 1;
      await prefs.setInt(_prefKeySessionCount, count);
      // Prompt at session 5 and every 25 thereafter.
      if (count == 5 || (count > 5 && (count - 5) % 25 == 0)) {
        final review = InAppReview.instance;
        if (await review.isAvailable()) {
          await review.requestReview();
        }
      }
    } catch (_) {
      // Review prompt is best-effort; swallow all errors.
    }
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
        scheduledDays: 0,
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
        scheduledDays: 0,
      );
      final nextCard = state.currentCard;
      if (nextCard != null) {
        final nextLang = nextCard.progress.direction == QuizDirection.frToKo ? 'fr' : 'ko';
        unawaited(_audio?.speak(nextCard.questionWord, nextLang));
      }
    }
  }
}
