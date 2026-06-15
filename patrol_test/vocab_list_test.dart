import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'helpers/test_helpers.dart';

const _listName = 'E2E Test List';
const _frWord = 'Bonjour';
const _koWord = '안녕하세요';

void main() {
  // ── Create list ───────────────────────────────────────────────────────────

  patrolTest('created list appears in Lists screen',
      timeout: const Timeout(Duration(minutes: 2)), ($) async {
    addTearDown(() => deleteListsByName($, _listName));
    await launchAndSignIn($);

    await $('Lists').tap();
    await $.pumpAndSettle();
    await deleteListsByName($, _listName);

    await $(find.byIcon(Icons.add)).tap(); // FAB "New List"
    await $.pumpAndSettle();

    // Dialog has a TextField with labelText 'List name'.
    await $(TextField).enterText(_listName);
    await $('Create').tap();
    await $.pumpAndSettle();

    expect($(find.text(_listName)), findsAtLeastNWidgets(1));
  });

  // ── Add word then verify it appears in the detail screen ─────────────────
  //
  // Regression test for the empty-detail bug:
  // list showed wordCount=10 in list view but detail screen showed nothing
  // because importFromJson wasn't wrapped in a transaction and variants
  // could be inserted outside the right scope.

  patrolTest('word added to list is visible in detail screen',
      timeout: const Timeout(Duration(minutes: 2)), ($) async {
    addTearDown(() => deleteListsByName($, _listName));
    await launchAndSignIn($);

    // 1. Create a fresh list.
    await $('Lists').tap();
    await $.pumpAndSettle();
    await deleteListsByName($, _listName);

    await $(find.byIcon(Icons.add)).tap();
    await $.pumpAndSettle();
    await $(TextField).enterText(_listName);
    await $('Create').tap();
    await $.pumpAndSettle();

    // 2. Open list detail.
    await $(find.text(_listName)).tap();
    await $.pumpAndSettle();

    // 3. Add a word via the "Add Word" FAB.
    await $(find.text('Add Word')).tap();
    await $.pumpAndSettle();

    // Dialog has two TextFormFields: French and Korean.
    await $(TextField).at(0).enterText(_frWord);
    await $(TextField).at(1).enterText(_koWord);
    await $('Add').tap();
    await $.pumpAndSettle();

    // 4. The word must now be visible in the list — not "No words yet".
    expect($(find.text(_frWord)), findsAtLeastNWidgets(1));
    expect($(find.text(_koWord)), findsAtLeastNWidgets(1));
    expect($(find.text('No words yet')), findsNothing);
  });

  // ── Word count in list view matches words in detail ───────────────────────

  patrolTest('word count in list view matches words in detail',
      timeout: const Timeout(Duration(minutes: 2)), ($) async {
    addTearDown(() => deleteListsByName($, _listName));
    await launchAndSignIn($);

    await $('Lists').tap();
    await $.pumpAndSettle();

    // Create list.
    await deleteListsByName($, _listName);
    await $(find.byIcon(Icons.add)).tap();
    await $.pumpAndSettle();
    await $(TextField).enterText(_listName);
    await $('Create').tap();
    await $.pumpAndSettle();

    // Open detail and add a word.
    await $(find.text(_listName)).tap();
    await $.pumpAndSettle();

    await $(find.text('Add Word')).tap();
    await $.pumpAndSettle();
    await $(TextField).at(0).enterText(_frWord);
    await $(TextField).at(1).enterText(_koWord);
    await $('Add').tap();
    await $.pumpAndSettle();

    // Go back to lists screen via the bottom nav.
    await $('Lists').tap();
    await $.pumpAndSettle();

    // The list card must show '1 word' (not '0 words' or the wrong count).
    expect($(find.text('1 words')), findsOneWidget);
  });
}
