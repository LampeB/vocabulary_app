// ignore_for_file: invalid_use_of_internal_member
import 'dart:async';

import 'package:audioplayers/audioplayers.dart' show PlayerState;
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/core/errors/app_exception.dart';
import 'package:vocab_kr/core/errors/failure.dart';
import 'package:vocab_kr/core/utils/fsrs_algorithm.dart' show CardState;
import 'package:vocab_kr/data/datasources/local/app_database.dart';
import 'package:vocab_kr/data/models/variant_progress_dto.dart';
import 'package:vocab_kr/data/repositories/progress_repository_impl.dart';
import 'package:vocab_kr/data/repositories/vocabulary_repository_impl.dart';
import 'package:vocab_kr/domain/entities/app_user.dart';
import 'package:vocab_kr/domain/entities/variant_progress.dart';
import 'package:vocab_kr/domain/repositories/progress_repository.dart';
import 'package:vocab_kr/domain/usecases/quiz/get_due_cards_usecase.dart';
import 'package:vocab_kr/presentation/providers/audio/audio_provider.dart';
import 'package:vocab_kr/presentation/providers/auth/auth_provider.dart';
import 'package:vocab_kr/presentation/providers/lists/vocabulary_provider.dart';
import 'package:vocab_kr/presentation/providers/quiz/quiz_provider.dart';
import 'package:vocab_kr/presentation/providers/quiz/quiz_availability_provider.dart';
import 'package:vocab_kr/services/audio/audio_player_service.dart';
import '../helpers/fake_remote.dart';

/// QuizNotifier.loadCards, end to end at the provider level: due-card fetching
/// (single + both directions, failure policy), enrichment against a real
/// in-memory drift DB, the drop rule for unresolvable variants, and padding.
/// Harness follows paywall_gate_test.dart (ProviderContainer + overrides).

final _now = DateTime(2026, 7, 3);

class _NoopAudio implements AudioPlayerService {
  final prefetchedPaths = <String?>[];
  final spokenPaths = <String?>[];
  final prefetchedWords = <String>[];
  final spokenWords = <String>[];
  @override
  Future<void> warmUp(String langCode) async {}
  @override
  Future<void> prefetch(
    String text,
    String langCode, {
    String? audioPath,
  }) async {
    prefetchedPaths.add(audioPath);
    prefetchedWords.add(text);
  }

  @override
  Future<void> speak(
    String text,
    String langCode, {
    String? audioPath,
    bool requirePlayback = false,
  }) async {
    spokenPaths.add(audioPath);
    spokenWords.add(text);
  }

  @override
  Future<void> stop() async {}
  @override
  Future<PlayerState> get state async => PlayerState.stopped;
  @override
  bool get isSpeaking => false;
  @override
  void dispose() {}
}

/// Serves canned due-card lists (or failures) per direction, honoring `limit`
/// the way the real repository would.
class _FakeProgressRepo implements ProgressRepository {
  _FakeProgressRepo(this.responses, {this.delayed});
  final Map<QuizDirection, Result<List<VariantProgress>>> responses;
  final Completer<void>? delayed;

  @override
  Future<Result<List<VariantProgress>>> getDueCards({
    required String userId,
    required String listId,
    required QuizDirection direction,
    int limit = 20,
  }) async {
    if (listId == 'slow') await delayed?.future;
    final r = responses[direction] ?? const Success([]);
    if (r.isFailure) return r;
    return Success(r.valueOrNull!.take(limit).toList());
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

VariantProgress _due(String variantId, QuizDirection direction) =>
    VariantProgress(
      id: 'p-$variantId',
      userId: 'u',
      variantId: variantId,
      direction: direction,
      createdAt: _now,
      updatedAt: _now,
    );

void main() {
  late AppDatabase db;
  // fr word → variant ids, seeded in setUp.
  late Map<String, String> frVariantId;
  late Map<String, String> koVariantId;
  late _NoopAudio audio;

  const words = [('chat', '고양이'), ('chien', '개'), ('maison', '집')];

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final repo = VocabularyRepositoryImpl(
      db.vocabularyListDao,
      db.conceptDao,
      FakeRemote(),
      'u',
      db,
    );
    final list = (await repo.createList(name: 'Quiz List')).valueOrNull!;
    frVariantId = {};
    koVariantId = {};
    for (final (fr, ko) in words) {
      final concept = (await repo.addConceptWithVariants(
        listId: list.id,
        wordA: fr,
        wordB: ko,
      )).valueOrNull!;
      final variants = await db.conceptDao.getVariantsByConcept(concept.id);
      frVariantId[fr] = variants.firstWhere((v) => v.langCode == 'fr').id;
      koVariantId[ko] = variants.firstWhere((v) => v.langCode == 'ko').id;
    }
  });
  tearDown(() => db.close());

