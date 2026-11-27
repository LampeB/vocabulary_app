import 'dart:async' show unawaited;
import 'package:easy_localization/easy_localization.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart'
    show debugPrint, debugPrintStack, kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../../data/datasources/local/app_database.dart';
import '../../../data/datasources/local/daos/quiz_session_dao.dart';
import '../../../data/repositories/progress_repository_impl.dart';
import '../../../domain/entities/variant_progress.dart';
import '../../../domain/repositories/progress_repository.dart';
import '../../../domain/repositories/vocabulary_repository.dart';
import '../../../domain/usecases/quiz/get_due_cards_usecase.dart';
import '../../../domain/usecases/quiz/submit_answer_usecase.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/errors/failure.dart';
import '../../../core/utils/answer_validator.dart';
import '../../../core/utils/fsrs_algorithm.dart';
import '../../../core/utils/streak.dart';
import '../../../core/utils/stt_debug_log.dart';
import '../audio/audio_provider.dart';
import '../../../services/quiz_orchestration/audio_director.dart';
import '../lists/vocabulary_provider.dart';
import '../auth/auth_provider.dart';
import '../../../services/audio/audio_player_service.dart';
import '../grammar/grammar_provider.dart';
import '../notifications/notification_provider.dart';
import '../../../core/grammar/grammar_drill_generator.dart';
import '../../../core/grammar/grammar_practice_policy.dart';
import '../../../core/grammar/rule_mastery.dart';
import 'session_assembly.dart';

const _uuid = Uuid();

// ─── Domain model ────────────────────────────────────────────────────────────

/// A fully enriched card ready for display in the quiz.
class QuizCard {
  const QuizCard({
    required this.progress,
    required this.questionWord,
    required this.answerWords,
    this.questionAudioPath,
    this.answerAudioPath,
    this.grammarAudioPrompt,
    this.isRequeue = false,
  });

  final VariantProgress progress;

  /// True for the queue-tail copy created by skipCurrentCard — excluded
  /// from user-facing counts so skips don't inflate the session size.
  final bool isRequeue;

  /// The word shown as the question (French or Korean depending on direction).
  final String questionWord;

  /// Immutable Storage path for the spoken prompt, if it has been published.
  final String? questionAudioPath;

  /// The localized instruction and the target-language word it introduces.
  final ({String instruction, String locale, String word})? grammarAudioPrompt;

  /// Accepted answer words (used for typing / voice validation).
  final List<String> answerWords;

