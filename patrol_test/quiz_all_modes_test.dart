// Automated quiz test — all 4 modes, no user interaction required.
//
// Voice and hands-free modes use SIMULATE_SPEECH for fully automated answers.
// Flashcard and typing modes are always automated regardless of SIMULATE_SPEECH.
//
// Run correct-path tests (voice/hands-free answer correctly):
//   patrol test -t patrol_test/quiz_all_modes_test.dart \
//               --dart-define-from-file=test.free.env.json --device R3CT30RDT2H
//
// Run wrong-path tests (voice/hands-free answer wrongly):
//   patrol test -t patrol_test/quiz_all_modes_test.dart \
//               --dart-define-from-file=test.quiz.wrong.env.json --device R3CT30RDT2H

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'helpers/test_helpers.dart';

const _sim      = String.fromEnvironment('SIMULATE_SPEECH');
const _listName = 'Quiz Modes Test List';
const _fr       = 'Bonjour';
const _ko       = '안녕하세요';

// ── Helpers ──────────────────────────────────────────────────────────────────

Future<void> _addWord(PatrolIntegrationTester $, String fr, String ko) async {
  await $(find.text('Ajouter')).first.tap();
  await $.pump(const Duration(milliseconds: 500));
  await $(TextField).at(0).enterText(fr);
  await $(TextField).at(1).enterText(ko);
  await $(find.descendant(
    of: find.byType(AlertDialog),
    matching: find.text('Ajouter'),
  )).tap();
  final deadline = DateTime.now().add(const Duration(seconds: 15));
  while (find.byType(AlertDialog).evaluate().isNotEmpty) {
    if (DateTime.now().isAfter(deadline)) {
      throw Exception('Add-Word dialog did not close in time');
    }
    await $.pump(const Duration(milliseconds: 100));
  }
  await $.pump(const Duration(milliseconds: 500));
}

/// Navigate to Lists tab, delete any stale copy of [_listName], create a fresh
/// list with one word pair, and leave the app on the list-detail screen.
Future<void> _setupList(PatrolIntegrationTester $) async {
  await $(find.byIcon(Icons.bookmark_border)).tap();
  await $.pump(const Duration(milliseconds: 500));

  await deleteListsByName($, 'E2E Test List');
  await deleteListsByName($, _listName);

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
  await $(find.text(_listName)).tap();
  await $(find.text('Ajouter')).waitUntilVisible(
    timeout: const Duration(seconds: 15),
  );
  await _addWord($, _fr, _ko);
}

