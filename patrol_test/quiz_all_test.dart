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

import 'navigation_test.dart' as navigation;
import 'quiz_test.dart' as quiz;
import 'user_flows_test.dart' as user_flows;

// All three suites run in CI. The "navigation crash" was never a Scaffold/animation
// issue — it was a '/' in test names, which crashes the Android Test Orchestrator
// (it names a per-test output file after the description). Fixed by renaming.

void main() {
  quiz.main();
  navigation.main();
  user_flows.main();
}
