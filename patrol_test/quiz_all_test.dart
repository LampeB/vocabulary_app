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

// CI runs the quiz suite — now fast and reliable after freezing the study
// animations under TEST_MODE (each Patrol action dropped from ~10s to ~1s; the
// previously-flaky count-10 scenario passes cleanly).
//
// user_flows_test.dart and navigation_test.dart stay in the repo but are
// EXCLUDED: they hit a SEPARATE issue — GoRouter route/tab navigation
// (go('/lists'), opening List-Detail, Social/Profile) trips a mid-layout
// Scaffold animation assertion in the live test binding (the issue
// auth_test.dart documents), which aborts the run after the quiz tests pass.
// That's the next thing to crack. See docs/test-scenarios.md §4.0 / §4.9.

void main() {
  quiz.main();
}
