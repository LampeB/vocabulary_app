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

// navigation_test.dart is still excluded pending one more verification round: it
// navigates into Social/Profile/Stats. The app's perpetual study animations
// (the quiz pulse) are now frozen under TEST_MODE, which should remove the
// binding flakiness; quiz + user_flows are re-enabled to confirm before adding
// navigation back. See docs/test-scenarios.md §4.0.

void main() {
  quiz.main();
  user_flows.main();
}
