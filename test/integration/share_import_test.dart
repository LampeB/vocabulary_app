// ignore_for_file: invalid_use_of_internal_member
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/core/errors/app_exception.dart';
import 'package:vocab_kr/core/errors/failure.dart';
import 'package:vocab_kr/data/datasources/local/app_database.dart';
import 'package:vocab_kr/data/repositories/vocabulary_repository_impl.dart';
import 'package:vocab_kr/data/sync/push_sync.dart';
import '../helpers/fake_remote.dart';

const _kUserId = 'test-user-share';

/// Fake remote that returns a fixed shared-list payload for any token.
class _SharedListRemote extends FakeRemote {
  _SharedListRemote(this.payload);
  final Map<String, dynamic>? payload;
  final storedLists = <String, Map<String, dynamic>>{};
  final storedConcepts = <String, Map<String, dynamic>>{};
  final storedVariants = <String, Map<String, dynamic>>{};
  bool writesOffline = false;

  @override
  Future<Result<Map<String, dynamic>?>> fetchPublicListByToken(
          String token) async =>
      Success(payload);

  @override
  Future<Result<List<Map<String, dynamic>>>> fetchLists(String ownerId) async =>
      Success(storedLists.values
          .where((row) => row['owner_id'] == ownerId)
          .toList());

  @override
  Future<Result<List<Map<String, dynamic>>>> fetchConcepts(
          String listId) async =>
      Success([
        for (final row
            in storedConcepts.values.where((row) => row['list_id'] == listId))
          {
            ...row,
            'word_variants': storedVariants.values
                .where((variant) => variant['concept_id'] == row['id'])
                .toList(),
          },
      ]);

  Result<Map<String, dynamic>> _upsert(
      Map<String, Map<String, dynamic>> table, Map<String, dynamic> row,
      {required bool insertOnly}) {
    if (writesOffline) return const Failure(NetworkException('offline'));
    final id = row['id'] as String;
    if (!insertOnly || !table.containsKey(id)) table[id] = row;
    return Success(table[id]!);
  }

  @override
  Future<Result<Map<String, dynamic>>> upsertList(Map<String, dynamic> data,
          {bool insertOnly = false}) async =>
      _upsert(storedLists, data, insertOnly: insertOnly);

  @override
  Future<Result<Map<String, dynamic>>> upsertConcept(Map<String, dynamic> data,
          {bool insertOnly = false}) async =>
      _upsert(storedConcepts, data, insertOnly: insertOnly);

  @override
  Future<Result<Map<String, dynamic>>> upsertVariant(Map<String, dynamic> data,
          {bool insertOnly = false}) async =>
      _upsert(storedVariants, data, insertOnly: insertOnly);
}

Map<String, dynamic> _sharedPayload() => {
      'name': 'Shared Greetings',
      'description': 'from a friend',
      'concepts': [
        {
          'id': 'greeting',
          'category': null,
          'notes': null,
          'example_fr': null,
          'example_ko': null,
          'word_variants': [
            {
              'id': 'greeting-fr',
              'word': 'bonjour',
              'lang_code': 'fr',
              'is_primary': true,
              'position': 0
            },
            {
              'id': 'greeting-ko',
              'word': '안녕하세요',
              'lang_code': 'ko',
              'is_primary': true,
              'position': 0
            },
          ],
        },
      ],
    };

