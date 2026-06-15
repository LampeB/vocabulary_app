import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'helpers/test_helpers.dart';

// Compile-time mode injected via --dart-define-from-file.
// 'correct' → simulate saying the right word (default in all test env files).
// 'wrong'   → simulate saying a wrong word (use test.quiz.wrong.env.json).
// ''        → real speech recognition (no simulation).
const _simulate = String.fromEnvironment('SIMULATE_SPEECH');

const _listName = 'E2E Quiz Test List';
const _frWord = 'Bonjour';
const _koWord = '안녕하세요';

Future<void> _setupListAndStartQuiz(
  PatrolIntegrationTester $, {
  bool handsFree = false,
}) async {
  await $('Lists').tap();
  await $.pumpAndSettle();
  // Clear stale lists from both vocab and quiz tests (free quota = 3 lists).
  await deleteListsByName($, 'E2E Test List');
  await deleteListsByName($, _listName);

  await $(find.byIcon(Icons.add)).tap();
  await $.pumpAndSettle();
  await $(TextField).enterText(_listName);
  await $('Create').tap();

  // createList is fire-and-forget from Flutter's perspective (VoidCallback),
  // so pumpAndSettle() may return before the Supabase write resolves and
  // the Drift stream emits the new row.  Poll until the tile appears.
  await $(find.text(_listName)).waitUntilVisible(
    timeout: const Duration(seconds: 30),
  );
  await $(find.text(_listName)).tap();
  await $.pumpAndSettle();

  await $(find.text('Add Word')).tap();
  await $.pumpAndSettle();
  await $(TextField).at(0).enterText(_frWord);
  await $(TextField).at(1).enterText(_koWord);
  await $('Add').tap();
  // Poll until the Add Word dialog closes — only happens after
  // addConceptWithVariants() returns Success (concept + both variants committed).
  // barrierDismissible: false on the dialog prevents spurious barrier dismissals.
  final deadline = DateTime.now().add(const Duration(seconds: 15));
  while (find.byType(AlertDialog).evaluate().isNotEmpty) {
    if (DateTime.now().isAfter(deadline)) {
      throw Exception('Timed out waiting for Add Word dialog to close');
    }
    await $.pump(const Duration(milliseconds: 100));
  }
  await $.pumpAndSettle();

  await $(find.text('Start Study Session')).tap();
  await $.pumpAndSettle();

  await $(find.text(handsFree ? 'Hands-Free' : 'Voice')).tap();
  await $.pumpAndSettle();

  await $(find.text('Start Quiz')).tap();

  // In real mode, STT init triggers a mic-permission dialog. In sim mode
  // STT is skipped entirely so no dialog appears — guard it accordingly.
  if (_simulate.isEmpty && await $.platform.mobile.isPermissionDialogVisible()) {
    await $.platform.mobile.grantPermissionWhenInUse();
    await $.pumpAndSettle();
  }
}

void main() {
  // ── Voice quiz: correct answer → 100% ────────────────────────────────────
  //
  // Regression for the crash that happened when voice quiz started.
  // Simulate submits card.answerWords.first automatically.
  // The session should complete with 100% accuracy regardless of
  // how many cards are loaded (leftover from previous test runs).

  patrolTest('voice quiz: correct answer → session completes at 100%',
      timeout: const Timeout(Duration(minutes: 3)), ($) async {
    if (_simulate != 'correct') return;
    addTearDown(() => deleteListsByName($, _listName));

    await launchAndSignIn($);
    await _setupListAndStartQuiz($);

    // Wait for cards to load (STT init is skipped in sim mode, so the quiz
    // screen transitions from spinner to mic button quickly).
    await $(find.byKey(const Key('mic_button'))).waitUntilVisible(
      timeout: const Duration(seconds: 30),
    );
    await $(find.byKey(const Key('mic_button'))).tap();

    // Each card: 800ms simulate + 2000ms advance delay.
    // waitUntilVisible polls until the summary screen appears (up to 60s).
    await $(find.text('Session complete!')).waitUntilVisible(
      timeout: const Duration(seconds: 60),
    );

    expect($(find.text('100% accuracy')), findsOneWidget);
  });

  // ── Hands-free quiz: auto-starts and completes ────────────────────────────
  //
  // Hands-free auto-triggers _startListening 1500ms after each card loads.
  // Simulate answers immediately, advance delay is 1s (isDrivingMode=true).

  patrolTest('hands-free quiz: auto-starts and completes at 100%',
      timeout: const Timeout(Duration(minutes: 3)), ($) async {
    if (_simulate != 'correct') return;
    addTearDown(() => deleteListsByName($, _listName));

    await launchAndSignIn($);
    await _setupListAndStartQuiz($, handsFree: true);

    // No mic tap needed — hands-free triggers listening automatically.
    await $(find.text('Session complete!')).waitUntilVisible(
      timeout: const Duration(seconds: 60),
    );

    expect($(find.text('100% accuracy')), findsOneWidget);
  });

  // ── Voice quiz: wrong answer → 0% ────────────────────────────────────────
  //
  // Run with: patrol test -t patrol_test/quiz_session_test.dart \
  //           --dart-define-from-file=test.quiz.wrong.env.json -d emulator-5554
  //
  // Simulate submits '__wrong__' for every card → all answers incorrect.
  // Session should still complete (no crash) with 0% accuracy.

  patrolTest('voice quiz: wrong answer → session completes at 0%',
      timeout: const Timeout(Duration(minutes: 3)), ($) async {
    if (_simulate != 'wrong') return;
    addTearDown(() => deleteListsByName($, _listName));

    await launchAndSignIn($);
    await _setupListAndStartQuiz($);

    await $(find.byKey(const Key('mic_button'))).waitUntilVisible(
      timeout: const Duration(seconds: 30),
    );
    await $(find.byKey(const Key('mic_button'))).tap();

    await $(find.text('Session complete!')).waitUntilVisible(
      timeout: const Duration(seconds: 60),
    );

    expect($(find.text('0% accuracy')), findsOneWidget);
  });
}
