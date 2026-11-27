import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
  @override
  Future<int> pushAll() async => ++calls;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

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
}
