// Umbrella entry point for the quiz E2E suite.
//
// Use this as --target so the patrol hook generates a test_bundle.dart that
// includes the quiz suite:
//
//   patrol test --target patrol_test/quiz_all_test.dart \
//               --dart-define-from-file=test.accounts.env.json
//
// The quiz scenarios now live in one consolidated file (quiz_test.dart) built on
// the given/when/then step library in helpers/steps.dart.

import 'auth_flows_test.dart' as auth_flows;
import 'navigation_test.dart' as navigation;
import 'quiz_ecrire_test.dart' as quiz_ecrire;
import 'quiz_test.dart' as quiz;
import 'user_flows_test.dart' as user_flows;

// Each registered scenario requires a fresh Android Orchestrator process and
// uses its own account. CI runs individual suite files for bounded retries.

void main() {
  quiz.main();
  quiz_ecrire.main();
  navigation.main();
  user_flows.main();
  auth_flows.main();
}
