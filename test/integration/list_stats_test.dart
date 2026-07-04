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
/// now the foundation of the grammar prerequisite gate ("is this list
/// known?"). Also pins the pure isListKnown rule.

const _kUserId = 'u';
final _now = DateTime(2026, 7, 4);

void main() {
  late AppDatabase db;
  late VocabularyRepositoryImpl vocabRepo;
  late ProgressRepositoryImpl progressRepo;

  Future<String> seedWord(String listId, String fr, String ko) async {
    final concept = (await vocabRepo.addConceptWithVariants(
            listId: listId, frWord: fr, koWord: ko))
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

      final stats =
          (await progressRepo.getListStats(list.id)).valueOrNull!;

      expect(stats['total'], 4);
      expect(stats['mastered'], 1); // only review + ≥21 scheduled days
      expect(stats['due'], 1); // only the past-scheduled learning card
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
      expect(stats, {'total': 0, 'mastered': 0, 'due': 0});
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
          (await progressRepo.getListStats(b.id)).valueOrNull!['mastered'],
          1);
    });
  });

  group('isListKnown (grammar prerequisite gate)', () {
    test('≥90% mastered → known', () {
      expect(isListKnown(total: 10, mastered: 9), isTrue);
      expect(isListKnown(total: 10, mastered: 10), isTrue);
    });

    test('below the threshold → not known', () {
      expect(isListKnown(total: 10, mastered: 8), isFalse);
      expect(isListKnown(total: 3, mastered: 0), isFalse);
    });

    test('an empty list is never known', () {
      expect(isListKnown(total: 0, mastered: 0), isFalse);
      expect(listMasteryRatio(total: 0, mastered: 0), 0);
    });

    test('threshold is overridable per lesson', () {
      expect(isListKnown(total: 10, mastered: 5, threshold: 0.5), isTrue);
    });
  });
}
