// ignore_for_file: invalid_use_of_internal_member
import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/core/errors/app_exception.dart';
import 'package:vocab_kr/core/errors/failure.dart';
import 'package:vocab_kr/data/datasources/local/app_database.dart';
import 'package:vocab_kr/data/repositories/vocabulary_repository_impl.dart';
import 'package:vocab_kr/data/sync/push_sync.dart';
import 'package:vocab_kr/domain/entities/app_user.dart';
import 'package:vocab_kr/presentation/providers/auth/auth_provider.dart';
import 'package:vocab_kr/presentation/providers/lists/vocabulary_provider.dart';
import '../helpers/fake_remote.dart';

/// Outbound sync: the isSynced flags are the queue. Rows written while the
/// backend is down get pushed by the next drain, marked synced, and never
/// pushed again; per-row failures stay queued for the next drain.

/// Records every push; can fail everything or a specific table.
class _RecordingRemote extends FakeRemote {
  Map<String, dynamic>? publicList;
  bool failAll = false;
  bool failConcepts = false;
  final pushedLists = <Map<String, dynamic>>[];
  final pushedConcepts = <Map<String, dynamic>>[];
  final pushedVariants = <Map<String, dynamic>>[];
  final pushedProgress = <Map<String, dynamic>>[];
  Future<void> Function(Map<String, dynamic>)? onList;
  Future<void> Function(String)? onAudio;

  @override
  Future<void> provisionAudio(String variantId) async {
    await onAudio?.call(variantId);
  }

  @override
  Future<Result<Map<String, dynamic>?>> fetchPublicListByToken(
          String token) async =>
      Success(publicList);

  Result<Map<String, dynamic>> _record(
      List<Map<String, dynamic>> sink, Map<String, dynamic> data,
      {bool fail = false}) {
    if (failAll || fail) return const Failure(NetworkException('down'));
    sink.add(data);
    return Success(data);
  }

  @override
  Future<Result<Map<String, dynamic>>> upsertList(Map<String, dynamic> data,
      {bool insertOnly = false}) async {
    await onList?.call(data);
    return _record(pushedLists, data);
  }

  @override
  Future<Result<Map<String, dynamic>>> upsertConcept(Map<String, dynamic> data,
          {bool insertOnly = false}) async =>
      _record(pushedConcepts, data, fail: failConcepts);
  @override
  Future<Result<Map<String, dynamic>>> upsertVariant(Map<String, dynamic> data,
          {bool insertOnly = false}) async =>
      _record(pushedVariants, data);
  @override
  Future<Result<Map<String, dynamic>>> upsertProgress(
          Map<String, dynamic> data) async =>
      _record(pushedProgress, data);
}

