import 'dart:async' show unawaited;
import 'package:easy_localization/easy_localization.dart';
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
import '../../../core/utils/stt_debug_log.dart';
import '../audio/audio_provider.dart';
import '../lists/vocabulary_provider.dart';
import '../auth/auth_provider.dart';
import '../../../services/audio/audio_player_service.dart';
import '../grammar/grammar_provider.dart';
import '../notifications/notification_provider.dart';
import '../../../core/grammar/composition_validator.dart';
import '../../../core/grammar/grammar_drill_generator.dart';
import '../../../core/grammar/grammar_language_module.dart';
import '../../../core/grammar/rule_mastery.dart';
import '../../../domain/entities/grammar_rule.dart';
import 'session_assembly.dart';

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

/// Whether the revealed answer should be auto-spoken, given the mode and whether
/// the user's answer was correct. Flashcard never speaks (visual-only). Hands-free
/// speaks only on a wrong answer — the user just said the word aloud correctly, so
/// only a mistake needs the correct pronunciation. Typing/voice always speak.
bool shouldSpeakAnswer(QuizMode mode, {required bool correct}) =>
    mode != QuizMode.flashcard && (mode != QuizMode.handsFree || !correct);

/// UI-level direction choice. `both` means load cards in both FR→KR and KR→FR
/// directions — each individual card still has a single concrete direction.
/// Never stored in the DB; only used in QuizArgs.
enum QuizDirectionChoice { frToKo, koToFr, both }

class QuizArgs {
  const QuizArgs({
    this.listId,
    this.source = QuizSource.list,
    required this.mode,
    required this.direction,
    required this.cardLimit,
    this.langA = 'fr',
    this.langB = 'ko',
    this.ruleId,
    this.ruleTitle,
  })  : assert(source != QuizSource.list || listId != null,
            'a list-sourced session needs a listId'),
        assert(source != QuizSource.grammar || ruleId != null,
            'a grammar session needs a ruleId');

  /// The list to study — required when [source] is [QuizSource.list],
  /// ignored for the cross-list smart sources.
  final String? listId;
  final QuizSource source;
  final QuizMode mode;
  final QuizDirectionChoice direction;
  final int cardLimit;

  /// The studied language pair (from the selected list; smart sources use the
  /// fr/ko defaults until multi-pair exists). Directions are RESOLVED from
  /// this pair — the QuizDirectionChoice names are legacy labels for
  /// forward/backward/both.
  final String langA;
  final String langB;

  /// Grammar sessions: the rule being drilled (+ its title for history).
  final String? ruleId;
  final String? ruleTitle;

  QuizDirection get forward =>
      QuizDirection(questionLang: langA, answerLang: langB);
  QuizDirection get backward => forward.reversed;
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
    _requeuedOnce.clear();
    state = state.copyWith(isLoading: true, isComplete: false, errorMessage: null);

    final userId = ref.read(currentUserProvider)?.id ?? '';

    if (args.source == QuizSource.grammar) {
      await _loadGrammarCards(args);
      return;
    }
    final getDueCards = ref.read(getDueCardsUseCaseProvider);

