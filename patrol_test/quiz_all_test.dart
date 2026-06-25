// Umbrella entry point that bundles both test suites.
//
// Use this as --target so the patrol hook generates a test_bundle.dart that
// permanently includes both files without manual re-editing after each run:
//
//   patrol test --target patrol_test/quiz_all_test.dart \
//               --dart-define-from-file=test.free.env.json
//
// The hook regenerates test_bundle.dart based on --target, so pointing it here
// means it imports this file, which in turn imports both suites.

import 'quiz_session_test.dart' as quiz_session;
import 'quiz_modes_test.dart' as quiz_modes;

void main() {
  quiz_session.main();
  quiz_modes.main();
}
