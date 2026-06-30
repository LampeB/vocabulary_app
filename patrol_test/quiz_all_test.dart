// Umbrella entry point for the quiz E2E suite.
//
// Use this as --target so the patrol hook generates a test_bundle.dart that
// includes the quiz suite:
//
//   patrol test --target patrol_test/quiz_all_test.dart \
//               --dart-define-from-file=test.free.env.json
//
// The quiz scenarios now live in one consolidated file (quiz_test.dart) built on
// the given/when/then step library in helpers/steps.dart.

import 'auth_flows_test.dart' as auth_flows;
import 'navigation_test.dart' as navigation;
import 'quiz_test.dart' as quiz;
import 'user_flows_test.dart' as user_flows;

// All 18 scenarios run in ONE Patrol process. The instability that capped a
// process at ~10 tests came from relaunching app.main() every test; the harness
// now launches once and reuses the app (see launchAndSignIn), so the whole suite
// shares one app launch.

void main() {
  quiz.main();
  navigation.main();
  user_flows.main();
  auth_flows.main();
}
