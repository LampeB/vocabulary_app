import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'helpers/test_helpers.dart';

const _listName = 'E2E Test List';
const _frWord = 'Bonjour';
const _koWord = '안녕하세요';

/// Opens Lists tab, deletes stale test lists, creates a fresh [_listName].
/// Leaves the user on the lists screen with [_listName] visible.
Future<void> _createFreshList(PatrolIntegrationTester $) async {
  await $(find.byIcon(Icons.bookmark_border)).tap();
  await $.pump(const Duration(milliseconds: 500));

  // Delete stale lists from this test AND from quiz tests that may have
  // failed to clean up (e.g. if their tearDown ran while Supabase was slow).
  await deleteListsByName($, _listName);
  await deleteListsByName($, 'E2E Quiz Test List');

  // 'Nouvelle liste' is the FAB label — always visible regardless of list
  // count.  'Créer une liste' only appears in the empty-state body and is
  // absent whenever there are stale lists from a previous test run.
  await $(find.text('Nouvelle liste')).waitUntilVisible(
    timeout: const Duration(seconds: 15),
  );
  await $(find.text('Nouvelle liste')).tap();
  await $.pump(const Duration(milliseconds: 300));
  await $(TextField).enterText(_listName);
  await $(find.text('Créer')).tap();

  await $(find.text(_listName)).waitUntilVisible(
    timeout: const Duration(seconds: 30),
  );
}

/// Adds a word [fr]/[ko] via the "Ajouter" dialog, waits for it to close.
Future<void> _addWord(
  PatrolIntegrationTester $,
  String fr,
  String ko,
) async {
  await $(find.text('Ajouter')).first.tap();
  await $.pump(const Duration(milliseconds: 500));

  await $(TextField).at(0).enterText(fr);
  await $(TextField).at(1).enterText(ko);

  await $(find.descendant(
    of: find.byType(AlertDialog),
    matching: find.text('Ajouter'),
  )).tap();

  // Poll until the dialog closes — fixed pump avoids pumpAndSettle hanging on
  // Supabase realtime stream emitting after the write commits.
  final deadline = DateTime.now().add(const Duration(seconds: 15));
  while (find.byType(AlertDialog).evaluate().isNotEmpty) {
    if (DateTime.now().isAfter(deadline)) {
      throw Exception('Timed out waiting for Add-Word dialog to close');
    }
    await $.pump(const Duration(milliseconds: 100));
  }
  await $.pump(const Duration(milliseconds: 500));
}

