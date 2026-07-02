import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'helpers/steps.dart';
import 'helpers/test_helpers.dart';

// The REAL email/password login flow, kept OUT of the main umbrella on purpose.
// The orchestrator crash was a '/' in the old name (fixed here to a '-'), but the
// test still does a LIVE Supabase sign-in on the network-constrained CI emulator,
// which frequently hangs and would destabilise the 20-test gate. Run it on its
// own as a login smoke check (it may need a retry):
//
//   gh workflow run e2e.yml -f target=patrol_test/auth_login_test.dart
//
// NOTE: no '/' in patrolTest descriptions — the orchestrator names a per-test
// output file after the description and a path separator crashes the run.
void main() {
  // Sign out to clear the session, then sign back in through the UI → Home.
  patrolTest('Auth — real email-password sign-in lands on Home',
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
