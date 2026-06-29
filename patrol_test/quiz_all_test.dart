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

// Only the quiz suite runs in CI for now — the proven-stable set (short 3-card
// sessions). navigation_test.dart and user_flows_test.dart stay in the repo but
// are EXCLUDED: they (and any long >3-card session) trigger an intermittent
// "mid-layout Scaffold animation" assertion in Flutter's integration-test
// binding during GoRouter navigation / repeated feedback-flood animations,
// which aborts the whole run (the same issue auth_test.dart documents). The
// unblock is app-side: freeze the study/social animations when
// MediaQuery.disableAnimations is true. See docs/test-scenarios.md §4.0.

void main() {
  quiz.main();
}