/// Tap "Démarrer" on the list detail → quiz setup → select [mode] (if not the
/// default 'Voix') → tap "Démarrer la session".
Future<void> _startQuizInMode(PatrolIntegrationTester $, String mode) async {
  await $(find.text('Démarrer')).tap();
  await $.pump(const Duration(seconds: 3));
  await $(find.text('Préparer la session')).waitUntilVisible(
    timeout: const Duration(seconds: 45),
  );
  // 'Voix' is the default mode and its isSelected overlay blocks taps — skip it.
  if (mode != 'Voix') {
    await $(find.text(mode)).tap();
  }
  await $(find.text('Démarrer la session')).scrollTo();
  await $(find.text('Démarrer la session')).tap();
  // Simulated tests bypass _stt.initialize(), so no permission dialog will appear.
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // ── 1. Flashcard: flip → Bien → 100% ────────────────────────────────────────
  patrolTest(
    'flashcard: flip card → rate Bien → 100%',
    timeout: const Timeout(Duration(minutes: 5)),
    ($) async {
      addTearDown(() => deleteListsByName($, _listName));
      await launchAndSignIn($);
      await _setupList($);
      await _startQuizInMode($, 'Cartes');

      // Tap the card (GestureDetector wrapping the question word) to flip it.
      await $(find.text(_fr)).waitUntilVisible(timeout: const Duration(seconds: 30));
      await $(find.text(_fr)).tap();

      // Rate as "good" → 100%
      await $(find.text('Bien')).waitUntilVisible(timeout: const Duration(seconds: 10));
      await $(find.text('Bien')).tap();

      await $(find.text('SESSION TERMINÉE')).waitUntilVisible(
        timeout: const Duration(seconds: 10),
      );
      expect($(find.text('100 %')), findsOneWidget);
    },
  );

  // ── 2. Flashcard: flip → Encore → 0% ────────────────────────────────────────
  patrolTest(
    'flashcard: flip card → rate Encore → 0%',
    timeout: const Timeout(Duration(minutes: 5)),
    ($) async {
      addTearDown(() => deleteListsByName($, _listName));
      await launchAndSignIn($);
      await _setupList($);
      await _startQuizInMode($, 'Cartes');

      await $(find.text(_fr)).waitUntilVisible(timeout: const Duration(seconds: 30));
      await $(find.text(_fr)).tap();

      // Rate as "again" → 0%
      await $(find.text('Encore')).waitUntilVisible(timeout: const Duration(seconds: 10));
      await $(find.text('Encore')).tap();

      await $(find.text('SESSION TERMINÉE')).waitUntilVisible(
        timeout: const Duration(seconds: 10),
      );
      expect($(find.text('0 %')), findsOneWidget);
    },
  );

  // ── 3. Typing: correct answer → 100% ────────────────────────────────────────
  patrolTest(
    'typing: correct answer → 100%',
    timeout: const Timeout(Duration(minutes: 5)),
    ($) async {
      addTearDown(() => deleteListsByName($, _listName));
      await launchAndSignIn($);
      await _setupList($);
      await _startQuizInMode($, 'Écrire');

      await $(find.byType(TextField)).waitUntilVisible(
        timeout: const Duration(seconds: 30),
      );
      await $(find.byType(TextField)).enterText(_ko);
      await $(find.byIcon(Icons.send_rounded)).tap();

      await $(find.text('Continuer')).waitUntilVisible(
        timeout: const Duration(seconds: 10),
      );
      await $(find.text('Continuer')).tap();

      await $(find.text('SESSION TERMINÉE')).waitUntilVisible(
        timeout: const Duration(seconds: 10),
      );
      expect($(find.text('100 %')), findsOneWidget);
    },
  );

  // ── 4. Typing: wrong answer → 0% ─────────────────────────────────────────────
  patrolTest(
    'typing: wrong answer → 0%',
    timeout: const Timeout(Duration(minutes: 5)),
    ($) async {
      addTearDown(() => deleteListsByName($, _listName));
      await launchAndSignIn($);
      await _setupList($);
      await _startQuizInMode($, 'Écrire');

      await $(find.byType(TextField)).waitUntilVisible(
        timeout: const Duration(seconds: 30),
      );
      await $(find.byType(TextField)).enterText('wrong answer');
      await $(find.byIcon(Icons.send_rounded)).tap();

      await $(find.text('Continuer')).waitUntilVisible(
        timeout: const Duration(seconds: 10),
      );
      await $(find.text('Continuer')).tap();

      await $(find.text('SESSION TERMINÉE')).waitUntilVisible(
        timeout: const Duration(seconds: 10),
      );
      expect($(find.text('0 %')), findsOneWidget);
    },
  );

  // ── 5. Voice: correct (sim) → 100% ──────────────────────────────────────────
  patrolTest(
    'voice: correct (sim) → 100%',
    timeout: const Timeout(Duration(minutes: 5)),
    ($) async {
      if (_sim != 'correct') return;
      addTearDown(() => deleteListsByName($, _listName));
      await launchAndSignIn($);
      await _setupList($);
      await _startQuizInMode($, 'Voix');

      await $(find.byKey(const Key('mic_button'))).waitUntilVisible(
        timeout: const Duration(seconds: 30),
      );
      await $(find.byKey(const Key('mic_button'))).tap();

      // Simulation fires automatically; feedback screen shows "Continuer".
      await $(find.text('Continuer')).waitUntilVisible(
        timeout: const Duration(seconds: 30),
      );
      await $(find.text('Continuer')).tap();

      await $(find.text('SESSION TERMINÉE')).waitUntilVisible(
        timeout: const Duration(seconds: 10),
      );
      expect($(find.text('100 %')), findsOneWidget);
    },
  );

  // ── 6. Voice: wrong (sim) → 0% ───────────────────────────────────────────────
  patrolTest(
    'voice: wrong (sim) → 0%',
    timeout: const Timeout(Duration(minutes: 5)),
    ($) async {
      if (_sim != 'wrong') return;
      addTearDown(() => deleteListsByName($, _listName));
      await launchAndSignIn($);
      await _setupList($);
      await _startQuizInMode($, 'Voix');

      await $(find.byKey(const Key('mic_button'))).waitUntilVisible(
        timeout: const Duration(seconds: 30),
      );
      await $(find.byKey(const Key('mic_button'))).tap();

      await $(find.text('Continuer')).waitUntilVisible(
        timeout: const Duration(seconds: 30),
      );
      await $(find.text('Continuer')).tap();

      await $(find.text('SESSION TERMINÉE')).waitUntilVisible(
        timeout: const Duration(seconds: 10),
      );
      expect($(find.text('0 %')), findsOneWidget);
    },
  );

  // ── 7. Hands-free: correct (sim) → auto-completes at 100% ───────────────────
  patrolTest(
    'hands-free: correct (sim) → 100%',
    timeout: const Timeout(Duration(minutes: 5)),
    ($) async {
      if (_sim != 'correct') return;
      addTearDown(() => deleteListsByName($, _listName));
      await launchAndSignIn($);
      await _setupList($);
      await _startQuizInMode($, 'Mains libres');

      // Hands-free auto-starts STT 1.5 s after card loads and auto-advances.
      await $(find.text('SESSION TERMINÉE')).waitUntilVisible(
        timeout: const Duration(seconds: 60),
      );
      expect($(find.text('100 %')), findsOneWidget);
    },
  );

  // ── 8. Hands-free: wrong (sim) → auto-completes at 0% ───────────────────────
  patrolTest(
    'hands-free: wrong (sim) → 0%',
    timeout: const Timeout(Duration(minutes: 5)),
    ($) async {
      if (_sim != 'wrong') return;
      addTearDown(() => deleteListsByName($, _listName));
      await launchAndSignIn($);
      await _setupList($);
      await _startQuizInMode($, 'Mains libres');

      await $(find.text('SESSION TERMINÉE')).waitUntilVisible(
        timeout: const Duration(seconds: 60),
      );
      expect($(find.text('0 %')), findsOneWidget);
    },
  );
}
