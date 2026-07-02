import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'helpers/steps.dart';
import 'helpers/test_helpers.dart';

// Auth flows beyond the existing sign-in test: sign-out and password reset.
// Sign-up validation is covered by unit tests; OAuth and reset-email *delivery*
// are device/manual-only (see docs/test-feasibility.md).
void main() {
  // Signing out from Profile returns to the Welcome screen.
  patrolTest('Auth — sign out returns to Welcome',
      timeout: const Timeout(Duration(minutes: 7)),
      config: kFastSettle, ($) async {
    final app = Steps($);
    addTearDown(() => deleteAllLists($));

    await app.given.signedIn();
    await app.when.signsOut();
    await app.then.onScreen(Screen.welcome);
  });

  // Requesting a password reset submits and the app shows a response. Neither
  // delivery nor success is asserted — Supabase rate-limits resets, so we only
  // prove the form → submit → response flow works.
  patrolTest('Auth — password reset request is handled',
      timeout: const Timeout(Duration(minutes: 7)),
      config: kFastSettle, ($) async {
    final app = Steps($);
    addTearDown(() => deleteAllLists($));

    await app.given.signedIn();
    await app.when.signsOut();
    await app.when.goesToSignIn();
    await app.when.requestsPasswordReset(kTestEmail);
    await app.then.passwordResetResponded();
  });
}
