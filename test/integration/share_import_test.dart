// ignore_for_file: invalid_use_of_internal_member
import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/core/errors/app_exception.dart';
import 'package:vocab_kr/core/errors/failure.dart';
import 'package:vocab_kr/data/datasources/local/app_database.dart';
import 'package:vocab_kr/data/datasources/remote/vocabulary_remote_datasource.dart';
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
  int publicFetches = 0;
  Future<void> Function()? onImportedListResponse;

  @override
  Future<Result<Map<String, dynamic>?>> fetchPublicListByToken(
    String token,
  ) async {
    publicFetches++;
    return Success(payload);
  }

  @override
  Future<Result<List<Map<String, dynamic>>>> fetchLists(String ownerId) async =>
      Success(
        storedLists.values.where((row) => row['owner_id'] == ownerId).toList(),
      );

  @override
  Future<Result<List<Map<String, dynamic>>>> fetchConcepts(
    String listId,
  ) async => Success([
    for (final row in storedConcepts.values.where(
      (row) => row['list_id'] == listId,
    ))
      {
        ...row,
        'word_variants': storedVariants.values
            .where((variant) => variant['concept_id'] == row['id'])
            .toList(),
      },
  ]);

  Result<Map<String, dynamic>> _upsert(
    Map<String, Map<String, dynamic>> table,
    Map<String, dynamic> row, {
    required bool insertOnly,
    Map<String, dynamic>? changes,
    Map<String, dynamic>? deletedList,
    Map<String, dynamic>? deletedConcept,
  }) {
    if (writesOffline) return const Failure(NetworkException('offline'));
    final id = row['id'] as String;
    final existing = table[id];
    if (deletedList != null || deletedConcept != null) {
      table[id] = {...existing ?? row, 'is_deleted': true};
    } else if (existing?['is_deleted'] == true) {
      return Success(existing!);
    } else if (!insertOnly || existing == null) {
      table[id] = row;
    } else if (changes != null && existing['is_deleted'] != true) {
      table[id] = {...existing, ...changes};
    }
    return Success({
      ...table[id]!,
      VocabularyRemoteDataSource.deletedListKey: ?deletedList,
      VocabularyRemoteDataSource.deletedConceptKey: ?deletedConcept,
    });
  }

  @override
  Future<Result<Map<String, dynamic>>> upsertList(
    Map<String, dynamic> data, {
    bool insertOnly = false,
    Map<String, dynamic>? changes,
  }) async {
    final response = _upsert(
      storedLists,
      data,
      insertOnly: insertOnly,
      changes: changes,
    );
    if (insertOnly) await onImportedListResponse?.call();
    return response;
  }

  @override
  Future<Result<Map<String, dynamic>>> upsertConcept(
    Map<String, dynamic> data, {
    bool insertOnly = false,
    Map<String, dynamic>? changes,
  }) async {
    final list = storedLists[data['list_id']];
    return _upsert(
      storedConcepts,
      data,
      insertOnly: insertOnly,
      changes: changes,
      deletedList: list?['is_deleted'] == true ? list : null,
    );
  }

  @override
  Future<Result<Map<String, dynamic>>> upsertVariant(
    Map<String, dynamic> data, {
    bool insertOnly = false,
    Map<String, dynamic>? changes,
  }) async {
    final concept = storedConcepts[data['concept_id']];
    final list = storedLists[concept?['list_id']];
    return _upsert(
      storedVariants,
      data,
      insertOnly: insertOnly,
      changes: changes,
      deletedList: list?['is_deleted'] == true ? list : null,
      deletedConcept: concept?['is_deleted'] == true ? concept : null,
    );
  }
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
          'context_tags': ['greeting', 'formal'],
          'example': 'Bonjour, madame.',
          'is_primary': true,
          'position': 0,
        },
        {
          'id': 'greeting-ko',
          'word': '안녕하세요',
          'lang_code': 'ko',
          'is_primary': true,
          'position': 0,
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
      () => driftRuntimeOptions.dontWarnAboutMultipleDatabases = previous,
    );
  }

  VocabularyRepositoryImpl repoWith(
    FakeRemote remote, {
    AppDatabase? device,
    String ownerId = _kUserId,
  }) {
    final local = device ?? db;
    return VocabularyRepositoryImpl(
      local.vocabularyListDao,
      local.conceptDao,
      remote,
      ownerId,
      local,
    );
  }

  PushSync pushWith(AppDatabase device, FakeRemote remote) => PushSync(
    device.vocabularyListDao,
    device.conceptDao,
    device.progressDao,
    device.reviewEventDao,
    remote,
    userId: _kUserId,
  );

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  group('generateShareLink', () {
    test('creates a token and returns a vocabkr://import link', () async {
      final repo = repoWith(FakeRemote());
      final list = (await repo.importFromJson({
        'list': {'name': 'My List', 'concepts': []},
      })).valueOrNull!;

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
    test(
      'an anonymous repository never persists new lists or requests an import',
      () async {
        final remote = _SharedListRemote(_sharedPayload());
        final signedOut = repoWith(remote, ownerId: '');
        for (final result in [
          await signedOut.createList(name: 'No account'),
          await signedOut.importFromJson({
            'list': {'name': 'JSON'},
          }),
          await signedOut.importFromShareToken('link'),
        ]) {
          expect(result.exceptionOrNull, isA<AuthException>());
        }
        expect(remote.publicFetches, 0);
        expect(await db.vocabularyListDao.getUnsyncedLists(), isEmpty);
      },
    );
    test('unknown token → NotFoundException', () async {
      final repo = repoWith(_SharedListRemote(null));
      final result = await repo.importFromShareToken('nope');
      expect(result.isFailure, isTrue);
      expect(result.exceptionOrNull, isA<NotFoundException>());
    });

    test(
      'valid token → the shared list + concepts are imported locally',
      () async {
        final repo = repoWith(_SharedListRemote(_sharedPayload()));

        final result = await repo.importFromShareToken('abc123');

        expect(result.isSuccess, isTrue);
        final list = result.valueOrNull!;
        expect(list.name, 'Shared Greetings');
        final concepts = await db.conceptDao.getConceptsByList(list.id);
        expect(concepts.length, 1);
        final variants = await db.conceptDao.getVariantsByConcept(
          concepts.first.id,
        );
        expect(variants.map((v) => v.word), containsAll(['bonjour', '안녕하세요']));
        final french = (await repo.getVariants(
          concepts.first.id,
        )).valueOrNull!.firstWhere((variant) => variant.langCode == 'fr');
        expect(french.contextTags, ['greeting', 'formal']);
        expect(french.example, 'Bonjour, madame.');
      },
    );

    test(
      're-importing the same token returns the existing list (dedup)',
      () async {
        final repo = repoWith(_SharedListRemote(_sharedPayload()));

        final first = (await repo.importFromShareToken('abc123')).valueOrNull!;
        expect(first.shareToken, isNull);
        expect(first.importedFromShareToken, 'abc123');
        final second = (await repo.importFromShareToken('abc123')).valueOrNull!;

        expect(second.id, first.id);
      },
    );

    test(
      'independent devices converge on one list and its source children',
      () async {
        await allowIndependentTestDatabases();
        final secondDevice = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(secondDevice.close);
        final payload = _sharedPayload();
        final remote = _SharedListRemote(payload);
        final firstRepo = repoWith(remote);
        final secondRepo = repoWith(remote, device: secondDevice);

        final first = (await firstRepo.importFromShareToken(
          'shared',
        )).valueOrNull!;
        // Map child identity to the source rows, even when their order changes.
        final sourceConcept =
            (payload['concepts'] as List).single as Map<String, dynamic>;
        sourceConcept['word_variants'] =
            (sourceConcept['word_variants'] as List).reversed.toList();
        final second = (await secondRepo.importFromShareToken(
          'shared',
        )).valueOrNull!;
        expect(first.id, second.id);
        final other = (await repoWith(
          remote,
          ownerId: 'other-account',
        ).importFromShareToken('shared')).valueOrNull!;
        expect(other.id, isNot(first.id));

        await pushWith(db, remote).pushAll();
        await pushWith(secondDevice, remote).pushAll();
        expect(remote.storedLists, hasLength(1));
        expect(remote.storedConcepts, hasLength(1));
        expect(remote.storedVariants, hasLength(2));
        await firstRepo.syncFromRemote();
        expect(await firstRepo.watchMyLists().first, hasLength(1));
        final concept = (await db.conceptDao.getConceptsByList(
          first.id,
        )).single;
        expect(
          (await db.conceptDao.getVariantsByConcept(
            concept.id,
          )).map((row) => row.word),
          unorderedEquals(['bonjour', '안녕하세요']),
        );
      },
    );

    test(
      'an unedited second import retried after restart preserves published edits',
      () async {
        await allowIndependentTestDatabases();
        final directory = await Directory.systemTemp.createTemp(
          'ponderin-import-',
        );
        addTearDown(() => directory.delete(recursive: true));
        final file = File(
          '${directory.path}${Platform.pathSeparator}device.sqlite',
        );
        var secondDevice = AppDatabase.forTesting(NativeDatabase(file));
        addTearDown(() => secondDevice.close());
        final remote = _SharedListRemote(_sharedPayload());
        final firstRepo = repoWith(remote);
        final secondRepo = repoWith(remote, device: secondDevice);

        final first = (await firstRepo.importFromShareToken(
          'link',
        )).valueOrNull!;
        final second = (await secondRepo.importFromShareToken(
          'link',
        )).valueOrNull!;
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
        final restored = (await secondDevice.vocabularyListDao.getById(
          first.id,
        ))!;
        expect(restored.name, 'Edited title');
        expect(restored.isSynced, isTrue);
        expect(restored.visibility, 'public');
        expect(
          (await secondDevice.conceptDao.getById(concept.id))!.notes,
          'Edited note',
        );
        expect(
          (await secondDevice.conceptDao.getVariantById(variant.id))!.word,
          'salutations',
        );

        final restarted = repoWith(remote, device: secondDevice);
        await restarted.renameList(first.id, 'Renamed after ack');
        await pushWith(secondDevice, remote).pushAll();
        expect(remote.storedLists[first.id]!['name'], 'Renamed after ack');
        expect(remote.storedLists[first.id]!['visibility'], 'public');
        expect(
          remote.storedLists[first.id]!['share_token'],
          restored.shareToken,
        );
      },
    );

    test(
      'a duplicate import rebases edits made while its response was in flight',
      () async {
        await allowIndependentTestDatabases();
        final device = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(device.close);
        final remote = _SharedListRemote(_sharedPayload());
        final author = repoWith(remote);
        final copy = repoWith(remote, device: device);
        final first = (await author.importFromShareToken('link')).valueOrNull!;
        final second = (await copy.importFromShareToken('link')).valueOrNull!;
        await author.generateShareLink(first.id);
        await pushWith(db, remote).pushAll();

        final requested = Completer<void>();
        final reply = Completer<void>();
        remote.onImportedListResponse = () async {
          remote.onImportedListResponse = null;
          requested.complete();
          await reply.future;
        };
        final syncing = pushWith(device, remote).pushAll();
        try {
          await requested.future;
          await copy.updateList(second.copyWith(name: 'Title on B'));
          // A changed another field after the response for B was captured.
          await remote.upsertList({
            ...remote.storedLists[first.id]!,
            'description': 'Latest on A',
          });
        } finally {
          reply.complete();
          await syncing;
        }
        final local = (await device.vocabularyListDao.getById(second.id))!;
        expect(local.isSynced, isTrue);
        expect(local.name, 'Title on B');
        expect(local.description, 'Latest on A');
        expect(local.visibility, 'public');
        expect(remote.storedLists[first.id]!['name'], 'Title on B');
        expect(remote.storedLists[first.id]!['description'], 'Latest on A');
        expect(remote.storedLists[first.id]!['share_token'], local.shareToken);
      },
    );

    test(
      'acknowledging a duplicate tombstone removes its local subtree immediately',
      () async {
        await allowIndependentTestDatabases();
        final device = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(device.close);
        final remote = _SharedListRemote(_sharedPayload());
        final author = repoWith(remote);
        final copy = repoWith(remote, device: device);
        final first = (await author.importFromShareToken('link')).valueOrNull!;
        final second = (await copy.importFromShareToken('link')).valueOrNull!;
        final concept = (await device.conceptDao.getConceptsByList(
          second.id,
        )).single;
        final variant = (await device.conceptDao.getVariantsByConcept(
          concept.id,
        )).first;
        final now = DateTime.now();
        await device.progressDao.upsert(
          VariantProgressTableCompanion.insert(
            id: 'card',
            userId: _kUserId,
            variantId: variant.id,
            direction: 'fr>ko',
            createdAt: now,
            updatedAt: now,
          ),
        );
        await pushWith(db, remote).pushAll();
        await author.deleteList(first.id);
        await pushWith(db, remote).pushAll();

        await pushWith(device, remote).pushAll();

        expect(await copy.watchMyLists().first, isEmpty);
        expect(
          (await device.conceptDao.getById(concept.id))!.isDeleted,
          isTrue,
        );
        expect(
          (await device.conceptDao.getVariantById(variant.id))!.isDeleted,
          isTrue,
        );
        expect(await device.progressDao.getById('card'), isNull);
        expect(
          await device.vocabularyListDao.getPendingListIds(ownerId: _kUserId),
          isEmpty,
        );
        expect(remote.storedLists[first.id]!['is_deleted'], isTrue);
        expect(
          (await copy.renameList(second.id, 'Must stay deleted')).isFailure,
          isTrue,
        );
        expect(await pushWith(device, remote).pushAll(), 0);
      },
    );

    test(
      'reimport can find an existing copy after restoring legacy duplicates',
      () async {
        final remote = _SharedListRemote(_sharedPayload());
        const date = '2026-11-01T10:00:00Z';
        for (final (id, name) in [
          ('legacy-b', 'Edited on device B'),
          ('legacy-a', 'Edited on device A'),
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

        final found = (await repo.importFromShareToken(
          'legacy-token',
        )).valueOrNull!;
        expect(found.id, 'legacy-a');
        expect(
          (await repo.watchMyLists().first).map((list) => list.name),
          unorderedEquals(['Edited on device A', 'Edited on device B']),
        );
        expect(await db.vocabularyListDao.getUnsyncedLists(), isEmpty);
      },
    );
  });

  for (final target in [
    'list',
    'concept',
    'variant',
    'variant under deleted list',
  ]) {
    test('two synced devices cannot revive a deleted $target', () async {
      await allowIndependentTestDatabases();
      final device = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(device.close);
      final remote = _SharedListRemote(null);
      final author = repoWith(remote);
      final copy = repoWith(remote, device: device);
      final list = (await author.createList(name: 'Original')).valueOrNull!;
      final concept = (await author.addConceptWithVariants(
        listId: list.id,
        wordA: 'old',
        wordB: '오래',
      )).valueOrNull!;
      await pushWith(db, remote).pushAll();
      await copy.syncFromRemote();
      expect(
        await device.vocabularyListDao.getPendingListIds(ownerId: _kUserId),
        isEmpty,
      );
      final cachedConcept = (await copy.watchConcepts(list.id).first).single;
      final cachedVariant = (await copy.getVariants(
        concept.id,
      )).valueOrNull!.firstWhere((row) => row.langCode == 'fr');
      final now = DateTime.now();
      await device.progressDao.upsert(
        VariantProgressTableCompanion.insert(
          id: 'saved-card',
          userId: _kUserId,
          variantId: cachedVariant.id,
          direction: 'fr>ko',
          createdAt: now,
          updatedAt: now,
        ),
      );

      final listDeleted = target.startsWith('list') || target.endsWith('list');
      if (listDeleted) {
        await author.deleteList(list.id);
      } else if (target == 'concept') {
        await author.deleteConcept(concept.id);
      } else {
        await author.deleteVariant(cachedVariant.id);
      }
      await pushWith(db, remote).pushAll();

      if (target == 'list') {
        expect(
          (await copy.renameList(list.id, 'Stale rename')).isSuccess,
          isTrue,
        );
      } else if (target == 'concept') {
        expect(
          (await copy.updateConcept(
            cachedConcept.copyWith(notes: 'Stale note'),
          )).isSuccess,
          isTrue,
        );
      } else {
        expect(
          (await copy.updateVariant(
            cachedVariant.copyWith(word: 'Stale word'),
          )).isSuccess,
          isTrue,
        );
      }
      await pushWith(device, remote).pushAll();

      final localList = (await device.vocabularyListDao.getById(list.id))!;
      final localConcept = (await device.conceptDao.getById(concept.id))!;
      final localVariant = (await device.conceptDao.getVariantById(
        cachedVariant.id,
      ))!;
      expect(localList.isDeleted, listDeleted);
      expect(localConcept.isDeleted, listDeleted || target == 'concept');
      if (target == 'concept') expect(localList.wordCount, 0);
      expect(localVariant.isDeleted, isTrue);
      expect(await device.progressDao.getById('saved-card'), isNull);
      expect(
        await device.vocabularyListDao.getPendingListIds(ownerId: _kUserId),
        isEmpty,
      );
      expect(remote.storedLists[list.id]!['name'], 'Original');
      expect(remote.storedConcepts[concept.id]!['notes'], isNull);
      expect(remote.storedVariants[cachedVariant.id]!['word'], 'old');
    });
  }
}
