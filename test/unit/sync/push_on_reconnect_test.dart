import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
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
import 'package:vocab_kr/presentation/widgets/app_shell.dart';
import '../../helpers/fake_remote.dart';

class _CountingPushSync implements PushSync {
  int calls = 0;
  final first = Completer<void>();
  @override
  Future<int> pushAll() async {
    if (!first.isCompleted) first.complete();
    return ++calls;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RestorationRemote extends FakeRemote {
  bool offline = false;
  int pulls = 0;
  final requested = Completer<void>();
  final release = Completer<void>();

  @override
  Future<Result<List<Map<String, dynamic>>>> fetchLists(String ownerId) async {
    pulls++;
    if (offline) return const Failure(NetworkException('offline'));
    if (!requested.isCompleted) requested.complete();
    await release.future;
    return Success([
      {
        'id': 'restored-list',
        'owner_id': ownerId,
        'name': 'Restored Vocabulary',
        'created_at': '2026-11-27T00:00:00Z',
        'updated_at': '2026-11-27T00:00:00Z',
      },
    ]);
  }
}

AppUser _user(String id) =>
    AppUser(id: id, email: '$id@test', username: id, createdAt: DateTime(2026));

void main() {
  testWidgets('offline writes wait for reconnect and cancel a queued drain', (
    tester,
  ) async {
    final network = StreamController<List<ConnectivityResult>>.broadcast();
    final writes = StreamController<void>.broadcast();
    final sync = _CountingPushSync();
    final container = ProviderContainer(
      overrides: [
        currentUserProvider.overrideWithValue(
          AppUser(
            id: 'u',
            email: 'u@test',
            username: 'user',
            createdAt: DateTime(2026),
          ),
        ),
        connectivityStreamProvider.overrideWith((ref) => network.stream),
        outboundMutationsProvider.overrideWith((ref) => writes.stream),
        syncOnLoginProvider.overrideWith((ref) async {}),
        pushSyncProvider.overrideWithValue(sync),
      ],
    );
    addTearDown(network.close);
    addTearDown(writes.close);
    try {
      container.read(pushOnReconnectProvider);
      network.add([ConnectivityResult.none]);
      await tester.pump();
      for (var count = 1; count <= 3; count++) {
        writes.add(null);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
      }
      expect(sync.calls, 0);
      network.add([ConnectivityResult.wifi]);
      await tester.pump(const Duration(milliseconds: 350));
      expect(sync.calls, 1);
      network.add([ConnectivityResult.mobile]);
      await tester.pump(const Duration(milliseconds: 350));
      expect(sync.calls, 1);

      writes.add(null);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 299));
      expect(sync.calls, 1);
      await tester.pump(const Duration(milliseconds: 1));
      expect(sync.calls, 2);

      writes.add(null);
      await tester.pump();
      network.add([ConnectivityResult.none]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(sync.calls, 2);
      network.add([ConnectivityResult.mobile]);
      await tester.pump(const Duration(milliseconds: 350));
      expect(sync.calls, 3);
      writes.add(null);
      await tester.pump();
    } finally {
      container.dispose();
    }
    await tester.pump(const Duration(milliseconds: 350));
    expect(sync.calls, 3);
  });

  testWidgets(
    'active account edits wake the scheduler, acknowledgements do not',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final network = StreamController<List<ConnectivityResult>>.broadcast();
      final sync = _CountingPushSync();
      final remote = FakeRemote();
      VocabularyRepositoryImpl repository(String userId) =>
          VocabularyRepositoryImpl(
            db.vocabularyListDao,
            db.conceptDao,
            remote,
            userId,
            db,
          );
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          currentUserProvider.overrideWithValue(
            AppUser(
              id: 'active',
              email: 'active@test',
              username: 'active',
              createdAt: DateTime(2026),
            ),
          ),
          connectivityStreamProvider.overrideWith((ref) => network.stream),
          syncOnLoginProvider.overrideWith((ref) async {}),
          pushSyncProvider.overrideWithValue(sync),
        ],
      );
      addTearDown(db.close);
      addTearDown(network.close);
      try {
        container.read(pushOnReconnectProvider);
        network.add([ConnectivityResult.wifi]);
        await tester.pump();
        expect(sync.calls, 1);

        await tester.runAsync(
          () => repository('other').createList(name: 'Other backlog'),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        expect(sync.calls, 1);

        final active = repository('active');
        final list = (await tester.runAsync(
          () => active.createList(name: 'Pending'),
        ))!.valueOrNull!;
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        expect(sync.calls, 2);

        // The spy never sends the row, so renaming changes no pending count.
        await tester.runAsync(
          () => active.renameList(list.id, 'Still pending'),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        expect(sync.calls, 3);

        await tester.runAsync(() async {
          final row = (await db.vocabularyListDao.getById(list.id))!;
          expect(row.isSynced, isFalse);
          expect(await db.vocabularyListDao.acknowledge(row), 1);
        });
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        expect(sync.calls, 3);
      } finally {
        container.dispose();
      }
    },
  );

