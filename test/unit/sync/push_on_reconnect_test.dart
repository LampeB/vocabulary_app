import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/data/sync/push_sync.dart';
import 'package:vocab_kr/domain/entities/app_user.dart';
import 'package:vocab_kr/presentation/providers/auth/auth_provider.dart';
import 'package:vocab_kr/presentation/providers/lists/vocabulary_provider.dart';
import 'package:vocab_kr/presentation/widgets/app_shell.dart';

class _CountingPushSync implements PushSync {
  int calls = 0;
  @override
  Future<int> pushAll() async => ++calls;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('offline writes wait for reconnect and cancel a queued drain',
      (tester) async {
    final network = StreamController<List<ConnectivityResult>>.broadcast();
    final writes = StreamController<int>.broadcast();
    final sync = _CountingPushSync();
    final container = ProviderContainer(overrides: [
      currentUserProvider.overrideWithValue(AppUser(
          id: 'u',
          email: 'u@test',
          username: 'user',
          createdAt: DateTime(2026))),
      connectivityStreamProvider.overrideWith((ref) => network.stream),
      pendingWritesProvider.overrideWith((ref) => writes.stream),
      pushSyncProvider.overrideWithValue(sync),
    ]);
    addTearDown(network.close);
    addTearDown(writes.close);
    try {
      container.read(pushOnReconnectProvider);
      network.add([ConnectivityResult.none]);
      await tester.pump();
      for (var count = 1; count <= 3; count++) {
        writes.add(count);
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

      writes.add(4);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 299));
      expect(sync.calls, 1);
      await tester.pump(const Duration(milliseconds: 1));
      expect(sync.calls, 2);

      writes.add(5);
      await tester.pump();
      network.add([ConnectivityResult.none]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(sync.calls, 2);
      network.add([ConnectivityResult.mobile]);
      await tester.pump(const Duration(milliseconds: 350));
      expect(sync.calls, 3);
      writes.add(6);
      await tester.pump();
      writes.add(0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(sync.calls, 3);
      writes.add(7);
      await tester.pump();
    } finally {
      container.dispose();
    }
    await tester.pump(const Duration(milliseconds: 350));
    expect(sync.calls, 3);
  });
}