void main() {
  late AppDatabase db;

  Future<void> allowIndependentTestDatabases() async {
    final previous = driftRuntimeOptions.dontWarnAboutMultipleDatabases;
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    addTearDown(
        () => driftRuntimeOptions.dontWarnAboutMultipleDatabases = previous);
  }

  VocabularyRepositoryImpl repoWith(FakeRemote remote,
      {AppDatabase? device, String ownerId = _kUserId}) {
    final local = device ?? db;
    return VocabularyRepositoryImpl(
        local.vocabularyListDao, local.conceptDao, remote, ownerId, local);
  }

  PushSync pushWith(AppDatabase device, FakeRemote remote) => PushSync(
      device.vocabularyListDao,
      device.conceptDao,
      device.progressDao,
      device.reviewEventDao,
      remote,
      userId: _kUserId);

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  group('generateShareLink', () {
    test('creates a token and returns a vocabkr://import link', () async {
      final repo = repoWith(FakeRemote());
      final list = (await repo.importFromJson({
        'list': {'name': 'My List', 'concepts': []}
      }))
          .valueOrNull!;

      final result = await repo.generateShareLink(list.id);

      expect(result.isSuccess, isTrue);
      final link = result.valueOrNull!;
      expect(link, startsWith('vocabkr://import?token='));

      final token = Uri.parse(link).queryParameters['token']!;
      final byToken = await db.vocabularyListDao.getByShareToken(token);
      expect(byToken, isNotNull);
      expect(byToken!.id, list.id);
    });
  });

  group('importFromShareToken', () {
    test('unknown token → NotFoundException', () async {
      final repo = repoWith(_SharedListRemote(null));
      final result = await repo.importFromShareToken('nope');
      expect(result.isFailure, isTrue);
      expect(result.exceptionOrNull, isA<NotFoundException>());
    });

    test('valid token → the shared list + concepts are imported locally',
        () async {
      final repo = repoWith(_SharedListRemote(_sharedPayload()));

      final result = await repo.importFromShareToken('abc123');

      expect(result.isSuccess, isTrue);
      final list = result.valueOrNull!;
      expect(list.name, 'Shared Greetings');
      final concepts = await db.conceptDao.getConceptsByList(list.id);
      expect(concepts.length, 1);
      final variants =
          await db.conceptDao.getVariantsByConcept(concepts.first.id);
      expect(variants.map((v) => v.word), containsAll(['bonjour', '안녕하세요']));
    });

    test('re-importing the same token returns the existing list (dedup)',
        () async {
      final repo = repoWith(_SharedListRemote(_sharedPayload()));

      final first = (await repo.importFromShareToken('abc123')).valueOrNull!;
      expect(first.shareToken, isNull);
      expect(first.importedFromShareToken, 'abc123');
      final second = (await repo.importFromShareToken('abc123')).valueOrNull!;

      expect(second.id, first.id);
    });

    test('independent devices converge on one list and its source children',
        () async {
      await allowIndependentTestDatabases();
      final secondDevice = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(secondDevice.close);
      final payload = _sharedPayload();
      final remote = _SharedListRemote(payload);
      final firstRepo = repoWith(remote);
      final secondRepo = repoWith(remote, device: secondDevice);

      final first =
          (await firstRepo.importFromShareToken('shared')).valueOrNull!;
      // Map child identity to the source rows, even when their order changes.
      final sourceConcept =
          (payload['concepts'] as List).single as Map<String, dynamic>;
      sourceConcept['word_variants'] =
          (sourceConcept['word_variants'] as List).reversed.toList();
      final second =
          (await secondRepo.importFromShareToken('shared')).valueOrNull!;
      expect(first.id, second.id);
      final other = (await repoWith(remote, ownerId: 'other-account')
              .importFromShareToken('shared'))
          .valueOrNull!;
      expect(other.id, isNot(first.id));

      await pushWith(db, remote).pushAll();
      await pushWith(secondDevice, remote).pushAll();
      expect(remote.storedLists, hasLength(1));
      expect(remote.storedConcepts, hasLength(1));
      expect(remote.storedVariants, hasLength(2));
      await firstRepo.syncFromRemote();
      expect(await firstRepo.watchMyLists().first, hasLength(1));
      final concept = (await db.conceptDao.getConceptsByList(first.id)).single;
      expect(
          (await db.conceptDao.getVariantsByConcept(concept.id))
              .map((row) => row.word),
          unorderedEquals(['bonjour', '안녕하세요']));
    });

    test(
        'an unedited second import retried after restart preserves published edits',
        () async {
      await allowIndependentTestDatabases();
      final directory =
          await Directory.systemTemp.createTemp('ponderin-import-');
      addTearDown(() => directory.delete(recursive: true));
      final file =
          File('${directory.path}${Platform.pathSeparator}device.sqlite');
      var secondDevice = AppDatabase.forTesting(NativeDatabase(file));
      addTearDown(() => secondDevice.close());
      final remote = _SharedListRemote(_sharedPayload());
      final firstRepo = repoWith(remote);
      final secondRepo = repoWith(remote, device: secondDevice);

      final first = (await firstRepo.importFromShareToken('link')).valueOrNull!;
      final second =
          (await secondRepo.importFromShareToken('link')).valueOrNull!;
      expect(second.id, first.id);
      await pushWith(db, remote).pushAll();

      await firstRepo.updateList(first.copyWith(name: 'Edited title'));
      await firstRepo.generateShareLink(first.id);
      final concept = (await firstRepo.watchConcepts(first.id).first).single;
      await firstRepo.updateConcept(concept.copyWith(notes: 'Edited note'));
      final variants = (await firstRepo.getVariants(concept.id)).valueOrNull!;
      final variant = variants.firstWhere((row) => row.langCode == 'fr');
      await firstRepo.updateVariant(variant.copyWith(word: 'salutations'));
      expect(await pushWith(db, remote).pushAll(), 3);

      remote.writesOffline = true;
      expect(await pushWith(secondDevice, remote).pushAll(), 0);
      await secondDevice.close();
      secondDevice = AppDatabase.forTesting(NativeDatabase(file));
      remote.writesOffline = false;
      expect(await pushWith(secondDevice, remote).pushAll(), 4);

      expect(remote.storedLists[first.id]!['name'], 'Edited title');
      expect(remote.storedLists[first.id]!['visibility'], 'public');
      expect(remote.storedLists[first.id]!['share_token'], isNotEmpty);
      expect(remote.storedConcepts[concept.id]!['notes'], 'Edited note');
      expect(remote.storedVariants[variant.id]!['word'], 'salutations');
      await repoWith(remote, device: secondDevice).syncFromRemote();
      final restored =
          (await secondDevice.vocabularyListDao.getById(first.id))!;
      expect(restored.name, 'Edited title');
      expect(restored.isSynced, isTrue);
    });

    test('reimport can find an existing copy after restoring legacy duplicates',
        () async {
      final remote = _SharedListRemote(_sharedPayload());
      const date = '2026-11-01T10:00:00Z';
      for (final (id, name) in [
        ('legacy-b', 'Edited on device B'),
        ('legacy-a', 'Edited on device A')
      ]) {
        await remote.upsertList({
          'id': id,
          'owner_id': _kUserId,
          'name': name,
          'imported_from_share_token': 'legacy-token',
          'created_at': date,
          'updated_at': date,
        });
      }
      final repo = repoWith(remote);
      await repo.syncFromRemote();

      final found =
          (await repo.importFromShareToken('legacy-token')).valueOrNull!;
      expect(found.id, 'legacy-a');
      expect((await repo.watchMyLists().first).map((list) => list.name),
          unorderedEquals(['Edited on device A', 'Edited on device B']));
      expect(await db.vocabularyListDao.getUnsyncedLists(), isEmpty);
    });
  });
}