void main() {
  // ── Create list ───────────────────────────────────────────────────────────

  patrolTest('created list appears in Lists screen',
      timeout: const Timeout(Duration(minutes: 3)), ($) async {
    addTearDown(() => deleteListsByName($, _listName));
    await launchAndSignIn($);
    await _createFreshList($);

    expect($(find.text(_listName)), findsAtLeastNWidgets(1));
  });

  // ── Add word then verify it appears in the detail screen ─────────────────
  //
  // Regression test for the empty-detail bug:
  // list showed wordCount=10 in list view but detail screen showed nothing
  // because importFromJson wasn't wrapped in a transaction and variants
  // could be inserted outside the right scope.

  patrolTest('word added to list is visible in detail screen',
      timeout: const Timeout(Duration(minutes: 3)), ($) async {
    addTearDown(() => deleteListsByName($, _listName));
    await launchAndSignIn($);
    await _createFreshList($);

    // Open the list detail.
    await $(find.text(_listName)).tap();
    await $(find.text('Ajouter')).waitUntilVisible(
      timeout: const Duration(seconds: 15),
    );

    // Add a word.
    await _addWord($, _frWord, _koWord);

    // The word must now be visible — not "Aucun mot pour l'instant".
    expect($(find.text(_frWord)), findsAtLeastNWidgets(1));
    expect($(find.text(_koWord)), findsAtLeastNWidgets(1));
    expect($(find.text("Aucun mot pour l'instant")), findsNothing);
  });

  // ── Word count in list view matches words in detail ───────────────────────

  patrolTest('word count in list view matches words in detail',
      timeout: const Timeout(Duration(minutes: 3)), ($) async {
    addTearDown(() => deleteListsByName($, _listName));
    await launchAndSignIn($);
    await _createFreshList($);

    // Open detail and add a word.
    await $(find.text(_listName)).tap();
    await $(find.text('Ajouter')).waitUntilVisible(
      timeout: const Duration(seconds: 15),
    );
    await _addWord($, _frWord, _koWord);

    // On Samsung the soft keyboard can linger after the dialog closes, covering
    // the bottom nav bar and making bookmark_border unhittable.  5 s gives the
    // OS enough time to finish the keyboard-dismiss animation even on busy days.
    await $.pump(const Duration(seconds: 5));

    // Return to lists screen via the bottom nav.
    await $(find.byIcon(Icons.bookmark_border)).tap();

    // Wait for the list card to appear with updated word count.
    await $(find.text('1 mot')).waitUntilVisible(
      timeout: const Duration(seconds: 15),
    );
    expect($(find.text('1 mot')), findsOneWidget);
  });

  // ── Edit word ─────────────────────────────────────────────────────────────
  //
  // Tapping a word tile opens a pre-populated edit dialog ('Modifier le mot').
  // Saving with new text updates the tile in-place.

  patrolTest('tapping word tile opens pre-populated edit dialog and saves changes',
      timeout: const Timeout(Duration(minutes: 3)), ($) async {
    addTearDown(() => deleteListsByName($, _listName));
    await launchAndSignIn($);
    await _createFreshList($);

    await $(find.text(_listName)).tap();
    await $(find.text('Ajouter')).waitUntilVisible(
      timeout: const Duration(seconds: 15),
    );
    await _addWord($, _frWord, _koWord);

    // Tap the word tile (anywhere except the trash icon) to open the edit dialog.
    await $(find.text(_frWord)).tap();
    await $.pump(const Duration(milliseconds: 500));

    // Dialog title must be present.
    expect($(find.text('Modifier le mot')), findsOneWidget);

    // Replace the FR word with a new value.
    const newFrWord = 'Bonsoir';
    await $(TextField).at(0).enterText(newFrWord);

    // Save.
    await $(find.text('Enregistrer')).tap();

    // Wait for the dialog to close.
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (find.byType(AlertDialog).evaluate().isNotEmpty) {
      if (DateTime.now().isAfter(deadline)) {
        throw Exception('Edit dialog did not close after tapping Enregistrer');
      }
      await $.pump(const Duration(milliseconds: 100));
    }
    await $.pump(const Duration(milliseconds: 500));

    // Updated word is visible; old word is gone.
    expect($(find.text(newFrWord)), findsAtLeastNWidgets(1));
    expect($(find.text(_frWord)), findsNothing);
    // Korean word is unchanged.
    expect($(find.text(_koWord)), findsAtLeastNWidgets(1));
  });

  // ── Delete word via trash button + confirmation ───────────────────────────
  //
  // Tapping the trash icon shows a confirmation dialog ('Supprimer le mot ?').
  // Confirming removes the word tile from the list.

  patrolTest('trash button + confirmation deletes word from detail screen',
      timeout: const Timeout(Duration(minutes: 3)), ($) async {
    addTearDown(() => deleteListsByName($, _listName));
    await launchAndSignIn($);
    await _createFreshList($);

    await $(find.text(_listName)).tap();
    await $(find.text('Ajouter')).waitUntilVisible(
      timeout: const Duration(seconds: 15),
    );
    await _addWord($, _frWord, _koWord);

    // Verify the word is present before deletion.
    expect($(find.text(_frWord)), findsAtLeastNWidgets(1));

    // Tap the trash icon on the word tile.
    await $(find.byIcon(Icons.delete_outline)).first.tap();
    await $.pump(const Duration(milliseconds: 300));

    // Confirmation dialog must appear.
    expect($(find.text('Supprimer le mot ?')), findsOneWidget);

    // Tap the red 'Supprimer' button inside the dialog to confirm.
    await $(find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('Supprimer'),
    )).tap();

    await $.pump(const Duration(seconds: 1));

    // Word is gone; empty-state placeholder appears.
    expect($(find.text(_frWord)), findsNothing);
    expect($(find.text(_koWord)), findsNothing);
    expect($(find.text("Aucun mot pour l'instant")), findsOneWidget);
  });

  // ── Cancelling delete confirmation keeps the word ─────────────────────────

  patrolTest('cancelling delete confirmation keeps word in detail screen',
      timeout: const Timeout(Duration(minutes: 3)), ($) async {
    addTearDown(() => deleteListsByName($, _listName));
    await launchAndSignIn($);
    await _createFreshList($);

    await $(find.text(_listName)).tap();
    await $(find.text('Ajouter')).waitUntilVisible(
      timeout: const Duration(seconds: 15),
    );
    await _addWord($, _frWord, _koWord);

    // Tap trash icon.
    await $(find.byIcon(Icons.delete_outline)).first.tap();
    await $.pump(const Duration(milliseconds: 300));

    // Tap 'Annuler' — word must survive.
    await $(find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('Annuler'),
    )).tap();
    await $.pump(const Duration(milliseconds: 500));

    expect($(find.text(_frWord)), findsAtLeastNWidgets(1));
    expect($(find.text(_koWord)), findsAtLeastNWidgets(1));
  });
}
