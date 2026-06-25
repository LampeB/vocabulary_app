// ignore_for_file: invalid_use_of_internal_member

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/core/errors/failure.dart';
import 'package:vocab_kr/data/datasources/local/app_database.dart';
import 'package:vocab_kr/data/repositories/vocabulary_repository_impl.dart';
import 'package:vocab_kr/domain/entities/vocabulary_list.dart';

import '../helpers/fake_remote.dart';

const _kUserId = 'test-user-abc123';

void main() {
  late AppDatabase db;
  late VocabularyRepositoryImpl repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = VocabularyRepositoryImpl(
      db.vocabularyListDao,
      db.conceptDao,
      FakeRemote(),
      _kUserId,
      db,
    );
  });

  tearDown(() => db.close());

  // ── createList ────────────────────────────────────────────────────────────

  group('createList', () {
    test('list appears in watchMyLists with correct name and ownerId', () async {
      await repo.createList(name: 'My List', description: null);
      final lists = await repo.watchMyLists().first;
      expect(lists.length, 1);
      expect(lists.first.name, 'My List');
      expect(lists.first.ownerId, _kUserId);
    });

    test('wordCount starts at 0', () async {
      await repo.createList(name: 'Empty', description: null);
      final lists = await repo.watchMyLists().first;
      expect(lists.first.wordCount, 0);
    });

    test('two lists get distinct IDs', () async {
      final r1 = await repo.createList(name: 'A', description: null);
      final r2 = await repo.createList(name: 'B', description: null);
      final id1 = (r1 as Success<VocabularyList>).value.id;
      final id2 = (r2 as Success<VocabularyList>).value.id;
      expect(id1, isNot(id2));
    });

    test('createdAt and updatedAt are set', () async {
      final result = await repo.createList(name: 'Timed', description: null);
      final list = (result as Success<VocabularyList>).value;
      expect(list.createdAt, isNotNull);
      expect(list.updatedAt, isNotNull);
    });
  });

  // ── updateList ────────────────────────────────────────────────────────────

  group('updateList', () {
    late VocabularyList created;

    setUp(() async {
      created = ((await repo.createList(name: 'Original', description: null))
              as Success<VocabularyList>)
          .value;
    });

    test('updated name is visible in watchMyLists', () async {
      await repo.updateList(created.copyWith(name: 'Renamed'));
      final lists = await repo.watchMyLists().first;
      expect(lists.first.name, 'Renamed');
    });

    test('updatedAt changes after update', () async {
      // Wait >1s: SQLite stores DateTime at second precision, so we need to
      // cross a second boundary to see a change in the DB-read value.
      await Future<void>.delayed(const Duration(seconds: 1, milliseconds: 100));
      await repo.updateList(created.copyWith(name: 'Renamed'));
      final lists = await repo.watchMyLists().first;
      expect(lists.first.updatedAt.isAfter(created.updatedAt), isTrue);
    });

    test('isSynced is set to false after update', () async {
      await repo.updateList(created.copyWith(name: 'Renamed'));
      final row = await db.vocabularyListDao.getById(created.id);
      expect(row!.isSynced, isFalse);
    });

    test('original createdAt is preserved', () async {
      await repo.updateList(created.copyWith(name: 'Renamed'));
      final lists = await repo.watchMyLists().first;
      // SQLite stores DateTime at second precision; compare at that level.
      expect(
        lists.first.createdAt.millisecondsSinceEpoch ~/ 1000,
        equals(created.createdAt.millisecondsSinceEpoch ~/ 1000),
      );
    });
  });

  // ── deleteList ────────────────────────────────────────────────────────────

  group('deleteList', () {
    late VocabularyList created;

    setUp(() async {
      created = ((await repo.createList(name: 'ToDelete', description: null))
              as Success<VocabularyList>)
          .value;
    });

    test('list disappears from watchMyLists after soft-delete', () async {
      await repo.deleteList(created.id);
      final lists = await repo.watchMyLists().first;
      expect(lists.where((l) => l.id == created.id), isEmpty);
    });

    test('raw DB row still exists with isDeleted=true', () async {
      await repo.deleteList(created.id);
      final row = await db.vocabularyListDao.getById(created.id);
      expect(row, isNotNull);
      expect(row!.isDeleted, isTrue);
    });

    test('concepts belonging to the list are NOT cascade-deleted', () async {
      await repo.createConcept(listId: created.id);
      await repo.createConcept(listId: created.id);
      await repo.deleteList(created.id);
      final concepts = await db.conceptDao.getConceptsByList(created.id);
      expect(concepts.length, 2,
          reason: 'Soft-delete on list must not delete child concepts');
    });
  });

  // ── watchMyLists ordering ─────────────────────────────────────────────────

  group('watchMyLists ordering', () {
    test('most recently updated list appears first (updatedAt DESC)', () async {
      final r1 =
          ((await repo.createList(name: 'First', description: null))
                  as Success<VocabularyList>)
              .value;
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await repo.createList(name: 'Second', description: null);

      // Touch the older list so it becomes the most recently updated.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await repo.updateList(r1.copyWith(name: 'First (updated)'));

      final lists = await repo.watchMyLists().first;
      expect(lists.first.name, 'First (updated)');
    });
  });
}
