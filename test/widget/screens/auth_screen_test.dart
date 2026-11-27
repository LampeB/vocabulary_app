import 'dart:async';
import 'dart:convert';

// ignore: implementation_imports
import 'package:easy_localization/src/localization.dart';
// ignore: implementation_imports
import 'package:easy_localization/src/translations.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vocab_kr/core/errors/app_exception.dart';
import 'package:vocab_kr/core/errors/failure.dart';
import 'package:vocab_kr/core/widget_keys.dart';
import 'package:vocab_kr/core/theme/app_theme.dart';
import 'package:vocab_kr/domain/entities/app_user.dart';
import 'package:vocab_kr/domain/entities/subscription_type.dart';
import 'package:vocab_kr/presentation/providers/auth/auth_provider.dart';
import 'package:vocab_kr/presentation/providers/lists/vocabulary_provider.dart';
import 'package:vocab_kr/presentation/screens/onboarding/auth_screen.dart';
import 'package:vocab_kr/presentation/screens/onboarding/welcome_screen.dart';
import '../../helpers/pump_screen.dart';

/// Welcome + auth screens: routing to sign-in/up, form validation, the
/// success → /home and failure → inline-error paths, and password reset.

AppUser _user() => AppUser(
  id: 'u',
  email: 't@t.fr',
  username: 'thomas',
  subscriptionType: SubscriptionType.free,
  createdAt: DateTime(2026),
);

_ScriptedAuthNotifier? _lastAuth;

class _ScriptedAuthNotifier extends AuthNotifier {
  _ScriptedAuthNotifier() {
    _lastAuth = this;
  }
  bool failNext = false;
  AuthFailureReason? failureReason;
  AppException? resetFailure;
  String? signedInEmail;
  String? signedUpUsername;
  String? resetEmail;

  @override
  Future<AppUser?> build() async => null;

  @override
  Future<Result<void>> sendPasswordReset(String email) async {
    resetEmail = email;
    return resetFailure == null ? const Success(null) : Failure(resetFailure!);
  }

  @override
  Future<Result<AppUser>> signIn(String email, String password) async {
    if (failureReason != null) {
      return Failure(AuthException.forReason(failureReason!));
    }
    if (failNext) {
      return const Failure(
        AuthException.forReason(AuthFailureReason.invalidCredentials),
      );
    }
    signedInEmail = email;
    return Success(_user());
  }

  @override
  Future<Result<AppUser>> signUp(
    String email,
    String password,
    String username,
  ) async {
    if (failureReason != null) {
      return Failure(AuthException.forReason(failureReason!));
    }
    if (failNext) {
      return const Failure(
        AuthException.forReason(AuthFailureReason.emailTaken),
      );
    }
    signedUpUsername = username;
    return Success(_user());
  }
}

