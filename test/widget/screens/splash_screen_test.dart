import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vocab_kr/domain/entities/app_user.dart';
import 'package:vocab_kr/domain/entities/subscription_type.dart';
import 'package:vocab_kr/presentation/providers/auth/auth_provider.dart';
import 'package:vocab_kr/presentation/providers/lists/vocabulary_provider.dart';
import 'package:vocab_kr/presentation/screens/onboarding/splash_screen.dart';

import '../../helpers/pump_screen.dart';

class _DelayedAuthNotifier extends AuthNotifier {
  _DelayedAuthNotifier(this._result);

  final Future<AppUser?> _result;

  @override
  Future<AppUser?> build() => _result;
}

void main() {
  setUpAll(initTestLocalization);

  testWidgets('waits for auth and starter content before opening home',
      (tester) async {
    final auth = Completer<AppUser?>();
    final starterContent = Completer<void>();
    final user = AppUser(
      id: 'user',
      email: 'user@example.com',
      username: 'learner',
      subscriptionType: SubscriptionType.free,
      createdAt: DateTime(2026),
    );

    await pumpScreen(
      tester,
      screen: const SplashScreen(),
      settle: false,
      overrides: [
        authStateProvider.overrideWith(() => _DelayedAuthNotifier(auth.future)),
        seedStarterListsProvider.overrideWith((ref) => starterContent.future),
      ],
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, __) => const Scaffold(body: Text('Home ready')),
        ),
        GoRoute(
          path: '/welcome',
          builder: (_, __) => const Scaffold(body: Text('Welcome ready')),
        ),
      ],
    );

    expect(find.text('Home ready'), findsNothing);
    auth.complete(user);
    await tester.pump();
    expect(find.text('Home ready'), findsNothing);

    starterContent.complete();
    await tester.pump();
    await tester.pump();
    expect(find.text('Home ready'), findsOneWidget);
  });

  testWidgets('opens welcome only after anonymous auth state resolves',
      (tester) async {
    final auth = Completer<AppUser?>();

    await pumpScreen(
      tester,
      screen: const SplashScreen(),
      settle: false,
      overrides: [
        authStateProvider.overrideWith(() => _DelayedAuthNotifier(auth.future)),
      ],
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, __) => const Scaffold(body: Text('Home ready')),
        ),
        GoRoute(
          path: '/welcome',
          builder: (_, __) => const Scaffold(body: Text('Welcome ready')),
        ),
      ],
    );

    expect(find.text('Welcome ready'), findsNothing);
    auth.complete(null);
    await tester.pump();
    await tester.pump();
    expect(find.text('Welcome ready'), findsOneWidget);
  });
}
