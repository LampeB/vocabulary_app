import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'helpers/steps.dart';
import 'helpers/test_helpers.dart';

// These are bundled curriculum identities, deliberately not localized names.
// The rule has two prerequisites, which lets this suite prove that a third,
// unrelated starter list cannot affect its availability.
const _ruleId = 'particules-sujet-objet-i-ga-eul-reul';
const _prerequisites = ['starter-greetings', 'starter-food'];
const _unrelatedList = 'starter-daily-life';

void main() {
  patrolTest(
      'Lessons — unrelated vocabulary does not unlock a locked prerequisite lesson',
      timeout: const Timeout(Duration(minutes: 8)),
      config: kFastSettle, ($) async {
    final app = Steps($);
    addTearDown(() => deleteAllLists($));

    await app.given.signedIn();
    await app.given.theFrenchKoreanStarterCurriculum();
    await app.given.theStarterListIsKnown(_unrelatedList);

    // A completed C list must not compensate for missing A and B.
    await app.when.tapsNavTab(NavTab.grammar);
    await app.then.grammarRuleIsLocked(_ruleId);

    // The locked card points specifically to a prerequisite list, not C.
    await app.when
        .opensGrammarPrerequisite(ruleId: _ruleId, token: _prerequisites.first);
    await app.then.onScreen(Screen.listDetail);
  });

  patrolTest(
      'Lessons — graduated required vocabulary unlocks and opens the real lesson',
      timeout: const Timeout(Duration(minutes: 8)),
      config: kFastSettle, ($) async {
    final app = Steps($);
    addTearDown(() => deleteAllLists($));

    await app.given.signedIn();
    await app.given.theFrenchKoreanStarterCurriculum();
    for (final token in _prerequisites) {
      await app.given.theStarterListIsKnown(token);
    }

    await app.when.tapsNavTab(NavTab.grammar);
    await app.when.opensGrammarLesson(_ruleId);
    await app.then.onScreen(Screen.grammarLesson);
  });
}