  /// Container wired for loadCards; keeps the autoDispose notifier alive.
  (ProviderContainer, ProviderSubscription<QuizState>) harness(
    Map<QuizDirection, Result<List<VariantProgress>>> responses, {
    Completer<void>? delayed,
  }) {
    final container = ProviderContainer(
      overrides: [
        getDueCardsUseCaseProvider.overrideWithValue(
          GetDueCardsUseCase(_FakeProgressRepo(responses, delayed: delayed)),
        ),
        appDatabaseProvider.overrideWithValue(db),
        vocabularyRemoteProvider.overrideWithValue(FakeRemote()),
        conceptDaoProvider.overrideWithValue(db.conceptDao),
        currentUserProvider.overrideWithValue(null),
        audioPlayerServiceProvider.overrideWithValue(audio = _NoopAudio()),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(quizProvider, (_, _) {});
    return (container, sub);
  }

  QuizArgs args({
    QuizDirectionChoice direction = QuizDirectionChoice.frToKo,
    int cardLimit = 3,
    String listId = 'ignored-by-fake',
  }) => QuizArgs(
    listId: listId,
    mode: QuizMode.flashcard,
    direction: direction,
    cardLimit: cardLimit,
  );

  test(
    'a direct reload clears previous state and discards a stale load',
    () async {
      final delayed = Completer<void>();
      final (container, sub) = harness({
        QuizDirection.frToKo: Success([
          _due(frVariantId['chat']!, QuizDirection.frToKo),
        ]),
        QuizDirection.koToFr: Success([
          _due(koVariantId['개']!, QuizDirection.koToFr),
        ]),
      }, delayed: delayed);
      final quiz = container.read(quizProvider.notifier);
      await quiz.loadCards(args(cardLimit: 1));
      quiz.flipCard();
      quiz.setListening(true);
      quiz.setPartialTranscript('old transcript');
      quiz.setForeground(false);
      quiz.setPaused(true);
      expect(sub.read().isFlipped, isTrue);

      final oldLoad = quiz.loadCards(args(listId: 'slow', cardLimit: 1));
      expect(sub.read().cards, isEmpty);
      expect(sub.read().isLoading, isTrue);
      expect(sub.read().isFlipped, isFalse);
      expect(sub.read().isListening, isFalse);
      expect(sub.read().partialTranscript, isEmpty);
      audio.spokenPaths.clear();

      await quiz.loadCards(
        args(direction: QuizDirectionChoice.koToFr, cardLimit: 1),
      );
      expect(sub.read().currentCard!.questionWord, '개');
      expect(audio.spokenPaths, [sub.read().currentCard!.questionAudioPath]);
      delayed.complete();
      await oldLoad;

      expect(sub.read().currentCard!.questionWord, '개');
      expect(audio.spokenPaths, hasLength(1));
    },
  );

  test(
    'single direction: cards are enriched with question + answer words',
    () async {
      final (container, sub) = harness({
        QuizDirection.frToKo: Success([
          _due(frVariantId['chat']!, QuizDirection.frToKo),
          _due(frVariantId['chien']!, QuizDirection.frToKo),
          _due(frVariantId['maison']!, QuizDirection.frToKo),
        ]),
      });

      await container.read(quizProvider.notifier).loadCards(args());

      final state = sub.read();
      expect(state.isLoading, isFalse);
      expect(state.errorMessage, isNull);
      expect(state.cards.length, 3);
      expect(
        state.cards.map((c) => c.questionWord),
        containsAll(['chat', 'chien', 'maison']),
      );
      final chat = state.cards.firstWhere((c) => c.questionWord == 'chat');
      expect(chat.answerWords, contains('고양이'));
      expect(chat.questionAudioPath, startsWith('users/u/'));
      expect(chat.answerAudioPath, startsWith('users/u/'));
    },
  );

  test(
    'a loaded session prefetches every published prompt and answer',
    () async {
      final (container, _) = harness({
        QuizDirection.frToKo: Success([
          _due(frVariantId['chat']!, QuizDirection.frToKo),
          _due(frVariantId['chien']!, QuizDirection.frToKo),
          _due(frVariantId['maison']!, QuizDirection.frToKo),
        ]),
      });

      await container.read(quizProvider.notifier).loadCards(args());
      await Future<void>.delayed(Duration.zero);

      expect(audio.prefetchedPaths, hasLength(6));
      expect(audio.prefetchedPaths, everyElement(startsWith('users/u/')));
    },
  );

  for (final cached in [true, false]) {
    test('the primary synonym supplies the spoken word and audio lookup '
        '(cached path: $cached) while other synonyms are accepted', () async {
      final oldId = frVariantId['chat']!;
      final old = (await db.conceptDao.getVariantById(oldId))!;
      await db.conceptDao.upsertVariant(
        old.copyWith(word: 'minou', isPrimary: false).toCompanion(false),
      );
      final primaryPath = cached ? 'seed/chat.mp3' : null;
      await db.conceptDao.upsertVariant(
        WordVariantsTableCompanion.insert(
          id: 'primary-chat',
          conceptId: old.conceptId,
          word: 'chat',
          langCode: 'fr',
          isPrimary: const Value(true),
          audioPath: Value(primaryPath),
          position: const Value(1),
          createdAt: _now,
          updatedAt: _now,
        ),
      );
      expect(
        (await db.conceptDao.getVariantsByConceptIds([
          old.conceptId,
        ], 'fr')).map((variant) => variant.word),
        ['minou', 'chat'],
      );
      final (container, sub) = harness({
        QuizDirection.koToFr: Success([
          _due(koVariantId['고양이']!, QuizDirection.koToFr),
        ]),
      });
      final quiz = container.read(quizProvider.notifier);
      await quiz.loadCards(
        args(direction: QuizDirectionChoice.koToFr, cardLimit: 1),
      );
      await Future<void>.delayed(Duration.zero);
      final card = sub.read().currentCard!;
      expect(card.answerWords, ['chat', 'minou']);
      expect(audio.prefetchedWords.last, 'chat');
      expect(audio.prefetchedPaths.last, primaryPath);
      quiz.flipCard();
      expect(audio.spokenWords.last, 'chat');
      expect(audio.spokenPaths.last, primaryPath);
      quiz.submitTextAnswer('minou');
      expect(sub.read().answerState, QuizAnswerState.correct);
    });
  }

  test('both directions fill a due-only limit with 20 distinct real '
      'SQLite cards when only one direction is due', () async {
    final remote = FakeRemote();
    final repo = VocabularyRepositoryImpl(
      db.vocabularyListDao,
      db.conceptDao,
      remote,
      'u',
      db,
    );
    final progressRepo = ProgressRepositoryImpl(
      db.progressDao,
      db.conceptDao,
      remote,
      'u',
    );
    final list = (await repo.createList(name: 'Due-only')).valueOrNull!;
    final variants = <String>{};
    for (var i = 0; i < 20; i++) {
      final concept = (await repo.addConceptWithVariants(
        listId: list.id,
        wordA: 'mot $i',
        wordB: '단어 $i',
      )).valueOrNull!;
      final question = (await db.conceptDao.getVariantsByConcept(
        concept.id,
      )).singleWhere((variant) => variant.langCode == 'fr');
      variants.add(question.id);
      await db.progressDao.upsertLocal(
        _due(question.id, QuizDirection.frToKo).toLocalCompanion(),
      );
    }
    final container = ProviderContainer(
      overrides: [
        getDueCardsUseCaseProvider.overrideWithValue(
          GetDueCardsUseCase(progressRepo),
        ),
        conceptDaoProvider.overrideWithValue(db.conceptDao),
        currentUserProvider.overrideWithValue(
          AppUser(
            id: 'u',
            username: 'learner',
            email: 'u@example.invalid',
            createdAt: _now,
          ),
        ),
        audioPlayerServiceProvider.overrideWithValue(_NoopAudio()),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(quizProvider, (_, _) {});
    await container
        .read(quizProvider.notifier)
        .loadCards(
          const QuizArgs(
            mode: QuizMode.flashcard,
            source: QuizSource.allDue,
            direction: QuizDirectionChoice.both,
            cardLimit: 20,
          ),
        );
    final cards = sub.read().cards;
    expect(cards, hasLength(20));
    expect(
      cards.map((card) => card.progress.variantId),
      unorderedEquals(variants),
    );
    expect(cards.map((card) => card.progress.direction).toSet(), {
      QuizDirection.frToKo,
    });
  });

  test(
    'subsequent and postponed cards retain the published audio clip',
    () async {
      final (container, sub) = harness({
        QuizDirection.frToKo: Success([
          _due(frVariantId['chat']!, QuizDirection.frToKo),
          _due(frVariantId['chien']!, QuizDirection.frToKo),
        ]),
      });
      final notifier = container.read(quizProvider.notifier);
      await notifier.loadCards(args(cardLimit: 2));
      final first = sub.read().currentCard!;
      expect(audio.spokenPaths.single, first.questionAudioPath);
      notifier.skipCurrentCard();
      await Future<void>.delayed(Duration.zero);
      final next = sub.read().currentCard!;
      expect(audio.spokenPaths.last, next.questionAudioPath);
      expect(sub.read().cards.last.questionAudioPath, first.questionAudioPath);
      expect(sub.read().cards.last.answerAudioPath, first.answerAudioPath);
    },
  );

  test('both directions: cards mix WITHOUT the same concept back-to-back '
      '(the old strict alternation dealt "chat" then "고양이" — the same '
      'word with the languages swapped; user report 2026-07-21)', () async {
    final (container, sub) = harness({
      QuizDirection.frToKo: Success([
        _due(frVariantId['chat']!, QuizDirection.frToKo),
        _due(frVariantId['chien']!, QuizDirection.frToKo),
      ]),
      QuizDirection.koToFr: Success([
        _due(koVariantId['고양이']!, QuizDirection.koToFr),
        _due(koVariantId['개']!, QuizDirection.koToFr),
      ]),
    });

    await container
        .read(quizProvider.notifier)
        .loadCards(args(direction: QuizDirectionChoice.both, cardLimit: 4));

    final cards = sub.read().cards;
    // Both directions are present…
    expect(cards.map((c) => c.progress.direction).toSet(), {
      QuizDirection.frToKo,
      QuizDirection.koToFr,
    });
    // …and the two directions of one concept are spaced as far apart as a
    // 2-concept deck allows (greedy: both FR fronts, then both KO fronts).
    expect(cards.map((c) => c.questionWord).toList(), [
      'chat',
      'chien',
      '고양이',
      '개',
    ]);
  });

  test(
    'both mode: one side failing still builds a session from the other',
    () async {
      final (container, sub) = harness({
        QuizDirection.frToKo: const Failure(NetworkException('down')),
        QuizDirection.koToFr: Success([
          _due(koVariantId['고양이']!, QuizDirection.koToFr),
          _due(koVariantId['개']!, QuizDirection.koToFr),
        ]),
      });

      await container
          .read(quizProvider.notifier)
          .loadCards(args(direction: QuizDirectionChoice.both, cardLimit: 4));

      final state = sub.read();
      expect(state.errorMessage, isNull);
      // 2 KO cards padded cyclically to the limit of 4.
      expect(state.cards.length, 4);
      expect(
        state.cards.every((c) => c.progress.direction == QuizDirection.koToFr),
        isTrue,
      );
    },
  );

  test('both mode: both sides failing → error state, no session', () async {
    final (container, sub) = harness({
      QuizDirection.frToKo: const Failure(NetworkException('down')),
      QuizDirection.koToFr: const Failure(NetworkException('down')),
    });

    await container
        .read(quizProvider.notifier)
        .loadCards(args(direction: QuizDirectionChoice.both, cardLimit: 4));

    final state = sub.read();
    expect(state.errorMessage, isNotNull);
    expect(state.isLoading, isFalse);
    expect(state.cards, isEmpty);
  });

  test('single direction failure → error state', () async {
    final (container, sub) = harness({
      QuizDirection.frToKo: const Failure(NetworkException('down')),
    });

    await container.read(quizProvider.notifier).loadCards(args());

    expect(sub.read().errorMessage, isNotNull);
  });

  test(
    'no due cards exposes a retryable empty state without a result',
    () async {
      final (container, sub) = harness({
        QuizDirection.frToKo: const Success([]),
      });

      await container.read(quizProvider.notifier).loadCards(args());

      final state = sub.read();
      expect(state.isEmpty, isTrue);
      expect(state.isComplete, isFalse);
      expect(state.errorMessage, isNull);
      expect(state.cards, isEmpty);
    },
  );

  test(
    'availability matches the live quiz for the pair, source and direction',
    () async {
      final remote = FakeRemote();
      final repo = VocabularyRepositoryImpl(
        db.vocabularyListDao,
        db.conceptDao,
        remote,
        'u',
        db,
      );
      final list = (await repo.watchMyLists().first).single;
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vocabularyRemoteProvider.overrideWithValue(remote),
          currentUserProvider.overrideWithValue(
            AppUser(
              id: 'u',
              username: 'learner',
              email: 'u@example.invalid',
              createdAt: _now,
            ),
          ),
          audioPlayerServiceProvider.overrideWithValue(_NoopAudio()),
        ],
      );
      addTearDown(container.dispose);
      QuizAvailabilityQuery query(
        QuizSource source,
        QuizDirectionChoice direction, {
        (String, String) pair = ('fr', 'ko'),
      }) => (
        pair: pair,
        source: source,
        direction: direction,
        listId: source == QuizSource.list ? list.id : null,
      );
      Future<int> count(QuizAvailabilityQuery query) =>
          container.read(quizAvailabilityProvider(query).future);

      const forward = QuizDirectionChoice.frToKo;
      const backward = QuizDirectionChoice.koToFr;
      const both = QuizDirectionChoice.both;
      expect(await count(query(QuizSource.inProgress, both)), 0);
      expect(await count(query(QuizSource.allDue, both)), 0);
      expect(await count(query(QuizSource.list, both)), 6);

      final saved = _due(
        frVariantId['chat']!,
        QuizDirection.frToKo,
      ).copyWith(state: CardState.review, timesShown: 1);
      await db.progressDao.upsertLocal(saved.toLocalCompanion());
      final incomplete = (await repo.createConcept(
        listId: list.id,
      )).valueOrNull!;
      final noTranslation = (await repo.createVariant(
        conceptId: incomplete.id,
        word: 'unanswered',
        langCode: 'fr',
      )).valueOrNull!;
      await db.progressDao.upsertLocal(
        _due(
          noTranslation.id,
          QuizDirection.frToKo,
        ).copyWith(state: CardState.review).toLocalCompanion(),
      );
      expect(await count(query(QuizSource.allDue, backward)), 0);
      expect(
        await count(query(QuizSource.allDue, both, pair: ('ko', 'fr'))),
        0,
      );
      expect(await count(query(QuizSource.inProgress, forward)), 1);
      expect(await count(query(QuizSource.inProgress, backward)), 0);
      expect(await count(query(QuizSource.list, both)), 6);

      final due = quizAvailabilityProvider(query(QuizSource.allDue, forward));
      final disappeared = Completer<void>();
      final availability = container.listen(due, (_, value) {
        if (value.valueOrNull == 0 && !disappeared.isCompleted) {
          disappeared.complete();
        }
      });
      addTearDown(availability.close);
      expect(await container.read(due.future), 1);
      final keptQuiz = container.listen(quizProvider, (_, _) {});
      addTearDown(keptQuiz.close);
      final quiz = container.read(quizProvider.notifier);
      const args = QuizArgs(
        source: QuizSource.allDue,
        mode: QuizMode.flashcard,
        direction: forward,
        cardLimit: 1,
      );
      await quiz.loadCards(args);
      expect(keptQuiz.read().cards.single.questionWord, 'chat');

      await db.progressDao.upsertLocal(
        saved
            .copyWith(nextReview: DateTime.now().add(const Duration(days: 1)))
            .toLocalCompanion(),
      );
      await disappeared.future.timeout(const Duration(seconds: 2));
      expect(await count(query(QuizSource.inProgress, forward)), 1);
      await quiz.loadCards(args);
      expect(keptQuiz.read().isEmpty, isTrue);
      expect(keptQuiz.read().isComplete, isFalse);
      expect(await db.quizSessionDao.getSessionsByUser('u'), isEmpty);
    },
  );

  test(
    'a progress row pointing at a missing variant is dropped, not crashed',
    () async {
      final (container, sub) = harness({
        QuizDirection.frToKo: Success([
          _due(frVariantId['chat']!, QuizDirection.frToKo),
          _due('no-such-variant', QuizDirection.frToKo),
        ]),
      });

      await container.read(quizProvider.notifier).loadCards(args(cardLimit: 2));

      final state = sub.read();
      expect(state.errorMessage, isNull);
      // The broken row is dropped; the survivor is padded up to the limit.
      expect(state.cards.length, 2);
      expect(state.cards.every((c) => c.questionWord == 'chat'), isTrue);
    },
  );

  test(
    'fewer due cards than the limit → padded cyclically to the limit',
    () async {
      final (container, sub) = harness({
        QuizDirection.frToKo: Success([
          _due(frVariantId['chat']!, QuizDirection.frToKo),
        ]),
      });

      await container.read(quizProvider.notifier).loadCards(args(cardLimit: 3));

      final state = sub.read();
      expect(state.cards.length, 3);
      expect(state.cards.every((c) => c.questionWord == 'chat'), isTrue);
      expect(state.isComplete, isFalse);
    },
  );
}