  /// Immutable Storage path for the primary accepted answer.
  final String? answerAudioPath;

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
    mode != QuizMode.flashcard &&
    mode != QuizMode.typing && // typing: on-demand speaker button instead
    (mode != QuizMode.handsFree || !correct);

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
    this.distinctCardsOnly = false,
  }) : assert(
         source != QuizSource.list || listId != null,
         'a list-sourced session needs a listId',
       ),
       assert(
         source != QuizSource.grammar || ruleId != null,
         'a grammar session needs a ruleId',
       );

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
  final bool distinctCardsOnly;

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
    this.isEmpty = false,
    this.correctCount = 0,
    this.isComplete = false,
    this.errorMessage,
    this.scheduledDays,
  });

  final List<QuizCard> cards;
  final int currentIndex;
  final QuizAnswerState answerState;
  final String userAnswer;
  final String partialTranscript;
  final bool isFlipped;
  final bool isListening;
  final bool isLoading;
  final bool isEmpty;
  final int correctCount;
  final bool isComplete;
  final String? errorMessage;

  /// Interval saved by FSRS for the current answer, if one was scheduled.
  final int? scheduledDays;

  QuizCard? get currentCard =>
      currentIndex < cards.length ? cards[currentIndex] : null;

  /// The card that will follow — used to pre-warm its TTS voice while the
  /// user answers the current one. Requeues can still change the actual
  /// successor; a mis-warm just falls back to the on-demand voice switch.
  QuizCard? get nextCard =>
      currentIndex + 1 < cards.length ? cards[currentIndex + 1] : null;

  /// Internal queue length — drives advancement/completion. Requeued
  /// copies (skipCurrentCard) count here so they actually replay.
  int get total => cards.length;

  /// User-facing session size: requeued copies excluded, so skips don't
  /// inflate it ("I chose 10 words but ended up with 12" + a progress bar
  /// stalling against a growing denominator — field report 2026-07-09).
  int get displayTotal => cards.where((c) => !c.isRequeue).length;

  /// User-facing position, clamped: while replaying requeued copies past
  /// the planned count it displays as total/total.
  int get position =>
      currentIndex + 1 > displayTotal ? displayTotal : currentIndex + 1;

  double get accuracy => displayTotal == 0 ? 0 : correctCount / displayTotal;

  /// True once the planned cards are done and requeued skips are replaying.
  bool get inReviewTail => currentIndex + 1 > displayTotal;

  /// 1-based position within the requeue tail (valid when [inReviewTail]).
  int get reviewPosition => currentIndex + 1 - displayTotal;

  /// Number of requeued cards in the tail.
  int get reviewTotal => cards.length - displayTotal;

  QuizState copyWith({
    List<QuizCard>? cards,
    int? currentIndex,
    QuizAnswerState? answerState,
    String? userAnswer,
    String? partialTranscript,
    bool? isFlipped,
    bool? isListening,
    bool? isLoading,
    bool? isEmpty,
    int? correctCount,
    bool? isComplete,
    String? errorMessage,
    int? scheduledDays,
    bool clearSchedule = false,
  }) => QuizState(
    cards: cards ?? this.cards,
    currentIndex: currentIndex ?? this.currentIndex,
    answerState: answerState ?? this.answerState,
    userAnswer: userAnswer ?? this.userAnswer,
    partialTranscript: partialTranscript ?? this.partialTranscript,
    isFlipped: isFlipped ?? this.isFlipped,
    isListening: isListening ?? this.isListening,
    isLoading: isLoading ?? this.isLoading,
    isEmpty: isEmpty ?? this.isEmpty,
    correctCount: correctCount ?? this.correctCount,
    isComplete: isComplete ?? this.isComplete,
    errorMessage: errorMessage,
    scheduledDays: clearSchedule ? null : scheduledDays ?? this.scheduledDays,
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

final quizProvider = NotifierProvider.autoDispose
    .family<QuizNotifier, QuizState, Object>(QuizNotifier.new);

// ─── Notifier ─────────────────────────────────────────────────────────────────

class QuizNotifier extends AutoDisposeFamilyNotifier<QuizState, Object> {
  // Not late final: Riverpod re-calls build() when audioPlayerServiceProvider
  // rebuilds (e.g. when audioSettingsProvider loads from SharedPreferences).
  AudioPlayerService? _audio;
  AudioDirector? _director;
  var _alive = true;
  var _foreground = true;
  var _paused = false;
  var _sessionEpoch = 0;
  var _lifecycleEpoch = 0;
  String? _sessionUserId;
  bool get _ownsSession =>
      _alive &&
      _lastArgs != null &&
      _sessionUserId == ref.read(currentUserProvider)?.id;
  bool get _canPlay => _ownsSession && _foreground && !_paused;
  ({int index, bool correct})? _pendingAutoAdvance;
  // Eagerly mirrored in the state setter so build() can restore it after a
  // dependency-triggered rebuild. Riverpod resets internal state to
  // "uninitialized" before firing onDispose, so reading state there throws.
  QuizState _preserved = const QuizState();
  QuizArgs? _lastArgs;
  // When the current card was shown — for review-event responseTimeMs.
  DateTime? _cardShownAt;
  DateTime? _sessionStartTime;

  @override
  set state(QuizState value) {
    _preserved = value;
    super.state = value;
  }

  @override
  QuizState build(Object routeSession) {
    _alive = true; // rebuild ≠ disposal
    _audio = ref.watch(audioPlayerServiceProvider);
    _director = ref.watch(audioDirectorProvider);
    final accountId = currentUserProvider.select((user) => user?.id);
    final invalidated = _accountChange(ref.read(accountId));
    if (invalidated != null) _preserved = invalidated;
    ref.listen(accountId, (_, next) {
      final invalidated = _accountChange(next);
      if (invalidated != null) state = invalidated;
    });
    ref.onDispose(() => _alive = false);
    return _preserved;
  }

  QuizState? _accountChange(String? userId) {
    if (_lastArgs == null || _sessionUserId == userId) return null;
    return _newSessionState(errorMessage: 'quiz.account_changed'.tr());
  }

  QuizState _newSessionState({
    QuizArgs? args,
    String? userId,
    String? errorMessage,
  }) {
    _pendingAutoAdvance = null;
    _sessionEpoch++;
    _lifecycleEpoch++;
    _foreground = true;
    _paused = false;
    _lastArgs = args;
    _sessionUserId = userId;
    _cardShownAt = null;
    _sessionStartTime = args == null ? null : DateTime.now();
    _requeuedOnce.clear();
    return QuizState(isLoading: args != null, errorMessage: errorMessage);
  }

  bool _isCurrentSession(int epoch) => _ownsSession && _sessionEpoch == epoch;

  Future<void> loadCards(QuizArgs args, {String? promptLocale}) async {
    final userId = ref.read(currentUserProvider)?.id;
    final loading = _newSessionState(args: args, userId: userId);
    final epoch = _sessionEpoch;
    state = loading;

    try {
      if (!_isCurrentSession(epoch)) return;
      final ownerId = userId ?? '';
      if (args.source == QuizSource.grammar) {
        await _loadGrammarCards(
          args,
          epoch,
          ownerId,
          promptLocale ??
              Intl.defaultLocale?.split(RegExp('[_-]')).first ??
              'en',
        );
      } else {
        await _loadVocabularyCards(args, epoch, ownerId);
      }
    } catch (error, stackTrace) {
      _failCardLoad(epoch, error, stackTrace: stackTrace);
    }
  }

  void _failCardLoad(int epoch, Object? error, {StackTrace? stackTrace}) {
    if (!_isCurrentSession(epoch)) return;
    state = state.copyWith(
      isLoading: false,
      errorMessage: 'quiz.load_failed'.tr(),
    );
    if (kDebugMode) {
      final detail = error is AppException
          ? '${error.runtimeType}: ${error.message}'
          : '$error';
      final diagnostic = '[QUIZ] Card preparation failed: $detail';
      if (stackTrace == null) {
        debugPrint(diagnostic);
      } else {
        debugPrintStack(
          label: diagnostic,
          stackTrace: stackTrace,
          maxFrames: 10,
        );
      }
    }
  }

  Future<void> _loadVocabularyCards(
    QuizArgs args,
    int epoch,
    String ownerId,
  ) async {
    final getDueCards = ref.read(getDueCardsUseCaseProvider);
    final distinctCardsOnly =
        args.distinctCardsOnly || args.source == QuizSource.allDue;

    // Fetch progress entries — one or two calls depending on direction choice.
    List<VariantProgress> progressList;
    if (args.direction == QuizDirectionChoice.both) {
      final limit = distinctCardsOnly
          ? args.cardLimit
          : halfLimit(args.cardLimit);
      final frResult = await getDueCards.call(
        userId: ownerId,
        listId: args.listId,
        source: args.source,
        direction: args.forward,
        langA: args.langA,
        langB: args.langB,
        limit: limit,
        includeScheduled: args.distinctCardsOnly,
      );
      if (!_isCurrentSession(epoch)) return;
      final koResult = await getDueCards.call(
        userId: ownerId,
        listId: args.listId,
        source: args.source,
        direction: args.backward,
        langA: args.langA,
        langB: args.langB,
        limit: limit,
        includeScheduled: args.distinctCardsOnly,
      );
      if (!_isCurrentSession(epoch)) return;
      if (frResult.isFailure && koResult.isFailure) {
        _failCardLoad(epoch, frResult.exceptionOrNull);
        return;
      }
      // Distinct-card sessions can fill unused places from either direction.
      progressList = interleaveAndCap(
        frResult.valueOrNull ?? [],
        koResult.valueOrNull ?? [],
        distinctCardsOnly ? limit * 2 : args.cardLimit,
      );
    } else {
      final direction = args.direction == QuizDirectionChoice.frToKo
          ? args.forward
          : args.backward;
      final result = await getDueCards.call(
        userId: ownerId,
        listId: args.listId,
        source: args.source,
        direction: direction,
        langA: args.langA,
        langB: args.langB,
        limit: args.cardLimit,
        includeScheduled: args.distinctCardsOnly,
      );
      if (!_isCurrentSession(epoch)) return;
      if (result.isFailure) {
        _failCardLoad(epoch, result.exceptionOrNull);
        return;
      }
      progressList = result.valueOrNull ?? [];
    }

    if (progressList.isEmpty) {
      state = state.copyWith(isLoading: false, isEmpty: true);
      return;
    }

    // Enrich each VariantProgress with question/answer word text.
    final conceptDao = ref.read(conceptDaoProvider);
    final questionVariantIds = progressList
        .map((p) => p.variantId)
        .toSet()
        .toList();

    // Look up question variants by ID (deduplicated).
    final questionVariants = await conceptDao.getVariantsByIds(
      questionVariantIds,
    );
    if (!_isCurrentSession(epoch)) return;
    final questionById = {for (final row in questionVariants) row.id: row};

    // Fetch answer variants for both languages of the session's pair —
    // needed for mixed-direction "both" mode.
    final allConceptIds = questionVariants
        .map((row) => row.conceptId)
        .toSet()
        .toList();
    final answerByConceptAndLang =
        <String, Map<String, List<WordVariantsTableData>>>{};
    for (final langCode in {args.langA, args.langB}) {
      final rows = await conceptDao.getVariantsByConceptIds(
        allConceptIds,
        langCode,
      );
      if (!_isCurrentSession(epoch)) return;
      for (final v in rows) {
        ((answerByConceptAndLang[v.conceptId] ??= {})[langCode] ??= []).add(v);
      }
    }

    // Assemble QuizCards, dropping any whose variant can't be resolved.
    var quizCards = <QuizCard>[];
    final seen = <(String, QuizDirection)>{};
    for (final p in progressList) {
      if (distinctCardsOnly && !seen.add((p.variantId, p.direction))) {
        continue;
      }
      final question = questionById[p.variantId];
      if (question == null) continue;
      final answerLang = p.direction.answerLang;
      final answerVariants =
          answerByConceptAndLang[question.conceptId]?[answerLang] ?? [];
      if (answerVariants.isEmpty) {
        // A concept missing its answer-language variant is UNANSWERABLE —
        // every attempt would grade wrong no matter what the user says
        // (field log 2026-07-06: "singe" had no KO word; the user's correct
        // 원숭이 scored 0 against an empty list). Never deal such a card.
        sttLog(
          '[QUIZ] dropping unanswerable card "${question.word}" — no $answerLang variant',
        );
        continue;
      }
      final primary = answerVariants.firstWhere(
        (variant) => variant.isPrimary,
        orElse: () => answerVariants.first,
      );
      quizCards.add(
        QuizCard(
          progress: p,
          questionWord: question.word,
          questionAudioPath: question.audioPath,
          answerWords: [
            primary.word,
            for (final variant in answerVariants)
              if (variant.id != primary.id) variant.word,
          ],
          answerAudioPath: primary.audioPath,
        ),
      );
    }

    if (distinctCardsOnly) {
      quizCards = quizCards.take(args.cardLimit).toList();
    }

    // Same concept, languages swapped, back-to-back ("morning" → "matin")
    // reads as an echo, not a test — keep ≥2 other cards between the two
    // directions of one concept (user report 2026-07-21).
    quizCards = spaceOutDuplicates(
      quizCards,
      (c) => questionById[c.progress.variantId]?.conceptId,
    );

    if (!distinctCardsOnly) {
      quizCards = padCyclically(quizCards, args.cardLimit);
    }

    _cardShownAt = quizCards.isEmpty ? null : DateTime.now();
    state = state.copyWith(
      cards: quizCards,
      currentIndex: 0,
      isLoading: false,
      isEmpty: quizCards.isEmpty,
      correctCount: 0,
    );

    // Fill the on-device cache for the whole session in the background. The
    // first prompt shares this same request; every later hands-free turn is
    // therefore a local file read rather than an audio-generation wait.
    unawaited(_prefetchSessionAudio(quizCards, epoch));

    if (_isCurrentSession(epoch) &&
        quizCards.isNotEmpty &&
        _canPlay &&
        args.mode != QuizMode.handsFree &&
        !_kTestMode) {
      final first = quizCards.first;
      final firstLang = first.progress.direction.questionLang;
      unawaited(
        _audio?.speak(
          first.questionWord,
          firstLang,
          audioPath: first.questionAudioPath,
        ),
      );
    }
  }

  Future<void> _prefetchSessionAudio(List<QuizCard> cards, int epoch) async {
    final audio = _audio;
    if (audio == null) return;
    for (final card in cards) {
      if (!_isCurrentSession(epoch)) return;
      await audio.prefetch(
        card.questionWord,
        card.progress.direction.questionLang,
        audioPath: card.questionAudioPath,
      );
      if (_isCurrentSession(epoch) && card.answerWords.isNotEmpty) {
        await audio.prefetch(
          card.answerWords.first,
          card.progress.direction.answerLang,
          audioPath: card.answerAudioPath,
        );
      }
    }
  }

  /// Grammar sessions use deterministic drills from the rule + mastered words.
  /// The question is the localized prompt;
  /// the answer is validated against the module's accepted forms; answers
  /// record grammar progress instead of FSRS.
  Future<void> _loadGrammarCards(
    QuizArgs args,
    int epoch,
    String userId,
    String promptLocale,
  ) async {
    final rules = await ref.read(grammarRulesProvider(args.langB).future);
    if (!_isCurrentSession(epoch)) return;
    final rule = rules.firstWhere((r) => r.id == args.ruleId);
    if ((args.mode == QuizMode.voice || args.mode == QuizMode.handsFree) &&
        !supportsSpokenGrammar(rule, args.langB)) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'grammar.written_only'.tr(),
      );
      return;
    }
    final module = await ref.read(grammarModuleProvider(args.langB).future);
    if (!_isCurrentSession(epoch)) return;
    if (module == null) {
      // No deterministic engine for this language — nothing to drill.
      state = state.copyWith(isLoading: false, isEmpty: true);
      return;
    }
    final words = await ref.read(
      ruleDrillWordsProvider((
        ruleId: args.ruleId!,
        targetLang: args.langB,
      )).future,
    );
    if (!_isCurrentSession(epoch)) return;

    final exercises = GrammarDrillGenerator(module).generate(
      rule,
      words,
      count: args.cardLimit,
      // The drill prompt itself is localized to the UI locale (.tr), so the
      // interpolated rule title must match it.
      promptLocale: promptLocale,
    );
    if (exercises.isEmpty) {
      state = state.copyWith(isLoading: false, isEmpty: true);
      return;
    }
    final now = DateTime.now();
    final cards = exercises.map((exercise) {
      final promptArgs = {
        for (final entry in exercise.promptParams.entries)
          entry.key: entry.key == 'hint' ? entry.value.tr() : entry.value,
      };
      final forms = promptArgs['forms'];
      final word = promptArgs['word']!;
      return QuizCard(
        progress: VariantProgress(
          id: 'grammar|${exercise.ruleId}',
          userId: userId,
          variantId: 'grammar|${exercise.ruleId}|${exercise.variantKey ?? ''}',
          direction: args.forward,
          createdAt: now,
          updatedAt: now,
        ),
        questionWord: exercise.promptKey.tr(namedArgs: promptArgs),
        grammarAudioPrompt: (
          instruction: forms == null
              ? exercise.promptKey.tr(
                  namedArgs: {
                    ...promptArgs,
                    'word': 'grammar.drill.spoken_word'.tr(),
                  },
                )
              : 'grammar.drill.spoken_particle'.tr(),
          locale: promptLocale,
          word: forms == null ? word : '${forms.split('/').join('. ')}. $word',
        ),
        answerWords: exercise.accepted,
      );
    }).toList();
    _cardShownAt = now;
    state = state.copyWith(
      cards: cards,
      currentIndex: 0,
      isLoading: false,
      isComplete: false,
      correctCount: 0,
    );
  }

  void flipCard() {
    if (!_ownsSession) return;
    final flipped = !state.isFlipped;
    state = state.copyWith(isFlipped: flipped);
    // TTS muted in TEST_MODE — emulator audio destabilizes the E2E runner.
    if (flipped && !_kTestMode) {
      final card = state.currentCard;
      if (card != null && card.answerWords.isNotEmpty) {
        final answerLang = card.progress.direction.answerLang;
        unawaited(
          _audio?.speak(
            card.answerWords.first,
            answerLang,
            audioPath: card.answerAudioPath,
          ),
        );
      }
    }
  }

  /// Rates the revealed card once, whether dismissed by a swipe or a button.
  void gradeFlashcard(FsrsRating rating) {
    if (!_ownsSession) return;
    final card = state.currentCard;
    if (card == null ||
        !state.isFlipped ||
        state.isComplete ||
        state.answerState != QuizAnswerState.idle) {
      return;
    }
    final isCorrect = rating == FsrsRating.good || rating == FsrsRating.easy;
    _recordReviewEvent(card, correct: isCorrect, rating: rating);
    state = state.copyWith(
      answerState: isCorrect
          ? QuizAnswerState.correct
          : QuizAnswerState.incorrect,
    );
    // Grammar flashcards are practice and leave rule mastery unchanged.
    if (_lastArgs?.source != QuizSource.grammar) {
      unawaited(_persistRating(card, rating));
    }
  }

  /// Called by the "Continuer" button on the feedback screen.
  void advance() {
    if (!_ownsSession) return;
    if (state.isComplete || state.answerState == QuizAnswerState.idle) return;
    _advance(isCorrect: state.answerState == QuizAnswerState.correct);
  }

  void submitTextAnswer(String answer) {
    if (!_ownsSession) return;
    final card = state.currentCard;
    if (card == null ||
        state.isComplete ||
        state.answerState != QuizAnswerState.idle) {
      return;
    }
    final correct = AnswerValidator.validate(
      userAnswer: answer,
      acceptedAnswers: card.answerWords,
      langCode: card.progress.direction.answerLang,
      preserveGrammar: _lastArgs?.source == QuizSource.grammar,
    ).isCorrect;
    final rating = correct ? FsrsRating.good : FsrsRating.again;
    _recordReviewEvent(card, correct: correct, rating: rating);
    state = state.copyWith(
      userAnswer: answer,
      answerState: correct
          ? QuizAnswerState.correct
          : QuizAnswerState.incorrect,
    );
    unawaited(_persistRating(card, rating));
    // Advance is triggered by user tapping "Continuer" on the feedback screen.
  }

  void submitVoiceAnswer(String transcript, {bool isDrivingMode = false}) {
    if (!_canPlay) return;
    final card = state.currentCard;
    if (card == null ||
        state.isComplete ||
        state.answerState != QuizAnswerState.idle) {
      return;
    }
    final result = AnswerValidator.validate(
      userAnswer: transcript,
      acceptedAnswers: card.answerWords,
      langCode: card.progress.direction.answerLang,
      isDrivingMode: isDrivingMode,
      preserveGrammar: _lastArgs?.source == QuizSource.grammar,
    );
    final rating = result.isCorrect ? FsrsRating.good : FsrsRating.again;
    _recordReviewEvent(card, correct: result.isCorrect, rating: rating);
    state = state.copyWith(
      userAnswer: transcript,
      answerState: result.isCorrect
          ? QuizAnswerState.correct
          : QuizAnswerState.incorrect,
      isListening: false,
    );
    unawaited(_persistRating(card, rating));
    if (isDrivingMode) {
      _pendingAutoAdvance = (
        index: state.currentIndex,
        correct: result.isCorrect,
      );
      unawaited(_advanceAfterAudio(isCorrect: result.isCorrect));
    }
    // Otherwise: advance is triggered by "Continuer" on the feedback screen.
  }

  /// Driving-mode advance, sequenced BEHIND the verdict audio instead of a
  /// fixed timer. The old fixed 800ms/3000ms raced the audio chain (verdict
  /// chirp → answer TTS → next question TTS), so when TTS ran long the next
  /// card started while audio was still queued — late answer audio, delayed
  /// questions and mistimed earcons (field report 2026-07-20). Waiting for
  /// quiet gives every card a clean audio slate.
  Future<void> _advanceAfterAudio({required bool isCorrect}) async {
    final marker = state.currentIndex;
    final epoch = _lifecycleEpoch;
    bool sameCard() =>
        _alive &&
        _canPlay &&
        _lifecycleEpoch == epoch &&
        state.currentIndex == marker &&
        !state.isComplete;
    // Give the screen's grade reaction a beat to START its audio first.
    await Future.delayed(const Duration(milliseconds: 250));
    if (!sameCard()) return;
    if (isCorrect) {
      // Correct plays only the chirp (no TTS) — a quick quiet check suffices.
      await _director?.quiet(timeout: const Duration(seconds: 4));
      await Future.delayed(const Duration(milliseconds: 550));
    } else {
      // Wrong answers speak the CORRECTION, and its start can lag (an
      // uncached ElevenLabs render is a network fetch). A quiet check that
      // ran before the audio began advanced the card mid-correction — the
      // answer played after its feedback screen was gone (field report
      // 2026-07-22). Wait for the chain: start (bounded) → end.
      await _director?.chainQuiet(
        cycles: 2,
        firstStartWindow: const Duration(seconds: 2),
        utteranceCap: const Duration(seconds: 6),
        keepGoing: sameCard,
      );
      await Future.delayed(const Duration(milliseconds: 650));
    }
    if (!sameCard()) return;
    _advance(isCorrect: isCorrect);
  }

  /// Invalidate delayed feedback/advance work before the screen stops audio.
  /// A graded card stays graded while backgrounded and advances once on resume.
  void setForeground(bool foreground) {
    if (_foreground == foreground) return;
    _foreground = foreground;
    _updatePlaybackState();
  }

  void setPaused(bool paused) {
    if (_paused == paused) return;
    _paused = paused;
    _updatePlaybackState();
  }

  void _updatePlaybackState() {
    _lifecycleEpoch++;
    if (!_canPlay) return;
    final pending = _pendingAutoAdvance;
    if (pending != null &&
        state.currentIndex == pending.index &&
        !state.isComplete) {
      unawaited(_advanceAfterAudio(isCorrect: pending.correct));
    }
  }

  /// Records one review-event row (observability for the stats dashboard).
  /// Strictly additive — best-effort, never blocks grading; the isSynced
  /// flag carries it to Supabase on the next push drain.
  void _recordReviewEvent(
    QuizCard card, {
    required bool correct,
    required FsrsRating rating,
    int? retryCount,
  }) {
    try {
      final userId = _sessionUserId;
      if (!_ownsSession || userId == null) return;
      final now = DateTime.now();
      final rt = _cardShownAt == null
          ? null
          : now.difference(_cardShownAt!).inMilliseconds;
      unawaited(
        ref
            .read(appDatabaseProvider)
            .reviewEventDao
            .insertEvent(
              ReviewEventsTableCompanion.insert(
                id: _uuid.v4(),
                userId: userId,
                variantId: card.progress.variantId,
                direction: card.progress.direction.name,
                listId: Value(_lastArgs?.listId),
                mode: (_lastArgs?.mode ?? QuizMode.flashcard).name,
                correct: correct,
                rating: rating.name,
                responseTimeMs: Value(rt),
                retryCount: Value(retryCount),
                createdAt: now,
              ),
            )
            .catchError((Object e) {
              sttLog('[QUIZ] ⚠️ review-event record failed: $e');
            }),
      );
    } catch (e) {
      sttLog('[QUIZ] ⚠️ review-event record failed (sync): $e');
    }
  }

  void setPartialTranscript(String text) {
    if (_ownsSession) state = state.copyWith(partialTranscript: text);
  }

  void setListening(bool listening) {
    if (_ownsSession) {
      state = state.copyWith(isListening: listening, partialTranscript: '');
    }
  }

  Future<void> _onSessionComplete(QuizState completed) async {
    if (_kTestMode || !_ownsSession) return;
    // A completed quiz belongs to the captured account after the screen closes.
    final args = _lastArgs!;
    final epoch = _sessionEpoch;
    final userId = _sessionUserId;
    if (userId == null) return;

    final completedAt = DateTime.now();
    final studyDate = civilDate(completedAt);
    final startedAt = _sessionStartTime;
    final snapshot = QuizSessionsTableCompanion.insert(
      id: _uuid.v4(),
      userId: userId,
      listId: Value(args.listId),
      listName: switch (args.source) {
        QuizSource.grammar => args.ruleTitle ?? args.ruleId ?? '',
        QuizSource.list => '',
        QuizSource.allDue => 'start_session.smart_due'.tr(),
        QuizSource.inProgress => 'start_session.smart_in_progress'.tr(),
      },
      mode: args.mode.name,
      direction: args.direction.name,
      cardCount: completed.displayTotal,
      correctCount: completed.correctCount,
      durationSeconds: startedAt == null
          ? 0
          : completedAt.difference(startedAt).inSeconds,
      masteredWordCount: 0,
      completedAt: completedAt,
    );
    final dao = ref.read(appDatabaseProvider).quizSessionDao;
    final progress = ref.read(progressRepositoryProvider);
    final vocabulary = args.source == QuizSource.list
        ? ref.read(vocabularyRepositoryProvider)
        : null;
    final auth = ref.read(authRepositoryProvider);
    final profile = ref.read(authStateProvider.notifier);
    final reminders = ref.read(notificationServiceProvider);

    ref.read(localStudyDayProvider(userId).notifier).state = completedAt;
    unawaited(
      reminders.cancelStreakWarning().catchError((Object error) {
        sttLog('[QUIZ] streak warning cancellation failed: $error');
      }),
    );
    await _recordSession(snapshot, dao, progress, vocabulary);
    final updated = await auth.updateStreak(
      userId: userId,
      studyDate: studyDate,
    );
    if (updated.isSuccess && auth.currentUser?.id == userId) {
      await profile.reloadProfile();
    }
    if (_isCurrentSession(epoch)) unawaited(_maybeRequestReview(epoch));
  }

  static Future<void> _recordSession(
    QuizSessionsTableCompanion snapshot,
    QuizSessionDao dao,
    ProgressRepository progress,
    VocabularyRepository? vocabulary,
  ) async {
    try {
      final list = (await vocabulary?.getListById(
        snapshot.listId.value!,
      ))?.valueOrNull;
      final mastered = await progress.getMasteredVariants(
        snapshot.userId.value,
      );
      await dao.insertSession(
        snapshot.copyWith(
          listId: list == null ? null : Value(list.id),
          listName: list == null ? null : Value(list.name),
          masteredWordCount: Value(mastered.valueOrNull?.length ?? 0),
        ),
      );
    } catch (_) {
      // Session recording is best-effort; never crash the quiz.
    }
  }

  static const _prefKeySessionCount = 'quiz_session_count';

  Future<void> _maybeRequestReview(int epoch) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!_isCurrentSession(epoch)) return;
      final count = (prefs.getInt(_prefKeySessionCount) ?? 0) + 1;
      await prefs.setInt(_prefKeySessionCount, count);
      // Prompt at session 5 and every 25 thereafter.
      if (count == 5 || (count > 5 && (count - 5) % 25 == 0)) {
        final review = InAppReview.instance;
        if (await review.isAvailable() && _isCurrentSession(epoch)) {
          await review.requestReview();
        }
      }
    } catch (_) {
      // Review prompt is best-effort; swallow all errors.
    }
  }

  /// The verdict appears immediately. An interval appears only when FSRS
  /// returns the saved progress for this turn, including repeats of one word.
  Future<void> _persistRating(QuizCard card, FsrsRating rating) async {
    if (!_ownsSession) return;
    final args = _lastArgs;
    final epoch = _sessionEpoch;
    final index = state.currentIndex;
    try {
      if (args?.source == QuizSource.grammar) {
        // Grammar typing and voice answers count toward rule mastery.
        final userId = _sessionUserId;
        if (userId == null) return;
        await ref
            .read(appDatabaseProvider)
            .grammarProgressDao
            .recordAnswer(
              userId: userId,
              ruleId: args!.ruleId!,
              correct: rating != FsrsRating.again,
              masteredWhenCorrectReaches: kRuleMasteryTarget,
            );
        return;
      }
      final saved = await ref
          .read(submitAnswerUseCaseProvider)
          .call(progress: card.progress, rating: rating);
      final days = saved.valueOrNull?.scheduledDays;
      if (days != null &&
          _isCurrentSession(epoch) &&
          state.currentIndex == index &&
          identical(state.currentCard, card) &&
          !state.isComplete &&
          state.answerState != QuizAnswerState.idle) {
        state = state.copyWith(scheduledDays: days);
      }
    } catch (error) {
      sttLog('[QUIZ] rating persistence failed: $error');
    }
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
    if (!_ownsSession) return;
    final card = state.currentCard;
    if (card == null ||
        state.isComplete ||
        state.answerState != QuizAnswerState.idle) {
      return;
    }
    final requeue = _requeuedOnce.add(card.progress.variantId);
    if (requeue) {
      // The copy is flagged: it replays (cards.length grows) but does not
      // inflate the user-facing displayTotal.
      state = state.copyWith(
        cards: [
          ...state.cards,
          QuizCard(
            progress: card.progress,
            questionWord: card.questionWord,
            answerWords: card.answerWords,
            questionAudioPath: card.questionAudioPath,
            answerAudioPath: card.answerAudioPath,
            grammarAudioPrompt: card.grammarAudioPrompt,
            isRequeue: true,
          ),
        ],
      );
    }
    _advance(isCorrect: false);
  }

  void _advance({required bool isCorrect}) {
    _pendingAutoAdvance = null;
    final next = state.currentIndex + 1;
    final newCorrect = state.correctCount + (isCorrect ? 1 : 0);
    if (next >= state.total) {
      final completed = state.copyWith(
        isComplete: true,
        correctCount: newCorrect,
        answerState: QuizAnswerState.idle,
        isFlipped: false,
        isListening: false,
        clearSchedule: true,
      );
      unawaited(_onSessionComplete(completed));
      state = completed;
    } else {
      state = state.copyWith(
        currentIndex: next,
        answerState: QuizAnswerState.idle,
        userAnswer: '',
        partialTranscript: '',
        isFlipped: false,
        isListening: false,
        correctCount: newCorrect,
        clearSchedule: true,
      );
      _cardShownAt = DateTime.now();
      final nextCard = state.currentCard;
      if (nextCard != null &&
          !_kTestMode &&
          _lastArgs?.mode != QuizMode.handsFree &&
          _lastArgs?.source != QuizSource.grammar) {
        final nextLang = nextCard.progress.direction.questionLang;
        unawaited(
          _speakWhenQuiet(
            nextCard.questionWord,
            nextLang,
            audioPath: nextCard.questionAudioPath,
          ),
        );
      }
    }
  }

  /// Speaks after any in-flight utterance finishes: a wrong-answer replay
  /// can still be playing when the session advances, and starting the next
  /// question over it produced overlapping audio (field log 2026-07-09,
  /// TTS active=2 near the end of the session).
  Future<void> _speakWhenQuiet(
    String text,
    String langCode, {
    String? audioPath,
  }) async {
    final epoch = _lifecycleEpoch;
    final index = state.currentIndex;
    // Wait/speak semantics owned by AudioDirector (refactor step 1).
    await _director?.speakWhenQuiet(
      text,
      langCode,
      audioPath: audioPath,
      keepGoing: () =>
          _alive &&
          _canPlay &&
          epoch == _lifecycleEpoch &&
          state.currentIndex == index,
    );
  }
}