void main() {
  late AppDatabase db;
  late _RecordingRemote remote;
  late VocabularyRepositoryImpl repo;
  late PushSync sync;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    remote = _RecordingRemote();
    repo = VocabularyRepositoryImpl(
        db.vocabularyListDao, db.conceptDao, remote, 'u', db);
    sync = PushSync(db.vocabularyListDao, db.conceptDao, db.progressDao,
        db.reviewEventDao, remote);
  });
  tearDown(() => db.close());

  test('profile data keeps the writer but an account change replaces it', () {
    final user = AppUser(
      id: 'u',
      email: 'test@example.com',
      username: 'test',
      createdAt: DateTime.utc(2026),
    );
    final current = StateProvider<AppUser?>((_) => user);
    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      vocabularyRemoteProvider.overrideWithValue(remote),
      currentUserProvider.overrideWith((ref) => ref.watch(current)),
    ]);
    addTearDown(container.dispose);
    final writer = container.read(pushSyncProvider);
    final repository = container.read(vocabularyRepositoryProvider);

    container.read(current.notifier).state =
        user.copyWith(displayName: 'Late profile');
    expect(container.read(pushSyncProvider), same(writer));
    expect(container.read(vocabularyRepositoryProvider), same(repository));

    container.read(current.notifier).state =
        user.copyWith(id: 'different-account');
    expect(container.read(pushSyncProvider), isNot(same(writer)));
    expect(
        container.read(vocabularyRepositoryProvider), isNot(same(repository)));
  });

  test('sharing publishes explicitly; importing a token preserves privacy',
      () async {
    final list = (await repo.createList(name: 'Share me')).valueOrNull!;
    await repo.generateShareLink(list.id);
    expect((await db.vocabularyListDao.getById(list.id))!.visibility, 'public');

    remote.publicList = {
      'id': 'source',
      'name': 'Imported',
      'lang_a': 'en',
      'lang_b': 'ko',
      'concepts': const [],
    };
    final imported =
        (await repo.importFromShareToken('original-token')).valueOrNull!;
    final row = (await db.vocabularyListDao.getById(imported.id))!;
    expect(row.shareToken, isNull);
    expect(row.importedFromShareToken, 'original-token');
    expect(row.visibility, 'private');
  });

  test('a user-scoped drain excludes another cached account and its content',
      () async {
    final own = (await repo.createList(name: 'Mine')).valueOrNull!;
    await repo.addConceptWithVariants(
        listId: own.id, wordA: 'chat', wordB: '고양이');
    final otherRepo = VocabularyRepositoryImpl(
        db.vocabularyListDao, db.conceptDao, remote, 'other-user', db);
    final other = (await otherRepo.createList(name: 'Other')).valueOrNull!;
    await otherRepo.addConceptWithVariants(
        listId: other.id, wordA: 'chien', wordB: '개');

    final ownSync = PushSync(db.vocabularyListDao, db.conceptDao,
        db.progressDao, db.reviewEventDao, remote,
        userId: 'u');
    await ownSync.pushAll();

    expect(remote.pushedLists.map((row) => row['id']), [own.id]);
    expect(remote.pushedConcepts.map((row) => row['list_id']), [own.id]);
    expect(remote.pushedVariants, hasLength(2));
    expect(await db.vocabularyListDao.getUnsyncedLists(ownerId: 'other-user'),
        hasLength(1));
    expect(await db.conceptDao.getUnsyncedConcepts(ownerId: 'other-user'),
        hasLength(1));
    expect(await db.conceptDao.getUnsyncedVariants(ownerId: 'other-user'),
        hasLength(2));
  });

  test('share readiness is list-specific and detects failed child uploads',
      () async {
    final own = (await repo.createList(name: 'Incomplete')).valueOrNull!;
    await repo.addConceptWithVariants(
        listId: own.id, wordA: 'chat', wordB: '고양이');
    remote.failConcepts = true;
    await sync.pushAll();
    expect(await db.vocabularyListDao.hasPendingContents(own.id), isTrue);

    remote.failConcepts = false;
    await sync.pushAll();
    await repo.createList(name: 'Unrelated pending list');
    expect(await db.vocabularyListDao.hasPendingContents(own.id), isFalse);
  });

  test('a share flush does not wait for a blocked unrelated drain', () async {
    final unrelated = (await repo.createList(name: 'Unrelated')).valueOrNull!;
    final requested = Completer<void>();
    final reply = Completer<void>();
    remote.onList = (row) async {
      if (row['id'] == unrelated.id) {
        requested.complete();
        await reply.future;
      }
    };
    final globalDrain = sync.pushAll();
    try {
      await requested.future;
      final shared = (await repo.createList(name: 'Share me')).valueOrNull!;
      await repo.addConceptWithVariants(
          listId: shared.id, wordA: 'chat', wordB: '고양이');
      await repo.generateShareLink(shared.id);

      expect(await sync.pushList(shared.id).timeout(const Duration(seconds: 2)),
          4);
      expect((await db.vocabularyListDao.getById(shared.id))!.isSynced, isTrue);
      expect(await db.vocabularyListDao.hasPendingContents(shared.id), isFalse);
      expect((await db.vocabularyListDao.getById(unrelated.id))!.isSynced,
          isFalse);
    } finally {
      reply.complete();
      await globalDrain;
    }
  });

  test('blocked audio does not delay share metadata or later global drains',
      () async {
    final shared = (await repo.createList(name: 'Share me')).valueOrNull!;
    await repo.addConceptWithVariants(
        listId: shared.id, wordA: 'chat', wordB: '고양이');
    await repo.generateShareLink(shared.id);
    final requested = Completer<void>();
    final reply = Completer<void>();
    final requests = <String>[];
    remote.onAudio = (id) async {
      requests.add(id);
      if (!requested.isCompleted) requested.complete();
      await reply.future;
    };

    final shareDrain = sync.pushList(shared.id);
    try {
      await requested.future;
      expect(await shareDrain.timeout(const Duration(seconds: 2)), 4);
      expect(await db.vocabularyListDao.hasPendingContents(shared.id), isFalse);
      final another =
          (await repo.createList(name: 'Work continues')).valueOrNull!;
      await repo.addConceptWithVariants(
          listId: another.id, wordA: 'sol', wordB: '땅');
      expect(await sync.pushAll().timeout(const Duration(seconds: 2)), 4);
      expect(remote.pushedVariants, hasLength(4));
      expect(requests, hasLength(1));
    } finally {
      reply.complete();
      await shareDrain;
    }
  });

  test(
      'offline writes are drained on the next push: list, concept and both '
      'variants land remotely and are marked synced', () async {
    remote.failAll = true; // backend down while the user works
    final list = (await repo.createList(name: 'Animaux')).valueOrNull!;
    await repo.addConceptWithVariants(
        listId: list.id, wordA: 'chat', wordB: '고양이');
    remote.pushedLists.clear(); // drop the failed fire-and-forget attempts

    remote.failAll = false; // back online
    final pushed = await sync.pushAll();

    expect(pushed, 4); // 1 list + 1 concept + 2 variants
    expect(remote.pushedLists.single['name'], 'Animaux');
    expect(remote.pushedLists.single['lang_a'], 'fr');
    expect(remote.pushedConcepts, hasLength(1));
    expect(remote.pushedVariants.map((v) => v['word']),
        containsAll(['chat', '고양이']));
    expect(await db.vocabularyListDao.getUnsyncedLists(), isEmpty);
    expect(await db.conceptDao.getUnsyncedConcepts(), isEmpty);
    expect(await db.conceptDao.getUnsyncedVariants(), isEmpty);
  });

  test('a second drain pushes nothing (idempotent)', () async {
    await repo.createList(name: 'A');
    await sync.pushAll();
    remote.pushedLists.clear();

    final pushed = await sync.pushAll();

    expect(pushed, 0);
    expect(remote.pushedLists, isEmpty);
  });

  test(
      'an edit during a remote write stays queued until its own acknowledgement',
      () async {
    final list = (await repo.createList(name: 'First')).valueOrNull!;
    remote.onList = (_) async {
      remote.onList = null;
      await repo.updateList(list.copyWith(name: 'Edited'));
    };

    await sync.pushAll();

    expect(remote.pushedLists.map((row) => row['name']), ['First', 'Edited']);
    expect((await db.vocabularyListDao.getById(list.id))!.isSynced, isTrue);
  });

  test('sharing persists public visibility for the single durable writer',
      () async {
    final list = (await repo.createList(name: 'Shared')).valueOrNull!;
    final link = await repo.generateShareLink(list.id);
    expect(link.isSuccess, isTrue);
    expect(remote.pushedLists, isEmpty);
    await sync.pushAll();
    expect(remote.pushedLists.single['visibility'], 'public');
    expect(remote.pushedLists.single['share_token'], isNotEmpty);
  });

  test(
      'a per-table failure keeps ONLY those rows queued; the next drain '
      'retries just them', () async {
    final list = (await repo.createList(name: 'A')).valueOrNull!;
    await repo.addConceptWithVariants(
        listId: list.id, wordA: 'chat', wordB: '고양이');
    remote.failConcepts = true;

    await sync.pushAll();

    // List and variants made it; the concept stayed queued.
    expect(await db.vocabularyListDao.getUnsyncedLists(), isEmpty);
    expect(await db.conceptDao.getUnsyncedConcepts(), hasLength(1));

    remote.failConcepts = false;
    final retried = await sync.pushAll();

    expect(retried, 1); // just the concept
    expect(await db.conceptDao.getUnsyncedConcepts(), isEmpty);
  });

  test('soft-deleted rows are pushed with is_deleted so the delete syncs',
      () async {
    final list = (await repo.createList(name: 'A')).valueOrNull!;
    final concept = (await repo.addConceptWithVariants(
            listId: list.id, wordA: 'chat', wordB: '고양이'))
        .valueOrNull!;
    await sync.pushAll();
    remote.pushedConcepts.clear();

    await repo.deleteConcept(concept.id); // soft-delete → isSynced=false again
    // Let the repo's own fire-and-forget push land, then isolate the drain's.
    await Future<void>.delayed(const Duration(milliseconds: 20));
    remote.pushedConcepts.clear();

    await sync.pushAll();

    expect(remote.pushedConcepts.single['is_deleted'], true);
    expect(await db.conceptDao.getUnsyncedConcepts(), isEmpty);
  });
}
