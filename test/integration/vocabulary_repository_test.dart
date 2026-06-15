// ignore_for_file: invalid_use_of_internal_member

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/core/errors/failure.dart';
import 'package:vocab_kr/data/datasources/local/app_database.dart';
import 'package:vocab_kr/data/datasources/remote/vocabulary_remote_datasource.dart';
import 'package:vocab_kr/data/repositories/vocabulary_repository_impl.dart';
import 'package:vocab_kr/domain/entities/vocabulary_list.dart';

// ---------------------------------------------------------------------------
// Fake remote — all calls succeed with empty data (no real network needed).
// ---------------------------------------------------------------------------
class _FakeRemote implements VocabularyRemoteDataSource {
  @override
  Future<Result<List<Map<String, dynamic>>>> fetchLists(String ownerId) async =>
      const Success([]);

  @override
  Future<Result<Map<String, dynamic>>> upsertList(
          Map<String, dynamic> data) async =>
      Success(data);

  @override
  Future<Result<void>> deleteList(String id) async => const Success(null);

  @override
  Future<Result<List<Map<String, dynamic>>>> fetchConcepts(
          String listId) async =>
      const Success([]);

  @override
  Future<Result<Map<String, dynamic>>> upsertConcept(
          Map<String, dynamic> data) async =>
      Success(data);

  @override
  Future<Result<Map<String, dynamic>>> upsertVariant(
          Map<String, dynamic> data) async =>
      Success(data);

  @override
  Future<Result<List<Map<String, dynamic>>>> fetchProgress(
          String userId) async =>
      const Success([]);

  @override
  Future<Result<Map<String, dynamic>>> upsertProgress(
          Map<String, dynamic> data) async =>
      Success(data);

