// ignore_for_file: invalid_use_of_internal_member
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/core/errors/failure.dart';
import 'package:vocab_kr/data/datasources/local/app_database.dart';
import 'package:vocab_kr/data/repositories/progress_repository_impl.dart';
import 'package:vocab_kr/data/repositories/vocabulary_repository_impl.dart';
import 'package:vocab_kr/domain/entities/variant_progress.dart';
import 'package:vocab_kr/domain/usecases/quiz/get_due_cards_usecase.dart';
import '../helpers/fake_remote.dart';

/// Cross-list smart-list sources ("À réviser maintenant" / "En cours
/// d'apprentissage"): due = started AND scheduled ≤ now, across lists;
/// in-progress = state ≠ new, due or not. Deleted words never resurface.

const _kUserId = 'u';
final _now = DateTime(2026, 7, 4);

void main() {
  late AppDatabase db;
  late VocabularyRepositoryImpl vocabRepo;
  late ProgressRepositoryImpl progressRepo;

  /// Seeds a word in [listName] and returns its FR variant id.
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
    DateTime? nextReview,
  }) =>
      db.progressDao.upsert(VariantProgressTableCompanion.insert(
        id: 'p-$variantId',
        userId: _kUserId,
        variantId: variantId,
        direction: 'frToKo',
        state: Value(state),
        nextReview: Value(nextReview),
        createdAt: _now,
        updatedAt: _now,
      ));

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    vocabRepo = VocabularyRepositoryImpl(
        db.vocabularyListDao, db.conceptDao, FakeRemote(), _kUserId, db);
    progressRepo = ProgressRepositoryImpl(
        db.progressDao, db.conceptDao, FakeRemote(), _kUserId);
  });
  tearDown(() => db.close());

  test(
      'getAllDueCards: due cards from BOTH lists; future-scheduled, '
      'never-studied and deleted words are excluded', () async {
    final l1 = (await vocabRepo.createList(name: 'A')).valueOrNull!;
    final l2 = (await vocabRepo.createList(name: 'B')).valueOrNull!;
    final past = _now.subtract(const Duration(days: 1));
    final future = DateTime.now().add(const Duration(days: 30));

    final dueA = await seedWord(l1.id, 'chat', '고양이');
    await seedProgress(dueA, state: 'review', nextReview: past);
    final dueB = await seedWord(l2.id, 'chien', '개');
    await seedProgress(dueB, state: 'learning', nextReview: past);
    final futureCard = await seedWord(l1.id, 'maison', '집');
    await seedProgress(futureCard, state: 'review', nextReview: future);
    await seedWord(l2.id, 'pain', '빵'); // never studied — no progress row
    final deleted = await seedWord(l1.id, 'lait', '우유');
    await seedProgress(deleted, state: 'review', nextReview: past);
    await db.conceptDao.softDeleteVariant(deleted);

    final result = await progressRepo.getAllDueCards(
        userId: _kUserId, direction: QuizDirection.frToKo);

    final ids = result.valueOrNull!.map((p) => p.variantId).toSet();
    expect(ids, {dueA, dueB});
  });

  test(
      'getInProgressCards: started cards across lists whether due or not; '
      'new-state and never-studied words are excluded', () async {
    final l1 = (await vocabRepo.createList(name: 'A')).valueOrNull!;
    final future = DateTime.now().add(const Duration(days: 30));

    final started = await seedWord(l1.id, 'chat', '고양이');
    await seedProgress(started, state: 'learning',
        nextReview: _now.subtract(const Duration(days: 1)));
    final scheduled = await seedWord(l1.id, 'maison', '집');
    await seedProgress(scheduled, state: 'review', nextReview: future);
    final newState = await seedWord(l1.id, 'pain', '빵');
    await seedProgress(newState, state: 'newCard', nextReview: null);
    await seedWord(l1.id, 'lait', '우유'); // never studied

    final result = await progressRepo.getInProgressCards(
        userId: _kUserId, direction: QuizDirection.frToKo);

    final ids = result.valueOrNull!.map((p) => p.variantId).toSet();
    expect(ids, {started, scheduled});
  });

  test('the use case routes each QuizSource to the right query', () async {
    final l1 = (await vocabRepo.createList(name: 'A')).valueOrNull!;
    final due = await seedWord(l1.id, 'chat', '고양이');
    await seedProgress(due, state: 'review',
        nextReview: _now.subtract(const Duration(days: 1)));
    final futureCard = await seedWord(l1.id, 'maison', '집');
    await seedProgress(futureCard, state: 'review',
        nextReview: DateTime.now().add(const Duration(days: 30)));

    final usecase = GetDueCardsUseCase(progressRepo);

    final allDue = await usecase.call(
        userId: _kUserId,
        source: QuizSource.allDue,
        direction: QuizDirection.frToKo);
    expect(allDue.valueOrNull!.map((p) => p.variantId), [due]);

    final inProgress = await usecase.call(
        userId: _kUserId,
        source: QuizSource.inProgress,
        direction: QuizDirection.frToKo);
    expect(inProgress.valueOrNull!.map((p) => p.variantId).toSet(),
        {due, futureCard});

    // list source still works and includes new cards (existing behaviour).
    final listCards = await usecase.call(
        userId: _kUserId,
        listId: l1.id,
        direction: QuizDirection.frToKo);
    expect(listCards.isSuccess, isTrue);
  });
}