  test(
    'late profile enrichment shares the same in-flight restoration',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final remote = _RestorationRemote();
      final current = StateProvider<AppUser?>((_) => _user('u'));
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vocabularyRemoteProvider.overrideWithValue(remote),
          currentUserProvider.overrideWith((ref) => ref.watch(current)),
        ],
      );
      addTearDown(db.close);
      addTearDown(container.dispose);

      final initial = container.read(syncOnLoginProvider.future);
      await remote.requested.future;
      container.read(current.notifier).state = _user(
        'u',
      ).copyWith(displayName: 'Enriched');
      expect(container.read(syncOnLoginProvider.future), same(initial));
      remote.release.complete();
      await initial;
      expect(remote.pulls, 1);

      container.read(current.notifier).state = null;
      await container.read(syncOnLoginProvider.future);
      container.read(current.notifier).state = _user('u');
      await container.read(syncOnLoginProvider.future);
      expect(remote.pulls, 2);
    },
  );

  test(
    'reconnect retries a failed initial pull before draining local edits',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final remote = _RestorationRemote()..offline = true;
      final network = StreamController<List<ConnectivityResult>>.broadcast();
      final sync = _CountingPushSync();
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vocabularyRemoteProvider.overrideWithValue(remote),
          currentUserProvider.overrideWithValue(_user('u')),
          connectivityStreamProvider.overrideWith((ref) => network.stream),
          pushSyncProvider.overrideWithValue(sync),
        ],
      );
      addTearDown(db.close);
      addTearDown(network.close);
      addTearDown(container.dispose);

      await expectLater(
        container.read(syncOnLoginProvider.future),
        throwsA(isA<NetworkException>()),
      );
      expect(container.read(syncOnLoginProvider).hasError, isTrue);
      container.read(pushOnReconnectProvider);
      network.add([ConnectivityResult.none]);
      await container.read(connectivityStreamProvider.future);
      final repo = container.read(vocabularyRepositoryProvider);
      expect((await repo.createList(name: 'Local edit')).isSuccess, isTrue);
      expect(sync.calls, 0);

      remote.offline = false;
      network.add([ConnectivityResult.wifi]);
      await remote.requested.future.timeout(const Duration(seconds: 2));
      expect(sync.calls, 0);
      remote.release.complete();
      await sync.first.future.timeout(const Duration(seconds: 2));
      expect(remote.pulls, 2);
      expect(container.read(syncOnLoginProvider).hasValue, isTrue);
      expect((await repo.getListById('restored-list')).isSuccess, isTrue);
      expect(sync.calls, 1);
    },
  );

  test(
    'a reconnect during a failed pull queues one retry before push',
    () async {
      final network = StreamController<List<ConnectivityResult>>.broadcast();
      final firstStarted = Completer<void>();
      final firstReply = Completer<void>();
      final retryStarted = Completer<void>();
      final retryReply = Completer<void>();
      final sync = _CountingPushSync();
      final writes = StreamController<void>.broadcast();
      var restores = 0;
      final container = ProviderContainer(
        overrides: [
          currentUserProvider.overrideWithValue(_user('u')),
          connectivityStreamProvider.overrideWith((ref) => network.stream),
          outboundMutationsProvider.overrideWith((ref) => writes.stream),
          pushSyncProvider.overrideWithValue(sync),
          syncOnLoginProvider.overrideWith((ref) {
            if (++restores == 1) {
              firstStarted.complete();
              return firstReply.future;
            }
            retryStarted.complete();
            return retryReply.future;
          }),
        ],
      );
      addTearDown(network.close);
      addTearDown(writes.close);
      addTearDown(container.dispose);

      container.read(pushOnReconnectProvider);
      network.add([ConnectivityResult.wifi]);
      await firstStarted.future.timeout(const Duration(seconds: 2));
      network.add([ConnectivityResult.none]);
      await Future<void>.delayed(Duration.zero);
      network.add([ConnectivityResult.wifi]);
      await Future<void>.delayed(Duration.zero);
      expect(restores, 1);
      expect(sync.calls, 0);

      firstReply.completeError(
        const NetworkException('previous connection lost'),
      );
      await retryStarted.future.timeout(const Duration(seconds: 2));
      expect(sync.calls, 0);
      retryReply.complete();
      await sync.first.future.timeout(const Duration(seconds: 2));
      expect(restores, 2);
      expect(sync.calls, 1);
    },
  );
}
