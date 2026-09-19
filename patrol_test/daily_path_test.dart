import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'helpers/steps.dart';
import 'helpers/test_helpers.dart';

// Daily Path is guidance, not a gate: a learner can enter it, follow its
// suggested vocabulary list, or jump to the lessons hub from the same screen.

const _list = 'E2E Daily Path List';

void main() {
  patrolTest('Daily path — suggested vocabulary opens its seeded list',
      timeout: const Timeout(Duration(minutes: 7)),
      config: kFastSettle, ($) async {
    final app = Steps($);
    addTearDown(() => deleteAllLists($));

    await app.given.signedIn();
    await app.given.aCleanSlate();
    await app.given
        .aListWithOneWord(name: _list, french: 'bonjour', korean: '안녕');

    await app.when.opensDailyPath();
    await app.then.onScreen(Screen.dailyPath);
    await app.when.opensDailyPractice();
    await app.then.onScreen(Screen.listDetail);
    await app.then.seesText(_list);
  });

  patrolTest('Daily path — lessons entry opens the grammar hub',
      timeout: const Timeout(Duration(minutes: 7)),
      config: kFastSettle, ($) async {
    final app = Steps($);
    addTearDown(() => deleteAllLists($));

    await app.given.signedIn();
    await app.given.aCleanSlate();

    await app.when.opensDailyPath();
    await app.then.onScreen(Screen.dailyPath);
    await app.when.opensDailyLessons();
    await app.then.onScreen(Screen.grammar);
  });
}
