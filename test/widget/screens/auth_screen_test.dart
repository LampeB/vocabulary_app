import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vocab_kr/core/errors/app_exception.dart';
import 'package:vocab_kr/core/errors/failure.dart';
import 'package:vocab_kr/core/widget_keys.dart';
import 'package:vocab_kr/domain/entities/app_user.dart';
import 'package:vocab_kr/domain/entities/subscription_type.dart';
import 'package:vocab_kr/presentation/providers/auth/auth_provider.dart';
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
  String? signedInEmail;
  String? signedUpUsername;

  @override
  Future<AppUser?> build() async => null;

  @override
  Future<Result<AppUser>> signIn(String email, String password) async {
    if (failNext) return const Failure(AuthException('Identifiants invalides'));
    signedInEmail = email;
    return Success(_user());
  }

  @override
  Future<Result<AppUser>> signUp(
      String email, String password, String username) async {
    if (failNext) return const Failure(AuthException('Email déjà utilisé'));
    signedUpUsername = username;
    return Success(_user());
  }
}

void main() {
  setUpAll(initTestLocalization);

  String? navigatedTo;

  Future<void> pump(WidgetTester tester, Widget screen,
      {bool settle = true}) {
    navigatedTo = null;
    _lastAuth = null;
    return pumpScreen(
      tester,
      screen: screen,
      settle: settle,
      overrides: [authStateProvider.overrideWith(_ScriptedAuthNotifier.new)],
      routes: [
        for (final r in ['/home', '/auth', '/welcome'])
          GoRoute(
            path: r,
            pageBuilder: (_, state) {
              navigatedTo = state.uri.toString();
              return const MaterialPage<void>(
                  child: Scaffold(body: SizedBox()));
            },
          ),
      ],
    );
  }

  group('welcome screen', () {
    testWidgets('sign-up and sign-in buttons route with the right mode',
        (tester) async {
      // Welcome animates forever -> no pumpAndSettle.
      await pump(tester, const WelcomeScreen(), settle: false);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey(WidgetKeys.screenWelcome)),
          findsOneWidget);

      await tester.tap(find.text('J\'ai déjà un compte'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(navigatedTo, '/auth?mode=signin');
    });
  });

  group('auth screen — sign in', () {
    testWidgets('valid credentials call signIn and land on /home',
        (tester) async {
      await pump(tester, const AuthScreen(initialMode: 'signin'));

      await tester.enterText(
          find.byKey(const Key('email_field')), 't@t.fr');
      await tester.enterText(
          find.byKey(const Key('password_field')), 'secret123');
      await tester.tap(find.byKey(const Key('auth_submit_button')));
      await tester.pumpAndSettle();

      expect(_lastAuth!.signedInEmail, 't@t.fr');
      expect(navigatedTo, '/home');
    });

    testWidgets('a failed sign-in shows the error inline and stays put',
        (tester) async {
      await pump(tester, const AuthScreen(initialMode: 'signin'));
      _lastAuth!.failNext = true;

      await tester.enterText(
          find.byKey(const Key('email_field')), 't@t.fr');
      await tester.enterText(
          find.byKey(const Key('password_field')), 'wrongpassword');
      await tester.tap(find.byKey(const Key('auth_submit_button')));
      await tester.pumpAndSettle();

      expect(find.text('Identifiants invalides'), findsOneWidget);
      expect(navigatedTo, isNull);
    });

    testWidgets('empty form does not submit (validators block)',
        (tester) async {
      await pump(tester, const AuthScreen(initialMode: 'signin'));

      await tester.tap(find.byKey(const Key('auth_submit_button')));
      await tester.pumpAndSettle();

      expect(_lastAuth!.signedInEmail, isNull);
      expect(navigatedTo, isNull);
    });
  });

  group('auth screen — sign up', () {
    testWidgets('sign-up mode shows the username field and calls signUp',
        (tester) async {
      await pump(tester, const AuthScreen(initialMode: 'signup'));

      await tester.enterText(
          find.byKey(const Key('username_field')), 'thomas');
      await tester.enterText(
          find.byKey(const Key('email_field')), 't@t.fr');
      await tester.enterText(
          find.byKey(const Key('password_field')), 'secret123');
      await tester.tap(find.byKey(const Key('auth_submit_button')));
      await tester.pumpAndSettle();

      expect(_lastAuth!.signedUpUsername, 'thomas');
      expect(navigatedTo, '/home');
    });
  });

  group('auth screen — password reset', () {
    testWidgets('forgot-password opens the dialog with email + send',
        (tester) async {
      await pump(tester, const AuthScreen(initialMode: 'signin'));

      await tester
          .tap(find.byKey(const ValueKey(WidgetKeys.authForgotPassword)));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey(WidgetKeys.authResetEmail)),
          findsOneWidget);
      expect(find.byKey(const ValueKey(WidgetKeys.authResetSend)),
          findsOneWidget);
    });
  });
}