  @override
  Future<Result<Map<String, dynamic>?>> fetchPublicListByToken(
          String token) async =>
      const Success(null);
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
const _kUserId = 'test-user-abc123';

Map<String, dynamic> _makeJson({
  int conceptCount = 3,
  int frVariantsPerConcept = 1,
  int koVariantsPerConcept = 1,
  String? name,
}) =>
    {
      'version': 1,
      'list': {
        'name': name ?? 'Test List',
        'description': 'A test list',
        'concepts': List.generate(
          conceptCount,
          (i) => {
            'category': 'test',
            'notes': i.isEven ? 'note $i' : null,
            'exampleFr': 'French example $i',
            'exampleKo': 'Korean example $i',
            'variants': [
              ...List.generate(
                frVariantsPerConcept,
                (j) => {
                  'word': 'fr_${i}_$j',
                  'langCode': 'fr',
                  'registerTag': j == 0 ? 'neutral' : 'informal',
                  'isPrimary': j == 0,
                  'position': j,
                },
              ),
              ...List.generate(
                koVariantsPerConcept,
                (j) => {
                  'word': 'ko_${i}_$j',
                  'langCode': 'ko',
                  'registerTag': j == 0 ? 'formal' : 'informal',
                  'isPrimary': j == 0,
                  'position': j,
                },
              ),
            ],
          },
        ),
      },
    };

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------
void main() {
  late AppDatabase db;
  late VocabularyRepositoryImpl repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = VocabularyRepositoryImpl(
      db.vocabularyListDao,
      db.conceptDao,
      _FakeRemote(),
      _kUserId,
      db,
    );
  });

  tearDown(() => db.close());

  // ── importFromJson ────────────────────────────────────────────────────────

  group('importFromJson', () {
    test('returns Success with correct name and wordCount', () async {
      final result = await repo.importFromJson(_makeJson(conceptCount: 5));

      expect(result, isA<Success<VocabularyList>>());
      final list = (result as Success<VocabularyList>).value;
      expect(list.name, 'Test List');
      expect(list.wordCount, 5);
      expect(list.ownerId, _kUserId);
    });

    test('inserts all concepts into the local DB', () async {
      final result = await repo.importFromJson(_makeJson(conceptCount: 10));
      final listId = (result as Success<VocabularyList>).value.id;

      final concepts = await db.conceptDao.getConceptsByList(listId);
      expect(concepts.length, 10,
          reason: 'Expected 10 concepts in DB after import');
    });

    test('inserts variants for every concept', () async {
      const fr = 2;
      const ko = 3;
      final result = await repo.importFromJson(
        _makeJson(conceptCount: 4, frVariantsPerConcept: fr, koVariantsPerConcept: ko),
      );
      final listId = (result as Success<VocabularyList>).value.id;
      final concepts = await db.conceptDao.getConceptsByList(listId);

      for (final concept in concepts) {
        final variants = await db.conceptDao.getVariantsByConcept(concept.id);
        expect(variants.length, fr + ko,
            reason: 'Concept ${concept.id} should have ${fr + ko} variants');
      }
    });

    test('watchConcepts streams inserted concepts immediately', () async {
      final result = await repo.importFromJson(_makeJson(conceptCount: 7));
      final listId = (result as Success<VocabularyList>).value.id;

      final concepts = await repo.watchConcepts(listId).first;
      expect(concepts.length, 7);
    });

    test('list appears in watchMyLists after import', () async {
      await repo.importFromJson(_makeJson(name: 'My Unique List'));

      final lists = await repo.watchMyLists().first;
      expect(lists.any((l) => l.name == 'My Unique List'), true);
    });

    test('imported concepts are NOT soft-deleted (isDeleted=false)', () async {
      final result = await repo.importFromJson(_makeJson(conceptCount: 3));
      final listId = (result as Success<VocabularyList>).value.id;

      // watchByList filters is_deleted=false — should return all 3.
      final visibleConcepts = await db.conceptDao.getConceptsByList(listId);
      expect(visibleConcepts.length, 3);
    });

    test('stores optional metadata fields (category, notes, examples)', () async {
      final result = await repo.importFromJson(_makeJson(conceptCount: 2));
      final listId = (result as Success<VocabularyList>).value.id;
      final concepts = await db.conceptDao.getConceptsByList(listId);

      // concept 0 has even index so has notes
      final withNotes = concepts.firstWhere((c) => c.notes != null);
      expect(withNotes.category, 'test');
      expect(withNotes.exampleFr, contains('French example'));
    });

    test('returns Failure on missing "list" key', () async {
      final result = await repo.importFromJson({'not': 'valid'});
      expect(result, isA<Failure>());
    });

    test('returns Failure on completely empty map', () async {
      final result = await repo.importFromJson({});
      expect(result, isA<Failure>());
    });

    test('empty concepts array creates list with wordCount=0', () async {
      final result = await repo.importFromJson({
        'list': {'name': 'Empty', 'concepts': []},
      });
      expect(result.isSuccess, true);
      expect((result as Success<VocabularyList>).value.wordCount, 0);
    });

    test('two imports of the same JSON create two separate lists', () async {
      final json = _makeJson(conceptCount: 3, name: 'Dupe');
      await repo.importFromJson(json);
      await repo.importFromJson(json);

      final lists = await repo.watchMyLists().first;
      expect(lists.where((l) => l.name == 'Dupe').length, 2);
    });
  });

  // ── exportToJson ──────────────────────────────────────────────────────────

  group('exportToJson', () {
    test('returns Failure for unknown listId', () async {
      final result = await repo.exportToJson('no-such-id');
      expect(result, isA<Failure>());
    });

    test('exported JSON contains list name and correct concept count', () async {
      final importResult = await repo.importFromJson(_makeJson(conceptCount: 4));
      final listId = (importResult as Success<VocabularyList>).value.id;

      final exportResult = await repo.exportToJson(listId);
      expect(exportResult.isSuccess, true);

      final json = (exportResult as Success<Map<String, dynamic>>).value;
      final concepts = (json['list'] as Map)['concepts'] as List;
      expect(concepts.length, 4);
    });

    test('round-trip: export then re-import preserves concepts and variants',
        () async {
      final original = _makeJson(
        conceptCount: 3,
        frVariantsPerConcept: 2,
        koVariantsPerConcept: 1,
        name: 'Round-trip',
      );
      final importResult1 = await repo.importFromJson(original);
      final listId1 = (importResult1 as Success<VocabularyList>).value.id;

      final exportResult = await repo.exportToJson(listId1);
      final json = (exportResult as Success<Map<String, dynamic>>).value;

      final importResult2 = await repo.importFromJson(json);
      final listId2 = (importResult2 as Success<VocabularyList>).value.id;

      final concepts = await db.conceptDao.getConceptsByList(listId2);
      expect(concepts.length, 3);

      for (final c in concepts) {
        final variants = await db.conceptDao.getVariantsByConcept(c.id);
        expect(variants.length, 3,
            reason: '2 fr + 1 ko variants per concept');
      }
    });
  });

  // ── createConcept / deleteConc ────────────────────────────────────────────

  group('createConcept', () {
    test('inserted concept appears in watchConcepts', () async {
      final listResult = await repo.createList(name: 'Test', description: null);
      final listId = (listResult as Success<VocabularyList>).value.id;

      await repo.createConcept(listId: listId);
      final concepts = await repo.watchConcepts(listId).first;
      expect(concepts.length, 1);
    });
  });

  group('deleteConcept', () {
    test('soft-deleted concept disappears from watchConcepts', () async {
      final listResult = await repo.createList(name: 'Del', description: null);
      final listId = (listResult as Success<VocabularyList>).value.id;

      final cResult = await repo.createConcept(listId: listId);
      final conceptId = (cResult as Success).value.id;

      await repo.deleteConcept(conceptId);
      final concepts = await repo.watchConcepts(listId).first;
      expect(concepts.isEmpty, true);
    });
  });
}
