// ignore_for_file: invalid_use_of_internal_member

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/core/errors/failure.dart';
import 'package:vocab_kr/core/utils/fsrs_algorithm.dart';
import 'package:vocab_kr/data/datasources/local/app_database.dart';
import 'package:vocab_kr/data/repositories/progress_repository_impl.dart';
import 'package:vocab_kr/data/repositories/vocabulary_repository_impl.dart';
import 'package:vocab_kr/domain/entities/concept.dart';
import 'package:vocab_kr/domain/entities/variant_progress.dart';
import 'package:vocab_kr/domain/entities/vocabulary_list.dart';

import '../helpers/fake_remote.dart';

const _kUserId = 'test-user-abc123';

void main() {
  late AppDatabase db;
  late VocabularyRepositoryImpl vocabRepo;
  late ProgressRepositoryImpl progressRepo;

  // IDs set up per test group that needs them.
  late String frVariantId;
  late String koVariantId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final remote = FakeRemote();
    vocabRepo = VocabularyRepositoryImpl(
      db.vocabularyListDao,
      db.conceptDao,
      remote,
      _kUserId,
      db,
    );
    progressRepo = ProgressRepositoryImpl(
      db.progressDao,
      db.conceptDao,
      remote,
      _kUserId,
    );
  });

  tearDown(() => db.close());

  // Helper: create list + one word → sets frVariantId and koVariantId.
  Future<VocabularyList> setup() async {
    final list = ((await vocabRepo.createList(name: 'Quiz List', description: null))
            as Success<VocabularyList>)
        .value;
    final concept = ((await vocabRepo.addConceptWithVariants(
      listId: list.id,
      frWord: 'Bonjour',
      koWord: '안녕하세요',
    )) as Success<Concept>)
        .value;
    final variants = await db.conceptDao.getVariantsByConcept(concept.id);
    frVariantId = variants.firstWhere((v) => v.langCode == 'fr').id;
    koVariantId = variants.firstWhere((v) => v.langCode == 'ko').id;
    return list;
  }

  // ── getProgress ───────────────────────────────────────────────────────────

  group('getProgress', () {
    test('returns new-card defaults when no record exists', () async {
      await setup();
      final result = await progressRepo.getProgress(
        variantId: frVariantId,
        direction: QuizDirection.frToKo,
      );
      final progress = (result as Success<VariantProgress>).value;
      expect(progress.stability, 0.0);
      expect(progress.difficulty, 5.0);
      expect(progress.reps, 0);
      expect(progress.state, CardState.newCard);
      expect(progress.lapses, 0);
    });

    test('returns the existing record unchanged when one exists', () async {
      await setup();
      final initial = await progressRepo.getProgress(
        variantId: frVariantId,
        direction: QuizDirection.frToKo,
      );
      final p = (initial as Success<VariantProgress>).value.copyWith(reps: 7);
      await progressRepo.updateProgress(p);

      final fetched = await progressRepo.getProgress(
        variantId: frVariantId,
        direction: QuizDirection.frToKo,
      );
      expect((fetched as Success<VariantProgress>).value.reps, 7);
    });
  });

  // ── updateProgress ────────────────────────────────────────────────────────

  group('updateProgress', () {
    test('all FSRS fields are persisted', () async {
      await setup();
      final now = DateTime.now();
      final base = ((await progressRepo.getProgress(
        variantId: frVariantId,
        direction: QuizDirection.frToKo,
      )) as Success<VariantProgress>)
          .value;

      final updated = base.copyWith(
        stability: 3.5,
        difficulty: 7.2,
        reps: 4,
        lapses: 1,
        state: CardState.review,
        scheduledDays: 10,
        nextReview: now.add(const Duration(days: 10)),
        lastReview: now,
      );
      await progressRepo.updateProgress(updated);

      final fetched = ((await progressRepo.getProgress(
        variantId: frVariantId,
        direction: QuizDirection.frToKo,
      )) as Success<VariantProgress>)
          .value;

      expect(fetched.stability, closeTo(3.5, 0.001));
      expect(fetched.difficulty, closeTo(7.2, 0.001));
      expect(fetched.reps, 4);
      expect(fetched.lapses, 1);
      expect(fetched.state, CardState.review);
      expect(fetched.scheduledDays, 10);
    });

    test('isSynced=false after update', () async {
      await setup();
      final base = ((await progressRepo.getProgress(
        variantId: frVariantId,
        direction: QuizDirection.frToKo,
      )) as Success<VariantProgress>)
          .value;
      await progressRepo.updateProgress(base.copyWith(reps: 1, isSynced: true));
      final row = await db.progressDao.getByVariantAndDirection(
          frVariantId, QuizDirection.frToKo.name);
      expect(row!.isSynced, isFalse);
    });
  });

  // ── getDueCards ───────────────────────────────────────────────────────────

  group('getDueCards', () {
    test('returns new cards (no prior progress) for all variants in a list',
        () async {
      final list = await setup();
      final result = await progressRepo.getDueCards(
        userId: _kUserId,
        listId: list.id,
        direction: QuizDirection.frToKo,
      );
      final cards = (result as Success<List<VariantProgress>>).value;
      expect(cards.length, 1,
          reason: 'One fr variant → one new card for frToKo');
    });

    test('excludes cards scheduled to the future', () async {
      final list = await setup();
      // Set nextReview to tomorrow → card should not be due.
      final base = ((await progressRepo.getProgress(
        variantId: frVariantId,
        direction: QuizDirection.frToKo,
      )) as Success<VariantProgress>)
          .value;
      await progressRepo.updateProgress(base.copyWith(
        nextReview: DateTime.now().add(const Duration(days: 1)),
        state: CardState.review,
        reps: 1,
      ));

      final result = await progressRepo.getDueCards(
        userId: _kUserId,
        listId: list.id,
        direction: QuizDirection.frToKo,
      );
      expect((result as Success<List<VariantProgress>>).value, isEmpty);
    });

    test('includes cards past due (nextReview in the past)', () async {
      final list = await setup();
      final base = ((await progressRepo.getProgress(
        variantId: frVariantId,
        direction: QuizDirection.frToKo,
      )) as Success<VariantProgress>)
          .value;
      await progressRepo.updateProgress(base.copyWith(
        nextReview: DateTime.now().subtract(const Duration(days: 1)),
        state: CardState.review,
        reps: 1,
      ));

      final result = await progressRepo.getDueCards(
        userId: _kUserId,
        listId: list.id,
        direction: QuizDirection.frToKo,
      );
      expect((result as Success<List<VariantProgress>>).value.length, 1);
    });

    test('respects the limit parameter', () async {
      // Create 3 words in the list.
      final list = ((await vocabRepo.createList(name: 'Big List', description: null))
              as Success<VocabularyList>)
          .value;
      await vocabRepo.addConceptWithVariants(
          listId: list.id, frWord: 'A', koWord: 'ㄱ');
      await vocabRepo.addConceptWithVariants(
          listId: list.id, frWord: 'B', koWord: 'ㄴ');
      await vocabRepo.addConceptWithVariants(
          listId: list.id, frWord: 'C', koWord: 'ㄷ');

      final result = await progressRepo.getDueCards(
        userId: _kUserId,
        listId: list.id,
        direction: QuizDirection.frToKo,
        limit: 2,
      );
      expect((result as Success<List<VariantProgress>>).value.length, 2);
    });

    test('frToKo only returns fr-source variants', () async {
      final list = await setup();
      final result = await progressRepo.getDueCards(
        userId: _kUserId,
        listId: list.id,
        direction: QuizDirection.frToKo,
      );
      final cards = (result as Success<List<VariantProgress>>).value;
      // All returned variantIds should be fr variants.
      for (final card in cards) {
        expect(card.variantId, frVariantId,
            reason: 'frToKo should only use fr variants as questions');
      }
    });

    test('koToFr only returns ko-source variants', () async {
      final list = await setup();
      final result = await progressRepo.getDueCards(
        userId: _kUserId,
        listId: list.id,
        direction: QuizDirection.koToFr,
      );
      final cards = (result as Success<List<VariantProgress>>).value;
      for (final card in cards) {
        expect(card.variantId, koVariantId,
            reason: 'koToFr should only use ko variants as questions');
      }
    });
  });

  // ── watchDueCount ─────────────────────────────────────────────────────────

  group('watchDueCount', () {
    test('emits 0 when no progress rows exist', () async {
      final count = await progressRepo.watchDueCount(_kUserId).first;
      expect(count, 0);
    });

    test('emits 1 after a progress record with nextReview=null is inserted',
        () async {
      await setup();
      final base = ((await progressRepo.getProgress(
        variantId: frVariantId,
        direction: QuizDirection.frToKo,
      )) as Success<VariantProgress>)
          .value;
      // nextReview=null means due immediately.
      await progressRepo.updateProgress(base.copyWith(nextReview: null));

      final count = await progressRepo.watchDueCount(_kUserId).first;
      expect(count, 1);
    });

    test('drops to 0 after nextReview is set to a future date', () async {
      await setup();
      final base = ((await progressRepo.getProgress(
        variantId: frVariantId,
        direction: QuizDirection.frToKo,
      )) as Success<VariantProgress>)
          .value;
      await progressRepo.updateProgress(base.copyWith(nextReview: null));
      // Now schedule it to the future.
      await progressRepo.updateProgress(
        base.copyWith(
          nextReview: DateTime.now().add(const Duration(days: 10)),
          state: CardState.review,
          reps: 1,
        ),
      );

      final count = await progressRepo.watchDueCount(_kUserId).first;
      expect(count, 0);
    });
  });

  // ── FSRS state transitions (end-to-end persistence) ──────────────────────

  group('FSRS state transitions', () {
    late VariantProgress newCard;

    setUp(() async {
      await setup();
      newCard = ((await progressRepo.getProgress(
        variantId: frVariantId,
        direction: QuizDirection.frToKo,
      )) as Success<VariantProgress>)
          .value;
    });

    FsrsCard toFsrsCard(VariantProgress p) => FsrsCard(
          stability: p.stability,
          difficulty: p.difficulty,
          elapsedDays: p.elapsedDays,
          scheduledDays: p.scheduledDays,
          reps: p.reps,
          lapses: p.lapses,
          state: p.state,
          lastReview: p.lastReview,
          nextReview: p.nextReview,
        );

    Future<VariantProgress> apply(
        VariantProgress p, FsrsRating rating) async {
      final now = DateTime.now();
      final scheduled = AppFsrs.schedule(toFsrsCard(p), rating, now);
      final updated = p.copyWith(
        stability: scheduled.stability,
        difficulty: scheduled.difficulty,
        elapsedDays: scheduled.elapsedDays,
        scheduledDays: scheduled.scheduledDays,
        reps: scheduled.reps,
        lapses: scheduled.lapses,
        state: scheduled.state,
        lastReview: scheduled.lastReview,
        nextReview: scheduled.nextReview,
        isSynced: false,
        updatedAt: now,
      );
      await progressRepo.updateProgress(updated);
      return ((await progressRepo.getProgress(
        variantId: frVariantId,
        direction: QuizDirection.frToKo,
      )) as Success<VariantProgress>)
          .value;
    }

    test('new card + Again → state=learning, reps=1, stability>0, lapses=0',
        () async {
      final after = await apply(newCard, FsrsRating.again);
      expect(after.state, CardState.learning);
      expect(after.reps, 1);
      expect(after.stability, greaterThan(0));
      expect(after.lapses, 0);
    });

    test('new card + Good → state=learning, reps=1', () async {
      final after = await apply(newCard, FsrsRating.good);
      expect(after.state, CardState.learning);
      expect(after.reps, 1);
    });

    test('learning card + Good → state=review, scheduledDays>1', () async {
      final learning = await apply(newCard, FsrsRating.good);
      final after = await apply(learning, FsrsRating.good);
      expect(after.state, CardState.review);
      expect(after.scheduledDays, greaterThan(1));
    });

    test('review card + Again → state=relearning, lapses=1', () async {
      final learning = await apply(newCard, FsrsRating.good);
      final review = await apply(learning, FsrsRating.good);
      final after = await apply(review, FsrsRating.again);
      expect(after.state, CardState.relearning);
      expect(after.lapses, 1);
    });
  });

  // ── bidirectional progress isolation ─────────────────────────────────────

  group('bidirectional progress isolation', () {
    setUp(() async => await setup());

    test('same variant, frToKo and koToFr → two separate progress rows',
        () async {
      final frProgress = ((await progressRepo.getProgress(
        variantId: frVariantId,
        direction: QuizDirection.frToKo,
      )) as Success<VariantProgress>)
          .value;
      await progressRepo.updateProgress(frProgress.copyWith(reps: 5));

      final koProgress = ((await progressRepo.getProgress(
        variantId: frVariantId,
        direction: QuizDirection.koToFr,
      )) as Success<VariantProgress>)
          .value;
      // The koToFr record must be independent (reps still 0).
      expect(koProgress.reps, 0);
    });

    test('updating frToKo does not change the koToFr record', () async {
      final frProgress = ((await progressRepo.getProgress(
        variantId: koVariantId,
        direction: QuizDirection.koToFr,
      )) as Success<VariantProgress>)
          .value;
      await progressRepo.updateProgress(frProgress.copyWith(reps: 10));

      final koCheck = ((await progressRepo.getProgress(
        variantId: koVariantId,
        direction: QuizDirection.frToKo,
      )) as Success<VariantProgress>)
          .value;
      expect(koCheck.reps, 0);
    });
  });

  // ── getMasteredVariants ───────────────────────────────────────────────────

  group('getMasteredVariants', () {
    setUp(() async => await setup());

    Future<void> setProgress(
      String variantId, {
      required CardState state,
      required int scheduledDays,
      int reps = 2,
    }) async {
      final base = ((await progressRepo.getProgress(
        variantId: variantId,
        direction: QuizDirection.frToKo,
      )) as Success<VariantProgress>)
          .value;
      await progressRepo.updateProgress(base.copyWith(
        state: state,
        scheduledDays: scheduledDays,
        reps: reps,
      ));
    }

    test('returns empty list when no progress exists', () async {
      final result = await progressRepo.getMasteredVariants(_kUserId);
      expect((result as Success<List<VariantProgress>>).value, isEmpty);
    });

    test('review card with scheduledDays==21 is included', () async {
      await setProgress(frVariantId,
          state: CardState.review, scheduledDays: 21);
      final result = await progressRepo.getMasteredVariants(_kUserId);
      final mastered = (result as Success<List<VariantProgress>>).value;
      expect(mastered.length, 1);
      expect(mastered.first.variantId, frVariantId);
    });

    test('review card with scheduledDays>21 is included', () async {
      await setProgress(frVariantId,
          state: CardState.review, scheduledDays: 60);
      final result = await progressRepo.getMasteredVariants(_kUserId);
      expect((result as Success<List<VariantProgress>>).value.length, 1);
    });

    test('review card with scheduledDays==20 is excluded', () async {
      await setProgress(frVariantId,
          state: CardState.review, scheduledDays: 20);
      final result = await progressRepo.getMasteredVariants(_kUserId);
      expect((result as Success<List<VariantProgress>>).value, isEmpty);
    });

    test('learning-state card with high scheduledDays is excluded', () async {
      await setProgress(frVariantId,
          state: CardState.learning, scheduledDays: 30);
      final result = await progressRepo.getMasteredVariants(_kUserId);
      expect((result as Success<List<VariantProgress>>).value, isEmpty);
    });

    test('relearning-state card with high scheduledDays is excluded', () async {
      await setProgress(frVariantId,
          state: CardState.relearning, scheduledDays: 30);
      final result = await progressRepo.getMasteredVariants(_kUserId);
      expect((result as Success<List<VariantProgress>>).value, isEmpty);
    });

    test('results are ordered by scheduledDays descending', () async {
      // Add a second word in its own list.
      final list2 = ((await vocabRepo.createList(
              name: 'List 2', description: null))
              as Success<VocabularyList>)
          .value;
      final c2 = ((await vocabRepo.addConceptWithVariants(
        listId: list2.id,
        frWord: 'Merci',
        koWord: '감사합니다',
      )) as Success<Concept>)
          .value;
      final variants2 = await db.conceptDao.getVariantsByConcept(c2.id);
      final frVariantId2 =
          variants2.firstWhere((v) => v.langCode == 'fr').id;

      // First word: scheduledDays=21 (less mastered).
      await setProgress(frVariantId,
          state: CardState.review, scheduledDays: 21);
      // Second word: scheduledDays=60 (more mastered).
      await setProgress(frVariantId2,
          state: CardState.review, scheduledDays: 60, reps: 5);

      final result = await progressRepo.getMasteredVariants(_kUserId);
      final mastered = (result as Success<List<VariantProgress>>).value;
      expect(mastered.length, 2);
      // Most-mastered (60 days) should come first.
      expect(mastered.first.scheduledDays, 60);
      expect(mastered.last.scheduledDays, 21);
    });

    test('only returns rows for the queried userId', () async {
      await setProgress(frVariantId,
          state: CardState.review, scheduledDays: 30);

      // Another user's mastered card should not appear.
      final result =
          await progressRepo.getMasteredVariants('other-user-id');
      expect((result as Success<List<VariantProgress>>).value, isEmpty);
    });
  });

  // ── isMastered getter ─────────────────────────────────────────────────────

  group('isMastered getter', () {
    VariantProgress make(
            {required CardState state, required int scheduledDays}) =>
        VariantProgress(
          id: 'x',
          userId: 'u',
          variantId: 'v',
          direction: QuizDirection.frToKo,
          state: state,
          scheduledDays: scheduledDays,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
        );

    test('true for review state with scheduledDays==21 (boundary)', () {
      expect(
        make(state: CardState.review, scheduledDays: 21).isMastered,
        isTrue,
      );
    });

    test('true for review state with scheduledDays>21', () {
      expect(
        make(state: CardState.review, scheduledDays: 60).isMastered,
        isTrue,
      );
    });

    test('false for review state with scheduledDays==20 (below boundary)', () {
      expect(
        make(state: CardState.review, scheduledDays: 20).isMastered,
        isFalse,
      );
    });

    test('false for review state with scheduledDays==0', () {
      expect(
        make(state: CardState.review, scheduledDays: 0).isMastered,
        isFalse,
      );
    });

    test('false for newCard state even with scheduledDays>=21', () {
      expect(
        make(state: CardState.newCard, scheduledDays: 30).isMastered,
        isFalse,
      );
    });

    test('false for learning state even with scheduledDays>=21', () {
      expect(
        make(state: CardState.learning, scheduledDays: 30).isMastered,
        isFalse,
      );
    });

    test('false for relearning state even with scheduledDays>=21', () {
      expect(
        make(state: CardState.relearning, scheduledDays: 30).isMastered,
        isFalse,
      );
    });
  });
}
