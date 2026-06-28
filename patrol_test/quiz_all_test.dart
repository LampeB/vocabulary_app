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

void main() {
  quiz.main();
}