    // Fetch progress entries — one or two calls depending on direction choice.
    List<VariantProgress> progressList;
    if (args.direction == QuizDirectionChoice.both) {
      final limit = halfLimit(args.cardLimit);
      final frResult = await getDueCards.call(
        userId: userId,
        listId: args.listId,
        source: args.source,
        direction: args.forward,
        limit: limit,
      );
      final koResult = await getDueCards.call(
        userId: userId,
        listId: args.listId,
        source: args.source,
        direction: args.backward,
        limit: limit,
      );
      if (frResult.isFailure && koResult.isFailure) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: frResult.exceptionOrNull?.message ?? 'Failed to load cards',
        );
        return;
      }
      // Interleave FR and KO cards (FR, KO, FR, KO, …), capped at the limit.
      progressList = interleaveAndCap(
        frResult.valueOrNull ?? [],
        koResult.valueOrNull ?? [],
        args.cardLimit,
      );
    } else {
      final direction = args.direction == QuizDirectionChoice.frToKo
          ? args.forward
          : args.backward;
      final result = await getDueCards.call(
        userId: userId,
        listId: args.listId,
        source: args.source,
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

    // Fetch answer variants for both languages of the session's pair —
    // needed for mixed-direction "both" mode.
    final allConceptIds = conceptIdMap.values.toSet().toList();
    final answerByConceptAndLang = <String, Map<String, List<String>>>{};
    for (final langCode in {args.langA, args.langB}) {
      final rows = await conceptDao.getVariantsByConceptIds(allConceptIds, langCode);
      for (final v in rows) {
        ((answerByConceptAndLang[v.conceptId] ??= {})[langCode] ??= []).add(v.word);
      }
    }

    // Assemble QuizCards, dropping any whose variant can't be resolved.
    var quizCards = <QuizCard>[];
    for (final p in progressList) {
      final q = questionVariantMap[p.variantId];
      final cId = conceptIdMap[p.variantId];
      if (q == null || cId == null) continue;
      final answerLang = p.direction.answerLang;
      final answers = answerByConceptAndLang[cId]?[answerLang] ?? [];
      if (answers.isEmpty) {
        // A concept missing its answer-language variant is UNANSWERABLE —
        // every attempt would grade wrong no matter what the user says
        // (field log 2026-07-06: "singe" had no KO word; the user's correct
        // 원숭이 scored 0 against an empty list). Never deal such a card.
        sttLog('[QUIZ] dropping unanswerable card "$q" — no $answerLang variant');
        continue;
      }
      quizCards.add(QuizCard(
        progress: p,
        questionWord: q,
        answerWords: answers,
      ));
    }

    // Pad to the requested limit by repeating cards cyclically.
    quizCards = padCyclically(quizCards, args.cardLimit);

    state = state.copyWith(
      cards: quizCards,
      currentIndex: 0,
      isLoading: false,
      isComplete: quizCards.isEmpty,
      correctCount: 0,
    );

    if (quizCards.isNotEmpty && !_kTestMode && args.source != QuizSource.grammar) {
      final first = quizCards.first;
      final firstLang = first.progress.direction.questionLang;
      unawaited(_audio?.speak(first.questionWord, firstLang));
    }
  }

  /// Grammar sessions: cards are GENERATED from the rule + mastered words
  /// (stage-2 drills today; the sentence composer replaces the generator's
  /// output as rules get mastered). The question is the localized prompt;
  /// the answer is validated against the module's accepted forms; answers
  /// record grammar progress instead of FSRS.
  Future<void> _loadGrammarCards(QuizArgs args) async {
    final rules = await ref.read(grammarRulesProvider.future);
    final rule = rules.firstWhere((r) => r.id == args.ruleId);
    final module = await ref.read(grammarModuleProvider.future);
    final words = await ref.read(drillWordsProvider.future);

    // AI-composed full-sentence exercises first (stage 3); the deterministic
    // word-level drill generator is the offline/error/TEST_MODE fallback.
    var cards = _kTestMode
        ? const <QuizCard>[]
        : await _loadCompositionCards(args, rule, module, words);

    if (cards.isEmpty) {
      final exercises = GrammarDrillGenerator(module)
          .generate(rule, words, count: args.cardLimit);
      if (exercises.isEmpty) {
        state = state.copyWith(isLoading: false, isComplete: true);
        return;
      }
      final now = DateTime.now();
      cards = [
        for (final e in exercises)
          QuizCard(
            progress: VariantProgress(
              id: 'grammar|${e.ruleId}',
              userId: ref.read(currentUserProvider)?.id ?? '',
              variantId: 'grammar|${e.ruleId}|${e.variantKey ?? ''}',
              direction: args.forward,
              createdAt: now,
              updatedAt: now,
            ),
            questionWord: e.promptKey.tr(namedArgs: {
              for (final entry in e.promptParams.entries)
                entry.key: entry.key == 'hint' ? entry.value.tr() : entry.value,
            }),
            answerWords: e.accepted,
          ),
      ];
    }
    state = state.copyWith(
      cards: cards,
      currentIndex: 0,
      isLoading: false,
      isComplete: false,
      correctCount: 0,
    );
  }

  /// Full-sentence exercises composed at runtime by the AI from the target
  /// rule + the user's KNOWN words (any list — user-made vocabulary works).
  /// Every batch passes the local morphology validator (the engine verifies
  /// what it can mechanically; hallucinated items are dropped), successful
  /// batches are cached for offline reuse, and any failure returns [] so the
  /// caller falls back to word-level drills.
  Future<List<QuizCard>> _loadCompositionCards(
    QuizArgs args,
    GrammarRule rule,
    GrammarLanguageModule module,
    List<DrillWord> words,
  ) async {
    try {
      final rawRules = await ref.read(grammarRulesRawProvider.future);
      final targetRaw = rawRules[rule.id];
      if (targetRaw == null) return const [];
      final progress = await ref.read(grammarProgressProvider.future);
      final masteredRaw = [
        for (final e in progress.entries)
          if (e.value.mastered && e.key != rule.id && rawRules[e.key] != null)
            rawRules[e.key]!,
      ];
      final promptLang =
          Intl.defaultLocale?.split(RegExp('[_-]')).first ?? 'fr';

      final validator = CompositionValidator(module);
      final result = await ref.read(grammarExerciseRemoteProvider).generate(
            targetRule: targetRaw,
            masteredRules: masteredRaw,
            words: words,
            promptLanguage: promptLang,
            targetLanguage: module.langCode,
            count: args.cardLimit,
          );
      final cache = ref.read(compositionCacheProvider);
      var exercises =
          validator.filter(rule, words, result.valueOrNull ?? const []);
      if (exercises.isNotEmpty) {
        unawaited(cache.save(rule.id, exercises));
      } else {
        // Network/AI unavailable → last good batch, still re-validated.
        exercises = validator.filter(rule, words, await cache.load(rule.id));
      }
      if (exercises.length > args.cardLimit) {
        exercises = exercises.sublist(0, args.cardLimit);
      }

      final now = DateTime.now();
      final userId = ref.read(currentUserProvider)?.id ?? '';
      return [
        for (var i = 0; i < exercises.length; i++)
          QuizCard(
            progress: VariantProgress(
              id: 'grammar|${rule.id}',
              userId: userId,
              variantId: 'grammar|${rule.id}|comp$i',
              direction: args.forward,
              createdAt: now,
              updatedAt: now,
            ),
            questionWord: exercises[i].prompt,
            answerWords: exercises[i].accepted,
          ),
      ];
    } catch (e, st) {
      assert(() {
        // ignore: avoid_print
        print('[composition] falling back to drills: $e\n$st');
        return true;
      }());
      return const [];
    }
  }

  void flipCard() {
    final flipped = !state.isFlipped;
    state = state.copyWith(isFlipped: flipped);
    // TTS muted in TEST_MODE — emulator audio destabilizes the E2E runner.
    if (flipped && !_kTestMode) {
      final card = state.currentCard;
      if (card != null && card.answerWords.isNotEmpty) {
        final answerLang = card.progress.direction.answerLang;
        unawaited(_audio?.speak(card.answerWords.first, answerLang));
      }
    }
  }

  /// Cartes self-grade on the unified study canvas: persist + set the answer
  /// state (so the full-screen feedback flood shows), then Continuer advances.
  void gradeFlashcard(FsrsRating rating) {
    final card = state.currentCard;
    if (card == null) return;
    // Cartes NEVER advances mastery (product decision 2026-07-04): self-graded
    // flips are too easy to fake, so no FSRS rating is persisted — the mode is
    // pure practice. Session score/history still record normally. Applies to
    // vocab today and to grammar when it lands. scheduledDays stays 0 so the
    // feedback screen doesn't show an interval that was never scheduled.
    final isCorrect = rating == FsrsRating.good || rating == FsrsRating.easy;
    state = state.copyWith(
      answerState:
          isCorrect ? QuizAnswerState.correct : QuizAnswerState.incorrect,
      scheduledDays: 0,
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

    // List sessions record the list's name; smart sessions their label;
    // grammar sessions the rule's title.
    final String listName;
    if (args.source == QuizSource.grammar) {
      listName = args.ruleTitle ?? args.ruleId ?? '';
    } else if (args.source == QuizSource.list) {
      final listRow =
          await ref.read(vocabularyListDaoProvider).getById(args.listId!);
      listName = listRow?.name ?? '';
    } else {
      listName = args.source == QuizSource.allDue
          ? 'start_session.smart_due'.tr()
          : 'start_session.smart_in_progress'.tr();
    }

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
    final args = _lastArgs;
    if (args?.source == QuizSource.grammar) {
      // Grammar mastery, not FSRS. Only non-cartes paths reach here (cartes
      // never persists), so every recorded answer counts toward the rule.
      final userId = ref.read(currentUserProvider)?.id ?? '';
      if (userId.isEmpty) return;
      await ref.read(appDatabaseProvider).grammarProgressDao.recordAnswer(
            userId: userId,
            ruleId: args!.ruleId!,
            correct: rating != FsrsRating.again,
            masteredWhenCorrectReaches: kRuleMasteryTarget,
          );
      return;
    }
    await ref
        .read(submitAnswerUseCaseProvider)
        .call(progress: progress, rating: rating);
  }

  /// Variant ids already requeued once by [skipCurrentCard] — a card comes
  /// back at most once, so a persistently silent environment can't loop a
  /// session forever.
  final _requeuedOnce = <String>{};

  /// Skips the current card WITHOUT grading: nothing is persisted (no FSRS
  /// rating, no grammar progress), and the card is requeued at the end of
  /// the session (once) so the user gets another shot. This is what
  /// "the mic heard nothing" and the hands-free Passer button do — silence
  /// or a noisy room is an environment problem, never a wrong answer
  /// (user feedback 2026-07-06: background noise was failing words the
  /// user never spoke).
  void skipCurrentCard() {
    final card = state.currentCard;
    if (card == null || state.answerState != QuizAnswerState.idle) return;
    final requeue = _requeuedOnce.add(card.progress.variantId);
    if (requeue) {
      // total is cards.length, so the session naturally grows by one slot.
      state = state.copyWith(cards: [...state.cards, card]);
    }
    _advance(isCorrect: false);
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
      if (nextCard != null &&
          !_kTestMode &&
          _lastArgs?.source != QuizSource.grammar) {
        final nextLang = nextCard.progress.direction.questionLang;
        unawaited(_audio?.speak(nextCard.questionWord, nextLang));
      }
    }
  }
}