void main() {
  setUpAll(initTestLocalization);

  String? navigatedTo;

  Future<void> pump(
    WidgetTester tester,
    Widget screen, {
    bool settle = true,
    Future<void>? bootstrap,
  }) {
    navigatedTo = null;
    _lastAuth = null;
    return pumpScreen(
      tester,
      screen: screen,
      settle: settle,
      overrides: [
        authStateProvider.overrideWith(_ScriptedAuthNotifier.new),
        seedStarterListsProvider.overrideWith(
          (ref) => bootstrap ?? Future.value(),
        ),
      ],
      routes: [
        for (final r in ['/home', '/auth', '/welcome'])
          GoRoute(
            path: r,
            pageBuilder: (_, state) {
              navigatedTo = state.uri.toString();
              return const MaterialPage<void>(
                child: Scaffold(body: SizedBox()),
              );
            },
          ),
      ],
    );
  }

  group('welcome screen', () {
    for (final mode in ['signup', 'signin']) {
      testWidgets('keyboard opens $mode and submits the actual form', (
        tester,
      ) async {
        _lastAuth = null;
        var reachedHome = false;
        await pumpScreen(
          tester,
          screen: const WelcomeScreen(),
          overrides: [
            authStateProvider.overrideWith(_ScriptedAuthNotifier.new),
            seedStarterListsProvider.overrideWith((ref) async {}),
          ],
          routes: [
            GoRoute(
              path: '/auth',
              builder: (_, state) =>
                  AuthScreen(initialMode: state.uri.queryParameters['mode']!),
            ),
            GoRoute(
              path: '/home',
              builder: (_, _) {
                reachedHome = true;
                return const Scaffold(body: Text('Home'));
              },
            ),
          ],
        );
        // Traverse the two visible welcome actions using Tab alone.
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        if (mode == 'signin') {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        }
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(find.byType(AuthScreen), findsOneWidget);
        expect(
          find.byKey(const Key('username_field')),
          mode == 'signup' ? findsOneWidget : findsNothing,
        );
        if (mode == 'signup') {
          await tester.enterText(
            find.byKey(const Key('username_field')),
            'thomas',
          );
        }
        await tester.enterText(find.byKey(const Key('email_field')), 't@t.fr');
        await tester.enterText(
          find.byKey(const Key('password_field')),
          'secret123',
        );
        // Password -> visibility -> forgot password (sign in) -> submit.
        final steps = mode == 'signin' ? 3 : 2;
        for (var i = 0; i < steps; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        }
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(reachedHome, isTrue);
        expect(
          mode == 'signin'
              ? _lastAuth!.signedInEmail
              : _lastAuth!.signedUpUsername,
          mode == 'signin' ? 't@t.fr' : 'thomas',
        );
      });
    }

    testWidgets('sign-up and sign-in buttons route with the right mode', (
      tester,
    ) async {
      // Welcome animates forever -> no pumpAndSettle.
      await pump(tester, const WelcomeScreen(), settle: false);
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.byKey(const ValueKey(WidgetKeys.screenWelcome)),
        findsOneWidget,
      );

      await tester.tap(find.text('J\'ai déjà un compte'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(navigatedTo, '/auth?mode=signin');
    });
  });

  group('auth screen — sign in', () {
    testWidgets('waits for the login bootstrap before opening home', (
      tester,
    ) async {
      final bootstrap = Completer<void>();
      await pump(tester, const AuthScreen(), bootstrap: bootstrap.future);
      await tester.enterText(find.byKey(const Key('email_field')), 't@t.fr');
      await tester.enterText(
        find.byKey(const Key('password_field')),
        'secret123',
      );
      await tester.tap(find.byKey(const Key('auth_submit_button')));
      await tester.pump();
      expect(navigatedTo, isNull);
      bootstrap.complete();
      await tester.pumpAndSettle();
      expect(navigatedTo, '/home');
    });

    testWidgets('valid credentials call signIn and land on /home', (
      tester,
    ) async {
      await pump(tester, const AuthScreen(initialMode: 'signin'));

      await tester.enterText(find.byKey(const Key('email_field')), 't@t.fr');
      await tester.enterText(
        find.byKey(const Key('password_field')),
        'secret123',
      );
      await tester.tap(find.byKey(const Key('auth_submit_button')));
      await tester.pumpAndSettle();

      expect(_lastAuth!.signedInEmail, 't@t.fr');
      expect(navigatedTo, '/home');
    });

    testWidgets('a failed sign-in shows the error inline and stays put', (
      tester,
    ) async {
      await pump(tester, const AuthScreen(initialMode: 'signin'));
      _lastAuth!.failNext = true;

      await tester.enterText(find.byKey(const Key('email_field')), 't@t.fr');
      await tester.enterText(
        find.byKey(const Key('password_field')),
        'wrongpassword',
      );
      await tester.tap(find.byKey(const Key('auth_submit_button')));
      await tester.pumpAndSettle();

      expect(
        find.text('Adresse e-mail ou mot de passe incorrect.'),
        findsOneWidget,
      );
      expect(navigatedTo, isNull);
    });

    testWidgets('empty form does not submit (validators block)', (
      tester,
    ) async {
      await pump(tester, const AuthScreen(initialMode: 'signin'));

      await tester.tap(find.byKey(const Key('auth_submit_button')));
      await tester.pumpAndSettle();

      expect(_lastAuth!.signedInEmail, isNull);
      expect(navigatedTo, isNull);
    });
  });

  group('auth screen — sign up', () {
    testWidgets('sign-up mode shows the username field and calls signUp', (
      tester,
    ) async {
      await pump(tester, const AuthScreen(initialMode: 'signup'));

      await tester.enterText(find.byKey(const Key('username_field')), 'thomas');
      await tester.enterText(find.byKey(const Key('email_field')), 't@t.fr');
      await tester.enterText(
        find.byKey(const Key('password_field')),
        'secret123',
      );
      await tester.tap(find.byKey(const Key('auth_submit_button')));
      await tester.pumpAndSettle();

      expect(_lastAuth!.signedUpUsername, 'thomas');
      expect(navigatedTo, '/home');
    });
  });

  for (final locale in ['fr', 'en', 'ko']) {
    for (final scenario in [
      (
        AuthFailureReason.invalidCredentials,
        'auth.error_credentials',
        'signin',
      ),
      (AuthFailureReason.usernameTaken, 'auth.error_username_taken', 'signup'),
      (AuthFailureReason.emailTaken, 'auth.error_email_taken', 'signup'),
    ]) {
      testWidgets('auth renders ${scenario.$1} in $locale', (tester) async {
        final raw = (await tester.runAsync(
          () => rootBundle.loadString('assets/translations/$locale.json'),
        ))!;
        final copy = jsonDecode(raw) as Map<String, dynamic>;
        final translations = Translations(copy);
        Localization.load(
          Locale(locale),
          translations: translations,
          fallbackTranslations: translations,
        );
        addTearDown(initTestLocalization);
        await pump(tester, AuthScreen(initialMode: scenario.$3));
        _lastAuth!.failureReason = scenario.$1;
        if (scenario.$3 == 'signup') {
          await tester.enterText(
            find.byKey(const Key('username_field')),
            'thomas',
          );
        }
        await tester.enterText(
          find.byKey(const Key('email_field')),
          'a@example.test',
        );
        await tester.enterText(
          find.byKey(const Key('password_field')),
          'password123',
        );
        await tester.tap(find.byKey(const Key('auth_submit_button')));
        await tester.pumpAndSettle();
        expect(find.text(copy[scenario.$2] as String), findsOneWidget);
        expect(navigatedTo, isNull);
      });
    }
  }

  group('auth screen — password reset', () {
    for (final locale in ['fr', 'en', 'ko']) {
      testWidgets('reset stays reachable above a compact keyboard in $locale', (
        tester,
      ) async {
        final raw = (await tester.runAsync(
          () => rootBundle.loadString('assets/translations/$locale.json'),
        ))!;
        final copy = jsonDecode(raw) as Map<String, dynamic>;
        final translations = Translations(copy);
        Localization.load(
          Locale(locale),
          translations: translations,
          fallbackTranslations: translations,
        );
        addTearDown(initTestLocalization);
        tester.view.physicalSize = const Size(568, 320);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        _lastAuth = null;
        final router = GoRouter(
          routes: [GoRoute(path: '/', builder: (_, _) => const AuthScreen())],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authStateProvider.overrideWith(_ScriptedAuthNotifier.new),
            ],
            child: MaterialApp.router(
              theme: AppTheme.light,
              routerConfig: router,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(2),
                  disableAnimations: true,
                ),
                child: child!,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final opener = find.byKey(
          const ValueKey(WidgetKeys.authForgotPassword),
        );
        await tester.ensureVisible(opener);
        await tester.tap(opener);
        tester.view.viewInsets = const FakeViewPadding(bottom: 180);
        await tester.pumpAndSettle();
        final dialog = find.byType(Dialog);
        final cue = find.descendant(
          of: dialog,
          matching: find.text(copy['v3.scroll_hint'] as String),
        );
        expect(cue, findsOneWidget);
        final opacity = find
            .ancestor(of: cue, matching: find.byType(AnimatedOpacity))
            .first;
        expect(tester.widget<AnimatedOpacity>(opacity).opacity, 1);
        final email = find.byKey(const ValueKey(WidgetKeys.authResetEmail));
        await tester.ensureVisible(email);
        await tester.pumpAndSettle();
        await tester.enterText(email, 'compact@example.test');
        await tester.pumpAndSettle();
        final send = find.byKey(const ValueKey(WidgetKeys.authResetSend));
        await tester.ensureVisible(send);
        await tester.pumpAndSettle();
        expect(send.hitTestable(), findsOneWidget);
        await tester.tap(send);
        await tester.pumpAndSettle();
        expect(_lastAuth!.resetEmail, 'compact@example.test');
        expect(find.byType(Dialog), findsNothing);
        expect(tester.takeException(), isNull);
        await unmountScreen(tester);
      });
    }
    for (final locale in ['fr', 'en', 'ko']) {
      for (final scenario in [
        (const NetworkException(), 'auth.error_network'),
        (
          const AuthException.forReason(AuthFailureReason.rateLimited),
          'auth.error_rate_limited',
        ),
        (
          const UnknownException('raw provider error'),
          'auth.reset_snackbar_error',
        ),
      ]) {
        testWidgets('reset shows ${scenario.$2} in $locale', (tester) async {
          final raw = (await tester.runAsync(
            () => rootBundle.loadString('assets/translations/$locale.json'),
          ))!;
          final copy = jsonDecode(raw) as Map<String, dynamic>;
          final translations = Translations(copy);
          Localization.load(
            Locale(locale),
            translations: translations,
            fallbackTranslations: translations,
          );
          addTearDown(initTestLocalization);
          await pump(tester, const AuthScreen());
          _lastAuth!.resetFailure = scenario.$1;
          await tester.tap(
            find.byKey(const ValueKey(WidgetKeys.authForgotPassword)),
          );
          await tester.pumpAndSettle();
          await tester.enterText(
            find.byKey(const ValueKey(WidgetKeys.authResetEmail)),
            'a@example.test',
          );
          await tester.tap(
            find.byKey(const ValueKey(WidgetKeys.authResetSend)),
          );
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey(WidgetKeys.authResetError)),
            findsOneWidget,
          );
          expect(find.text(copy[scenario.$2] as String), findsOneWidget);
          expect(find.text('raw provider error'), findsNothing);
        });
      }
    }
    testWidgets('forgot-password opens the dialog with email + send', (
      tester,
    ) async {
      await pump(tester, const AuthScreen(initialMode: 'signin'));

      await tester.tap(
        find.byKey(const ValueKey(WidgetKeys.authForgotPassword)),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey(WidgetKeys.authResetEmail)),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey(WidgetKeys.authResetSend)),
        findsOneWidget,
      );
    });
  });
}
