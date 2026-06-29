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

// CI runs the quiz suite (green, ~6 min). navigation_test + user_flows_test are
// renamed (the '/'-in-name orchestrator crash is fixed) and DO navigate fine —
// but they hang at the test boundary: this suite relaunches app.main() on every
// test (launchAndSignIn), which deadlocks when the next test relaunches. That's
// a test-harness fix to make, then re-add them here. See docs/test-scenarios §4.0.

void main() {
  quiz.main();
}
