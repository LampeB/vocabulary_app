import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vocab_kr/presentation/navigation/auth_redirect.dart';
import 'package:go_router/go_router.dart';
import 'package:vocab_kr/domain/entities/app_user.dart';
import 'package:vocab_kr/domain/entities/subscription_type.dart';
import 'package:vocab_kr/domain/repositories/auth_repository.dart';
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

class _LocalSessionRepository implements AuthRepository {
  _LocalSessionRepository(this.currentUser);
  @override
  final AppUser? currentUser;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(initTestLocalization);

  testWidgets('waits for auth and starter content before opening home', (
    tester,
  ) async {
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
          builder: (_, _) => const Scaffold(body: Text('Home ready')),
        ),
        GoRoute(
          path: '/welcome',
          builder: (_, _) => const Scaffold(body: Text('Welcome ready')),
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

  testWidgets(
    'early Supabase session redirects through bootstrap while profile is pending',
    (tester) async {
      final session = ValueNotifier(false);
      addTearDown(session.dispose);
      final profile = Completer<AppUser?>();
      final seed = Completer<void>();
      final router = GoRouter(
        initialLocation: '/auth',
        refreshListenable: session,
        redirect: (_, state) => authRedirect(
          isSignedIn: session.value,
          location: state.matchedLocation,
        ),
        routes: [
          GoRoute(
            path: '/auth',
            builder: (_, _) => const Text('Authentication'),
          ),
          GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
          GoRoute(
            path: '/home',
            builder: (_, _) => const Text('Prepared home'),
          ),
          GoRoute(path: '/welcome', builder: (_, _) => const Text('Welcome')),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith(
              () => _DelayedAuthNotifier(profile.future),
            ),
            seedStarterListsProvider.overrideWith((ref) => seed.future),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      session.value = true;
      await tester.pump();
      await tester.pump();
      expect(find.text('Prepared home'), findsNothing);
      profile.complete(
        AppUser(
          id: 'user',
          email: 'u@test.example',
          username: 'learner',
          subscriptionType: SubscriptionType.free,
          createdAt: DateTime(2026),
        ),
      );
      await tester.pump();
      expect(find.text('Prepared home'), findsNothing);
      seed.complete();
      await tester.pump();
      await tester.pump();
      expect(find.text('Prepared home'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('opens welcome only after anonymous auth state resolves', (
    tester,
  ) async {
    final auth = Completer<AppUser?>();

    await pumpScreen(
      tester,
      screen: const SplashScreen(),
      settle: false,
      overrides: [
        authStateProvider.overrideWith(() => _DelayedAuthNotifier(auth.future)),
        authRepositoryProvider.overrideWithValue(_LocalSessionRepository(null)),
      ],
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, _) => const Scaffold(body: Text('Home ready')),
        ),
        GoRoute(
          path: '/welcome',
          builder: (_, _) => const Scaffold(body: Text('Welcome ready')),
        ),
      ],
    );

    expect(find.text('Welcome ready'), findsNothing);
    auth.complete(null);
    await tester.pump();
    await tester.pump();
    expect(find.text('Welcome ready'), findsOneWidget);
  });

  testWidgets('falls back to welcome when auth restoration times out', (
    tester,
  ) async {
    final pendingAuth = Completer<AppUser?>();

    await pumpScreen(
      tester,
      screen: const SplashScreen(authTimeout: Duration(milliseconds: 10)),
      settle: false,
      overrides: [
        authStateProvider.overrideWith(
          () => _DelayedAuthNotifier(pendingAuth.future),
        ),
        authRepositoryProvider.overrideWithValue(_LocalSessionRepository(null)),
      ],
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, _) => const Scaffold(body: Text('Home ready')),
        ),
        GoRoute(
          path: '/welcome',
          builder: (_, _) => const Scaffold(body: Text('Welcome ready')),
        ),
      ],
    );

    await tester.pump(const Duration(milliseconds: 11));
    await tester.pump();

    expect(find.text('Welcome ready'), findsOneWidget);
  });

  for (final profilePending in [true, false]) {
    testWidgets(
      'local session survives production redirect (pending: $profilePending)',
      (tester) async {
        final pendingProfile = Completer<AppUser?>();
        final user = AppUser(
          id: 'restored-user',
          email: 'u@test.example',
          username: 'learner',
          subscriptionType: SubscriptionType.free,
          createdAt: DateTime(2026),
        );
        var seeds = 0;
        final router = GoRouter(
          initialLocation: '/splash',
          redirect: (_, state) =>
              authRedirect(isSignedIn: true, location: state.matchedLocation),
          routes: [
            GoRoute(
              path: '/splash',
              builder: (_, _) =>
                  const SplashScreen(authTimeout: Duration(milliseconds: 10)),
            ),
            GoRoute(
              path: '/home',
              builder: (_, _) => const Text('Offline home'),
            ),
            GoRoute(path: '/welcome', builder: (_, _) => const Text('Welcome')),
          ],
        );
        addTearDown(router.dispose);
        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(
              _LocalSessionRepository(user),
            ),
            authStateProvider.overrideWith(
              () => _DelayedAuthNotifier(
                profilePending ? pendingProfile.future : Future.value(null),
              ),
            ),
            seedStarterListsProvider.overrideWith((ref) async {
              expect(ref.read(currentUserProvider)?.id, user.id);
              seeds++;
            }),
          ],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pump(const Duration(milliseconds: 11));
        await tester.pump();
        await tester.pump();
        expect(find.text('Offline home'), findsOneWidget);
        expect(seeds, 1);
        if (profilePending) {
          pendingProfile.complete(
            user.copyWith(displayName: 'Restored profile'),
          );
          await tester.pump();
          await tester.pump();
          expect(
            container.read(currentUserProvider)?.displayName,
            'Restored profile',
          );
        }
        expect(find.text('Offline home'), findsOneWidget);
        expect(seeds, 1);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
