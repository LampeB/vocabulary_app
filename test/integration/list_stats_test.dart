// ignore_for_file: invalid_use_of_internal_member
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/core/errors/failure.dart';
import 'package:vocab_kr/core/utils/list_mastery.dart';
import 'package:vocab_kr/domain/entities/variant_progress.dart';
import 'package:vocab_kr/data/datasources/local/app_database.dart';
import 'package:vocab_kr/data/repositories/progress_repository_impl.dart';
import 'package:vocab_kr/data/repositories/vocabulary_repository_impl.dart';
import '../helpers/fake_remote.dart';

/// Per-list stats (total / mastered / due) + reset progress — formerly stubs,
/// now the foundation of the grammar prerequisite gate. Also pins the pure
/// combined-prerequisite rule.

const _kUserId = 'u';
final _now = DateTime(2026, 7, 4);

void main() {
  late AppDatabase db;
  late VocabularyRepositoryImpl vocabRepo;
  late ProgressRepositoryImpl progressRepo;

  Future<String> seedWord(String listId, String fr, String ko) async {
    final concept = (await vocabRepo.addConceptWithVariants(
            listId: listId, wordA: fr, wordB: ko))
        .valueOrNull!;
    final variants = await db.conceptDao.getVariantsByConcept(concept.id);
    return variants.firstWhere((v) => v.langCode == 'fr').id;
  }

  Future<void> seedProgress(
    String variantId, {
    required String state,
    int scheduledDays = 0,
    DateTime? nextReview,
  }) =>
      db.progressDao.upsert(VariantProgressTableCompanion.insert(
        id: 'p-$variantId',
        userId: _kUserId,
        variantId: variantId,
        direction: QuizDirection.frToKo.name,
        state: Value(state),
        scheduledDays: Value(scheduledDays),
        nextReview: Value(nextReview),
        createdAt: _now,
        updatedAt: _now,
      ));

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    vocabRepo = VocabularyRepositoryImpl(
        db.vocabularyListDao, db.conceptDao, FakeRemote(), _kUserId, db);
    progressRepo = ProgressRepositoryImpl(
        db.progressDao, db.conceptDao, FakeRemote(), _kUserId);
  });
  tearDown(() => db.close());

  group('getListStats', () {
    test('counts total, mastered (review ≥21j) and due words', () async {
      final list = (await vocabRepo.createList(name: 'A')).valueOrNull!;
      final past = _now.subtract(const Duration(days: 1));
      final future = DateTime.now().add(const Duration(days: 30));

      final mastered = await seedWord(list.id, 'chat', '고양이');
      await seedProgress(mastered,
          state: 'review', scheduledDays: 30, nextReview: future);
      final learningDue = await seedWord(list.id, 'chien', '개');
      await seedProgress(learningDue,
          state: 'learning', scheduledDays: 1, nextReview: past);
      final reviewNotMastered = await seedWord(list.id, 'maison', '집');
      await seedProgress(reviewNotMastered,
          state: 'review', scheduledDays: 10, nextReview: future);
      await seedWord(list.id, 'pain', '빵'); // never studied

      final stats = (await progressRepo.getListStats(list.id)).valueOrNull!;

      expect(stats['total'], 4);
      expect(stats['mastered'], 1); // only review + ≥21 scheduled days
      // 'known' (graduated from learning — the grammar gate) is lighter:
      // both review words count, the learning and never-studied ones don't.
      expect(stats['known'], 2);
      expect(stats['due'], 1); // only the past-scheduled learning card
    });

    test('a relearning (lapsed) word still counts as known, not mastered',
        () async {
      final list = (await vocabRepo.createList(name: 'A')).valueOrNull!;
      final lapsed = await seedWord(list.id, 'chat', '고양이');
      await seedProgress(lapsed, state: 'relearning', scheduledDays: 1);

      final stats = (await progressRepo.getListStats(list.id)).valueOrNull!;

      expect(stats['known'], 1); // it graduated once — the user learned it
      expect(stats['mastered'], 0);
    });

    test('a mastered word in ANOTHER list does not leak in', () async {
      final a = (await vocabRepo.createList(name: 'A')).valueOrNull!;
      final b = (await vocabRepo.createList(name: 'B')).valueOrNull!;
      await seedWord(a.id, 'chat', '고양이');
      final other = await seedWord(b.id, 'chien', '개');
      await seedProgress(other, state: 'review', scheduledDays: 30);

      final stats = (await progressRepo.getListStats(a.id)).valueOrNull!;

      expect(stats['total'], 1);
      expect(stats['mastered'], 0);
    });

    test('empty list → zeros', () async {
      final list = (await vocabRepo.createList(name: 'Vide')).valueOrNull!;
      final stats = (await progressRepo.getListStats(list.id)).valueOrNull!;
      expect(stats, {'total': 0, 'mastered': 0, 'known': 0, 'due': 0});
    });
  });

  group('resetProgress', () {
    test('clears the list\'s progress so its words are new again', () async {
      final list = (await vocabRepo.createList(name: 'A')).valueOrNull!;
      final v = await seedWord(list.id, 'chat', '고양이');
      await seedProgress(v, state: 'review', scheduledDays: 30);
      expect(
          (await progressRepo.getListStats(list.id)).valueOrNull!['mastered'],
          1);

      final result = await progressRepo.resetProgress(list.id);

      expect(result.isSuccess, isTrue);
      final stats = (await progressRepo.getListStats(list.id)).valueOrNull!;
      expect(stats['mastered'], 0);
      expect(stats['due'], 0);
      expect(stats['total'], 1); // the word itself remains
    });

    test('does not touch another list\'s progress', () async {
      final a = (await vocabRepo.createList(name: 'A')).valueOrNull!;
      final b = (await vocabRepo.createList(name: 'B')).valueOrNull!;
      final va = await seedWord(a.id, 'chat', '고양이');
      await seedProgress(va, state: 'review', scheduledDays: 30);
      final vb = await seedWord(b.id, 'chien', '개');
      await seedProgress(vb, state: 'review', scheduledDays: 30);

      await progressRepo.resetProgress(a.id);

      expect(
          (await progressRepo.getListStats(b.id)).valueOrNull!['mastered'], 1);
    });
  });

  group('deleteList mastery loss (product decision 2026-07-04)', () {
    test('deleting a list removes its words from mastery and smart lists',
        () async {
      final list = (await vocabRepo.createList(name: 'A')).valueOrNull!;
      final v = await seedWord(list.id, 'chat', '고양이');
      await seedProgress(v,
          state: 'review',
          scheduledDays: 30,
          nextReview: _now.subtract(const Duration(days: 1)));
      // Mastered and due before deletion…
      expect(
          (await progressRepo.getMasteredVariants(_kUserId))
              .valueOrNull!
              .length,
          1);
      expect(
          (await progressRepo.getAllDueCards(
                  userId: _kUserId, direction: QuizDirection.frToKo))
              .valueOrNull!,
          isNotEmpty);

      await vocabRepo.deleteList(list.id);

      // …gone everywhere after: mastery deleted, smart lists empty.
      expect((await progressRepo.getMasteredVariants(_kUserId)).valueOrNull!,
          isEmpty);
      expect(
          (await progressRepo.getAllDueCards(
                  userId: _kUserId, direction: QuizDirection.frToKo))
              .valueOrNull!,
          isEmpty);
      expect(
          (await progressRepo.getInProgressCards(
                  userId: _kUserId, direction: QuizDirection.frToKo))
              .valueOrNull!,
          isEmpty);
    });
  });

  group('arePrerequisitesKnown (grammar prerequisite gate)', () {
    PrerequisiteProgress p(int known, int total) =>
        PrerequisiteProgress(known: known, total: total);

    test('80% weighted progress unlocks when every list reaches 70%', () {
      // 10/10 + 14/20 = 80% overall; the second list reaches its 70% floor.
      expect(arePrerequisitesKnown([p(10, 10), p(14, 20)]), isTrue);
      expect(arePrerequisitesKnown([p(8, 10)]), isTrue);
    });

    test('a list below 70% remains locked even when the total reaches 80%', () {
      // The previous average-only rule incorrectly opened this at 80%.
      expect(arePrerequisitesKnown([p(10, 10), p(6, 10)]), isFalse);
    });

    test('weighted total prevents a short complete list masking a longer one',
        () {
      // Average = 85%, but 10/10 + 21/30 is only 77.5% of all words.
      expect(arePrerequisitesKnown([p(10, 10), p(21, 30)]), isFalse);
    });

    test('a missing prerequisite cannot open a lesson', () {
      expect(arePrerequisitesKnown([p(10, 10), p(0, 0)]), isFalse);
      expect(listMasteryRatio(total: 0, mastered: 0), 0);
    });

    test('threshold is overridable for a curriculum policy', () {
      expect(
        arePrerequisitesKnown(
          [p(5, 10)],
          combinedThreshold: 0.5,
          minimumPerList: 0.5,
        ),
        isTrue,
      );
    });
  });
}
