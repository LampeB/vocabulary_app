import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:vocab_kr/main.dart' as app;
import 'package:vocab_kr/presentation/providers/auth/auth_provider.dart';
import 'helpers/test_helpers.dart';

// ---------------------------------------------------------------------------
// Navigates to the sign-up screen, signing out first if already authenticated.
// ---------------------------------------------------------------------------
Future<void> _launchAndGoToSignUp(PatrolIntegrationTester $) async {
  unawaited(app.main());
  await $.pump(const Duration(seconds: 4));
  await $.pump(const Duration(milliseconds: 500));

  // If already signed in, sign out via the provider so the router
  // redirects back to /welcome.
  if (!$(find.text('Commencer gratuitement')).exists) {
    try {
      final container = ProviderScope.containerOf(
        $.tester.element(find.byType(MaterialApp)),
      );
      await container.read(authStateProvider.notifier).signOut();
      await $.pump(const Duration(seconds: 2));
    } catch (_) {}
  }

  if ($(find.text('Commencer gratuitement')).exists) {
    await $(find.text('Commencer gratuitement')).tap();
    await $.pump(const Duration(milliseconds: 500));
  }
}

void main() {
  // ── Duplicate e-mail ───────────────────────────────────────────────────────

  patrolTest(
    'sign-up with already-used email shows French error',
    timeout: const Timeout(Duration(minutes: 2)),
    ($) async {
      await _launchAndGoToSignUp($);

      await $(find.byKey(const Key('username_field'))).enterText('brandnewuser99');
      await $(find.byKey(const Key('email_field'))).enterText(kTestEmail);
      await $(find.byKey(const Key('password_field'))).enterText('Password123!');
      await $(find.byKey(const Key('auth_submit_button'))).tap();

      // Allow time for the username pre-check + Supabase auth call.
      await $.pump(const Duration(seconds: 6));

      expect(
        $(find.text('Cette adresse e-mail est déjà utilisée.')),
        findsOneWidget,
      );
    },
  );

  // ── Duplicate username ─────────────────────────────────────────────────────

  patrolTest(
    'sign-up with already-used username shows French error',
    timeout: const Timeout(Duration(minutes: 2)),
    ($) async {
      await _launchAndGoToSignUp($);

      await $(find.byKey(const Key('username_field'))).enterText(kTestUsername);
      await $(find.byKey(const Key('email_field'))).enterText('notused_patrol@example.com');
      await $(find.byKey(const Key('password_field'))).enterText('Password123!');
      await $(find.byKey(const Key('auth_submit_button'))).tap();

      // The username pre-check is a single SELECT — should resolve quickly.
      await $.pump(const Duration(seconds: 6));

      expect(
        $(find.text('Ce pseudo est déjà utilisé.')),
        findsOneWidget,
      );
    },
  );
}
