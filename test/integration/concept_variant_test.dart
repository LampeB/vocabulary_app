// ignore_for_file: invalid_use_of_internal_member

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/core/errors/failure.dart';
import 'package:vocab_kr/data/datasources/local/app_database.dart';
import 'package:vocab_kr/data/repositories/vocabulary_repository_impl.dart';
import 'package:vocab_kr/domain/entities/concept.dart';
import 'package:vocab_kr/domain/entities/vocabulary_list.dart';

import '../helpers/fake_remote.dart';

const _kUserId = 'test-user-abc123';

void main() {
  late AppDatabase db;
  late VocabularyRepositoryImpl repo;
  late VocabularyList list;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = VocabularyRepositoryImpl(
      db.vocabularyListDao,
      db.conceptDao,
      FakeRemote(),
      _kUserId,
      db,
    );
    list = ((await repo.createList(name: 'Test List', description: null))
            as Success<VocabularyList>)
        .value;
  });

  tearDown(() => db.close());

  // ── addConceptWithVariants ────────────────────────────────────────────────

  group('addConceptWithVariants', () {
    test('concept and both variants are inserted atomically', () async {
      final result = await repo.addConceptWithVariants(
        listId: list.id,
        frWord: 'Bonjour',
        koWord: '안녕하세요',
      );
      expect(result.isSuccess, isTrue);
      final conceptId = (result as Success<Concept>).value.id;
      final variants = await db.conceptDao.getVariantsByConcept(conceptId);
      expect(variants.length, 2);
    });

    test('wordCount on the list increments to 1', () async {
      await repo.addConceptWithVariants(
          listId: list.id, frWord: 'Bonjour', koWord: '안녕하세요');
      final lists = await repo.watchMyLists().first;
      expect(lists.first.wordCount, 1);
    });

    test('wordCount increments correctly for multiple adds', () async {
      await repo.addConceptWithVariants(
          listId: list.id, frWord: 'Bonjour', koWord: '안녕하세요');
      await repo.addConceptWithVariants(
          listId: list.id, frWord: 'Merci', koWord: '감사합니다');
      await repo.addConceptWithVariants(
          listId: list.id, frWord: 'Au revoir', koWord: '안녕히 가세요');
      final lists = await repo.watchMyLists().first;
      expect(lists.first.wordCount, 3);
    });

    test('fr variant has langCode=fr and isPrimary=true', () async {
      final result = await repo.addConceptWithVariants(
          listId: list.id, frWord: 'Bonjour', koWord: '안녕하세요');
      final conceptId = (result as Success<Concept>).value.id;
      final variants = await db.conceptDao.getVariantsByConcept(conceptId);
      final fr = variants.firstWhere((v) => v.word == 'Bonjour');
      expect(fr.langCode, 'fr');
      expect(fr.isPrimary, isTrue);
    });

    test('ko variant has langCode=ko and isPrimary=true', () async {
      final result = await repo.addConceptWithVariants(
          listId: list.id, frWord: 'Bonjour', koWord: '안녕하세요');
      final conceptId = (result as Success<Concept>).value.id;
      final variants = await db.conceptDao.getVariantsByConcept(conceptId);
      final ko = variants.firstWhere((v) => v.word == '안녕하세요');
      expect(ko.langCode, 'ko');
      expect(ko.isPrimary, isTrue);
    });
  });

  // ── updateConcept ─────────────────────────────────────────────────────────

  group('updateConcept', () {
    late Concept concept;

    setUp(() async {
      concept = ((await repo.createConcept(listId: list.id))
              as Success<Concept>)
          .value;
    });

    test('updated notes are visible in watchConcepts', () async {
      await repo.updateConcept(concept.copyWith(notes: 'a helpful note'));
      final concepts = await repo.watchConcepts(list.id).first;
      expect(concepts.first.notes, 'a helpful note');
    });

    test('updated category is visible in watchConcepts', () async {
      await repo.updateConcept(concept.copyWith(category: 'greetings'));
      final concepts = await repo.watchConcepts(list.id).first;
      expect(concepts.first.category, 'greetings');
    });

    test('updatedAt changes after update', () async {
      // Wait >1s: SQLite stores DateTime at second precision, so we need to
      // cross a second boundary to see a change in the DB-read value.
      await Future<void>.delayed(const Duration(seconds: 1, milliseconds: 100));
      await repo.updateConcept(concept.copyWith(notes: 'changed'));
      final concepts = await repo.watchConcepts(list.id).first;
      expect(concepts.first.updatedAt.isAfter(concept.updatedAt), isTrue);
    });
  });

  // ── deleteConcept ─────────────────────────────────────────────────────────

  group('deleteConcept', () {
    late Concept concept;

    setUp(() async {
      concept = ((await repo.addConceptWithVariants(
        listId: list.id,
        frWord: 'Bonjour',
        koWord: '안녕하세요',
      )) as Success<Concept>)
          .value;
    });

    test('concept disappears from watchConcepts after deletion', () async {
      await repo.deleteConcept(concept.id);
      final concepts = await repo.watchConcepts(list.id).first;
      expect(concepts.where((c) => c.id == concept.id), isEmpty);
    });

    test('wordCount decrements after deletion', () async {
      await repo.deleteConcept(concept.id);
      final lists = await repo.watchMyLists().first;
      expect(lists.first.wordCount, 0);
    });

    test('variants are NOT cascade-deleted (remain in DB with isDeleted=false)', () async {
      final variantsBefore =
          await db.conceptDao.getVariantsByConcept(concept.id);
      expect(variantsBefore.length, 2);

      await repo.deleteConcept(concept.id);

      // getVariantsByConcept filters isDeleted=false on variants.
      // Since we only soft-deleted the CONCEPT (not the variants), they
      // should still appear here.
      final variantsAfter =
          await db.conceptDao.getVariantsByConcept(concept.id);
      expect(variantsAfter.length, 2,
          reason: 'Soft-delete on concept must not cascade to variants');
    });
  });

  // ── variant CRUD ──────────────────────────────────────────────────────────

  group('variant CRUD', () {
    late Concept concept;

    setUp(() async {
      concept = ((await repo.createConcept(listId: list.id))
              as Success<Concept>)
          .value;
    });

    test('createVariant appears in getVariantsByConcept', () async {
      await repo.createVariant(
        conceptId: concept.id,
        word: 'Salut',
        langCode: 'fr',
        registerTag: 'informal',
      );
      final variants = await db.conceptDao.getVariantsByConcept(concept.id);
      expect(variants.length, 1);
      expect(variants.first.word, 'Salut');
    });

    test('createVariant preserves langCode and registerTag', () async {
      await repo.createVariant(
        conceptId: concept.id,
        word: 'Salut',
        langCode: 'fr',
        registerTag: 'informal',
      );
      final variants = await db.conceptDao.getVariantsByConcept(concept.id);
      expect(variants.first.langCode, 'fr');
      expect(variants.first.registerTag, 'informal');
    });

    test('updateVariant: updated word is visible', () async {
      final createResult = await repo.createVariant(
        conceptId: concept.id,
        word: 'Salut',
        langCode: 'fr',
      );
      final variant = (createResult as Success).value;
      await repo.updateVariant(variant.copyWith(word: 'Coucou'));
      final variants = await db.conceptDao.getVariantsByConcept(concept.id);
      expect(variants.first.word, 'Coucou');
    });

    test('updateVariant sets isSynced=false', () async {
      final createResult = await repo.createVariant(
        conceptId: concept.id,
        word: 'Salut',
        langCode: 'fr',
      );
      final variant = (createResult as Success).value;
      await repo.updateVariant(variant.copyWith(word: 'Coucou'));
      final row = await db.conceptDao.getVariantById(variant.id);
      expect(row!.isSynced, isFalse);
    });

    test('deleteVariant disappears from getVariantsByConcept', () async {
      final createResult = await repo.createVariant(
        conceptId: concept.id,
        word: 'Salut',
        langCode: 'fr',
      );
      final variant = (createResult as Success).value;
      await repo.deleteVariant(variant.id);
      final variants = await db.conceptDao.getVariantsByConcept(concept.id);
      expect(variants.where((v) => v.id == variant.id), isEmpty);
    });

    test('deleteVariant: raw DB row has isDeleted=true', () async {
      final createResult = await repo.createVariant(
        conceptId: concept.id,
        word: 'Salut',
        langCode: 'fr',
      );
      final variant = (createResult as Success).value;
      await repo.deleteVariant(variant.id);
      final row = await db.conceptDao.getVariantById(variant.id);
      expect(row, isNotNull);
      expect(row!.isDeleted, isTrue);
    });
  });
}
