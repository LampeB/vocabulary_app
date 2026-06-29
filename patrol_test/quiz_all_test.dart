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

import 'quiz_test.dart' as quiz;
import 'user_flows_test.dart' as user_flows;

// NOTE: navigation_test.dart is intentionally NOT included yet. Tapping into the
// Social/Profile/Stats screens performs GoRouter navigation that triggers
// "mid-layout Scaffold animation" assertions in Flutter's integration-test
// binding (same issue auth_test.dart documents) and aborts the whole run. It
// stays in the repo until the app's screen animations respect
// MediaQuery.disableAnimations under TEST_MODE. See docs/test-scenarios.md §4.0.

void main() {
  quiz.main();
  user_flows.main();
}
