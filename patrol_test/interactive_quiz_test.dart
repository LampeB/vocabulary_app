// Semi-interactive quiz tests — navigation fully automated, user speaks.
//
// voice quiz:      test taps mic each round and waits 12 s for you to speak.
// hands-free quiz: STT auto-starts; speak when you hear each word.
//                  If you don't speak, STT times out and advances automatically.
//
// Run with:
//   patrol test -t patrol_test/interactive_quiz_test.dart \
//               --dart-define-from-file=test.nosim.env.json \
//               --device R3CT30RDT2H

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'helpers/test_helpers.dart';

const _listName = 'Interactive Quiz Test';

// ── Helpers ───────────────────────────────────────────────────────────────────

Future<void> _hint(
  PatrolIntegrationTester $,
  String message,
  Color bg, {
  Duration display = const Duration(seconds: 11),
}) async {
  try {
    ScaffoldMessenger.of(
      $.tester.element(find.byType(MaterialApp).first),
    ).showSnackBar(SnackBar(
      content: Text(
        message,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      backgroundColor: bg,
      duration: display,
      behavior: SnackBarBehavior.floating,
    ));
    await $.pump(const Duration(milliseconds: 200));
  } catch (_) {}
}

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
  final deadline = DateTime.now().add(const Duration(seconds: 15));
  while (find.byType(AlertDialog).evaluate().isNotEmpty) {
    if (DateTime.now().isAfter(deadline)) {
      throw Exception('Add-Word dialog did not close in time');
    }
    await $.pump(const Duration(milliseconds: 100));
  }
  await $.pump(const Duration(milliseconds: 500));
}

/// Navigate to Lists, delete stale copy, create "Interactive Quiz Test" list,
/// add [_fr]/[_ko] word pairs, and leave the app on the list-detail screen.
Future<void> _setupListWithWords(PatrolIntegrationTester $) async {
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

  await _addWord($, 'Bonjour', '안녕하세요');
  await _addWord($, 'Merci', '감사합니다');
  await _addWord($, 'Au revoir', '안녕히 가세요');
}

// ── Tests ──────────────────────────────────────────────────────────────────────

void main() {
  // ── 1. Voice quiz — interactive ────────────────────────────────────────────
  //
  // The test taps the mic for each card and waits 12 s.
  // A dark-green banner "🎤 PARLE maintenant !" appears when it's your turn.
  patrolTest(
    'voice quiz — interactive: speak when prompted',
    timeout: const Timeout(Duration(minutes: 15)),
    ($) async {
      addTearDown(() => deleteListsByName($, _listName));

      // ── 1. Sign in ────────────────────────────────────────────────────────
      await launchAndSignIn($);

      // ── 2. Create list + add 3 words ──────────────────────────────────────
      await _setupListWithWords($);

      // ── 3. Start quiz in Voice mode (default) ────────────────────────────
      await $(find.text('Démarrer')).tap();
      await $.pump(const Duration(seconds: 3));
      await $(find.text('Préparer la session')).waitUntilVisible(
        timeout: const Duration(seconds: 45),
      );
      await $(find.text('Démarrer la session')).scrollTo();
      await $(find.text('Démarrer la session')).tap();

      // Give the quiz screen's initState postFrameCallback time to fire and
      // _stt.initialize() to request the RECORD_AUDIO permission before we check.
      await $.pump(const Duration(seconds: 3));
      if (await $.platform.mobile.isPermissionDialogVisible()) {
        await $.platform.mobile.grantPermissionWhenInUse();
        await $.pumpAndSettle();
      }

      // ── 4. Wait for first quiz card ────────────────────────────────────────
      await $(find.byKey(const Key('mic_button'))).waitUntilVisible(
        timeout: const Duration(seconds: 60),
      );

      // ── 5. Voice quiz loop ─────────────────────────────────────────────────
      for (var round = 0; round < 50; round++) {
        if ($(find.text('SESSION TERMINÉE')).exists) break;

        if ($(find.text('Continuer')).exists) {
          await $(find.text('Continuer')).tap();
          await $.pump(const Duration(seconds: 4));
          continue;
        }

        if ($(find.byKey(const Key('mic_button'))).exists) {
          await _hint(
            $,
            '🎤 PARLE maintenant ! 12 secondes…',
            const Color(0xFF1B7A6E),
            display: const Duration(seconds: 12),
          );
          await $(find.byKey(const Key('mic_button'))).tap();
          await $.pump(const Duration(seconds: 12));
          continue;
        }

        await $.pump(const Duration(seconds: 2));
      }

      // ── 6. Assert summary ─────────────────────────────────────────────────
      await $(find.text('SESSION TERMINÉE')).waitUntilVisible(
        timeout: const Duration(seconds: 10),
      );

      if ($(find.text('Accueil')).exists) {
        await $(find.text('Accueil')).tap();
        await $.pump(const Duration(seconds: 2));
      }
    },
  );

  // ── 2. Hands-free quiz — interactive ────────────────────────────────────────
  //
  // STT auto-starts 1.5 s after each card loads.
  // A banner prompts you to speak; if you don't, STT times out and advances.
  patrolTest(
    'hands-free quiz — interactive: speak when STT auto-starts',
    timeout: const Timeout(Duration(minutes: 10)),
    ($) async {
      addTearDown(() => deleteListsByName($, _listName));

      // ── 1. Sign in ────────────────────────────────────────────────────────
      await launchAndSignIn($);

      // ── 2. Create list + add 3 words ──────────────────────────────────────
      await _setupListWithWords($);

      // ── 3. Start quiz in Hands-free mode ─────────────────────────────────
      await $(find.text('Démarrer')).tap();
      await $.pump(const Duration(seconds: 3));
      await $(find.text('Préparer la session')).waitUntilVisible(
        timeout: const Duration(seconds: 45),
      );
      await $(find.text('Mains libres')).tap();
      await $(find.text('Démarrer la session')).scrollTo();
      await $(find.text('Démarrer la session')).tap();

      // Give STT time to request the RECORD_AUDIO permission.
      await $.pump(const Duration(seconds: 3));
      if (await $.platform.mobile.isPermissionDialogVisible()) {
        await $.platform.mobile.grantPermissionWhenInUse();
        await $.pumpAndSettle();
      }

      // ── 4. Wait for quiz card to load ─────────────────────────────────────
      await $(find.byKey(const Key('mic_button'))).waitUntilVisible(
        timeout: const Duration(seconds: 60),
      );

      // Show a persistent banner — STT auto-starts, no tap needed.
      await _hint(
        $,
        '🎤 MAINS LIBRES — parle dès que tu entends le mot !',
        const Color(0xFF1B4A6E),
        display: const Duration(seconds: 30),
      );

      // ── 5. Wait for auto-completion ───────────────────────────────────────
      // STT auto-starts 1.5 s after each card and auto-advances after answer
      // (or after STT timeout if you don't speak). 3 words × ~8 s = ~24 s worst case.
      await $(find.text('SESSION TERMINÉE')).waitUntilVisible(
        timeout: const Duration(minutes: 5),
      );

      if ($(find.text('Accueil')).exists) {
        await $(find.text('Accueil')).tap();
        await $.pump(const Duration(seconds: 2));
      }
    },
  );
}
