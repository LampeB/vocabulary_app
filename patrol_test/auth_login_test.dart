import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'helpers/steps.dart';
import 'helpers/test_helpers.dart';

// The REAL email/password login flow, kept OUT of the main umbrella on purpose:
// it does a live network sign-out + sign-in (the flaky operation the injected
// TEST_SESSION removes for every other test), so running it inline destabilises
// the suite. Run it on its own for a login smoke check:
//
//   gh workflow run e2e.yml -f target=patrol_test/auth_login_test.dart
void main() {
  // Sign out to clear the session, then sign back in through the UI → Home.
  patrolTest('Auth — real email/password sign-in lands on Home',
      timeout: const Timeout(Duration(minutes: 7)),
      config: kFastSettle, ($) async {
    final app = Steps($);
    addTearDown(() => deleteAllLists($));

    await app.given.signedIn();
    await app.when.signsOut();
    await app.when.goesToSignIn();
    await app.when.signsInWith(kTestEmail, kTestPassword);
    await app.then.onScreen(Screen.home);
  });
}
