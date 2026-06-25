import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'helpers/test_helpers.dart';

const _listName = 'E2E Quiz Modes List';
const _frWord   = 'Bonjour';
const _koWord   = '안녕하세요';

// ── Shared helpers ────────────────────────────────────────────────────────────

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
      throw Exception('Timed out waiting for Add-Word dialog to close');
    }
    await $.pump(const Duration(milliseconds: 100));
  }
  await $.pump(const Duration(milliseconds: 500));
}

Future<void> _openOrCreateList(PatrolIntegrationTester $) async {
  await $(find.byIcon(Icons.bookmark_border)).tap();
  // Wait for the LISTES screen to fully load BEFORE calling deleteListsByName.
  // The lists provider is populated only after this screen renders; reading
  // it before the screen loads always returns [] and stale lists accumulate.
  await $(find.text('Nouvelle liste')).waitUntilVisible(
    timeout: const Duration(seconds: 15),
  );
  await deleteListsByName($, _listName);
  // Re-confirm the button is still visible after list deletions refresh the UI.
  await $(find.text('Nouvelle liste')).waitUntilVisible(
    timeout: const Duration(seconds: 10),
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
}

/// [mode]: 'voice' | 'flashcard' | 'typing' | 'handsFree'
Future<void> _startQuiz(
  PatrolIntegrationTester $, {
  String mode = 'voice',
  bool koToFr = false,
}) async {
  await $(find.text('Démarrer')).tap();
  await $.pump(const Duration(seconds: 3));
  await $(find.text('Préparer la session')).waitUntilVisible(
    timeout: const Duration(seconds: 45),
  );

  // Voice is already selected by default; other modes are tappable.
  switch (mode) {
    case 'flashcard': await $(find.text('Cartes')).tap();
    case 'typing':    await $(find.text('Écrire')).tap();
    case 'handsFree': await $(find.text('Mains libres')).tap();
  }
  if (koToFr) await $(find.text('KR → FR')).tap();

  await $(find.text('Démarrer la session')).scrollTo();
  await $(find.text('Démarrer la session')).tap();
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // ── Flashcard: flip + rate Bien → 100% ──────────────────────────────────────

  patrolTest(
    'flashcard: flip card and rate Bien → 100%',
    timeout: const Timeout(Duration(minutes: 5)),
    ($) async {
      addTearDown(() => deleteListsByName($, _listName));
      await launchAndSignIn($);
      await _openOrCreateList($);
      await _addWord($, _frWord, _koWord);
      await _startQuiz($, mode: 'flashcard');

      // Card front shown — hint text is the tap target for the flip gesture.
      await $(find.text('Appuyer pour révéler')).waitUntilVisible(
        timeout: const Duration(seconds: 15),
      );
      await $(find.text('Appuyer pour révéler')).tap();
      await $.pump(const Duration(milliseconds: 300));

      // Rating buttons appear after flip.
      await $(find.text('Bien')).waitUntilVisible(
        timeout: const Duration(seconds: 5),
      );
      await $(find.text('Bien')).tap();

      await $(find.text('SESSION TERMINÉE')).waitUntilVisible(
        timeout: const Duration(seconds: 10),
      );
      expect($(find.text('100 %')), findsOneWidget);
      expect($(find.text('1 / 1 corrects')), findsOneWidget);
    },
  );

  // ── Flashcard: rate Encore → 0% ─────────────────────────────────────────────

  patrolTest(
    'flashcard: rate Encore → 0%',
    timeout: const Timeout(Duration(minutes: 5)),
    ($) async {
      addTearDown(() => deleteListsByName($, _listName));
      await launchAndSignIn($);
      await _openOrCreateList($);
      await _addWord($, _frWord, _koWord);
      await _startQuiz($, mode: 'flashcard');

      await $(find.text('Appuyer pour révéler')).waitUntilVisible(
        timeout: const Duration(seconds: 15),
      );
      await $(find.text('Appuyer pour révéler')).tap();
      await $(find.text('Encore')).waitUntilVisible(
        timeout: const Duration(seconds: 5),
      );
      await $(find.text('Encore')).tap();

      await $(find.text('SESSION TERMINÉE')).waitUntilVisible(
        timeout: const Duration(seconds: 10),
      );
      expect($(find.text('0 %')), findsOneWidget);
      expect($(find.text('0 / 1 corrects')), findsOneWidget);
    },
  );

  // ── Flashcard: 3 cards, Bien/Encore/Bien → 67% ──────────────────────────────
  //
  // FsrsRating.good/easy → correct; FsrsRating.again/hard → not correct.
  // 2 correct out of 3 → (2/3 * 100).round() = 67.

  patrolTest(
    'flashcard: 3 cards mixed ratings → correct accuracy',
    timeout: const Timeout(Duration(minutes: 5)),
    ($) async {
      addTearDown(() => deleteListsByName($, _listName));
      await launchAndSignIn($);
      await _openOrCreateList($);
      await _addWord($, _frWord, _koWord);
      await _addWord($, 'Merci', '감사합니다');
      await _addWord($, 'Au revoir', '안녕히 가세요');
      await _startQuiz($, mode: 'flashcard');

      for (final rating in ['Bien', 'Encore', 'Bien']) {
        await $(find.text('Appuyer pour révéler')).waitUntilVisible(
          timeout: const Duration(seconds: 10),
        );
        await $(find.text('Appuyer pour révéler')).tap();
        await $(find.text(rating)).waitUntilVisible(
          timeout: const Duration(seconds: 5),
        );
        await $(find.text(rating)).tap();
        await $.pump(const Duration(milliseconds: 300));
      }

      await $(find.text('SESSION TERMINÉE')).waitUntilVisible(
        timeout: const Duration(seconds: 10),
      );
      expect($(find.text('67 %')), findsOneWidget);
      expect($(find.text('2 / 3 corrects')), findsOneWidget);
    },
  );

  // ── Typing: correct answer → JUSTE! → 100% ──────────────────────────────────

  patrolTest(
    'typing: correct answer → JUSTE! → 100%',
    timeout: const Timeout(Duration(minutes: 5)),
    ($) async {
      addTearDown(() => deleteListsByName($, _listName));
      await launchAndSignIn($);
      await _openOrCreateList($);
      await _addWord($, _frWord, _koWord);
      await _startQuiz($, mode: 'typing');

      // Wait for the send button — confirms the typing input has rendered.
      await $(find.byIcon(Icons.send_rounded)).waitUntilVisible(
        timeout: const Duration(seconds: 15),
      );
      await $(TextField).at(0).enterText(_koWord);
      await $(find.byIcon(Icons.send_rounded)).tap();

      // _AnswerFeedback screen appears for voice/typing after answering.
      await $(find.text('JUSTE !')).waitUntilVisible(
        timeout: const Duration(seconds: 5),
      );
      await $(find.text('Continuer')).tap();

      await $(find.text('SESSION TERMINÉE')).waitUntilVisible(
        timeout: const Duration(seconds: 10),
      );
      expect($(find.text('100 %')), findsOneWidget);
      expect($(find.text('1 / 1 corrects')), findsOneWidget);
    },
  );

  // ── Typing: wrong answer → À REVOIR → 0%, correct answer revealed ───────────

  patrolTest(
    'typing: wrong answer → À REVOIR → 0%',
    timeout: const Timeout(Duration(minutes: 5)),
    ($) async {
      addTearDown(() => deleteListsByName($, _listName));
      await launchAndSignIn($);
      await _openOrCreateList($);
      await _addWord($, _frWord, _koWord);
      await _startQuiz($, mode: 'typing');

      await $(find.byIcon(Icons.send_rounded)).waitUntilVisible(
        timeout: const Duration(seconds: 15),
      );
      await $(TextField).at(0).enterText('__wrong__');
      await $(find.byIcon(Icons.send_rounded)).tap();

      await $(find.text('À REVOIR')).waitUntilVisible(
        timeout: const Duration(seconds: 5),
      );
      // The correct answer is shown in the answer card on the feedback screen.
      expect($(find.text(_koWord)).evaluate(), isNotEmpty);
      await $(find.text('Continuer')).tap();

      await $(find.text('SESSION TERMINÉE')).waitUntilVisible(
        timeout: const Duration(seconds: 10),
      );
      expect($(find.text('0 %')), findsOneWidget);
      expect($(find.text('0 / 1 corrects')), findsOneWidget);
    },
  );

  // ── Typing: Continuer advances card and updates counter ──────────────────────
  //
  // Regression guard: _AnswerFeedback's Continuer button must call advance(),
  // move to the next card, and update the _ProgressHeader counter.

  patrolTest(
    'typing: Continuer advances to next card',
    timeout: const Timeout(Duration(minutes: 5)),
    ($) async {
      addTearDown(() => deleteListsByName($, _listName));
      await launchAndSignIn($);
      await _openOrCreateList($);
      await _addWord($, _frWord, _koWord);
      await _addWord($, 'Merci', '감사합니다');
      await _startQuiz($, mode: 'typing');

      // Answer card 1 correctly.
      await $(find.byIcon(Icons.send_rounded)).waitUntilVisible(
        timeout: const Duration(seconds: 15),
      );
      await $(TextField).at(0).enterText(_koWord);
      await $(find.byIcon(Icons.send_rounded)).tap();
      // Wait for _AnswerFeedback — counter shows regardless of verdict.
      // Card order is non-deterministic: if 'Merci' loads first, _koWord is
      // wrong → À REVOIR not JUSTE!; using the counter avoids that dependency.
      await $(find.text('01/02')).waitUntilVisible(
        timeout: const Duration(seconds: 10),
      );

      await $(find.text('Continuer')).tap();
      await $.pump(const Duration(milliseconds: 300));

      // Card 2 is now shown — header counter updates.
      await $(find.byIcon(Icons.send_rounded)).waitUntilVisible(
        timeout: const Duration(seconds: 5),
      );
      expect($(find.text('02/02')), findsOneWidget);
    },
  );

  // ── Flashcard: close button mid-quiz → home ─────────────────────────────────
  //
  // Tapping × before flipping or rating must call context.go('/home').
  // Covers the _ProgressHeader.onClose path in flashcard mode.

  patrolTest(
    'flashcard: close button mid-quiz → navigates home',
    timeout: const Timeout(Duration(minutes: 5)),
    ($) async {
      addTearDown(() => deleteListsByName($, _listName));
      await launchAndSignIn($);
      await _openOrCreateList($);
      await _addWord($, _frWord, _koWord);
      await _startQuiz($, mode: 'flashcard');

      await $(find.text('Appuyer pour révéler')).waitUntilVisible(
        timeout: const Duration(seconds: 15),
      );

      // Tap × without flipping or rating.
      await $(find.byIcon(Icons.close_rounded)).tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 5));

      expect(
        find.text('ACCUEIL').evaluate(),
        isNotEmpty,
        reason: 'Home nav not found after flashcard close',
      );
    },
  );

  // ── Typing: close button mid-quiz → home ────────────────────────────────────
  //
  // Tapping × before submitting an answer must navigate home.
  // Covers the _ProgressHeader.onClose path in typing mode.

  patrolTest(
    'typing: close button mid-quiz → navigates home',
    timeout: const Timeout(Duration(minutes: 5)),
    ($) async {
      addTearDown(() => deleteListsByName($, _listName));
      await launchAndSignIn($);
      await _openOrCreateList($);
      await _addWord($, _frWord, _koWord);
      await _startQuiz($, mode: 'typing');

      await $(find.byIcon(Icons.send_rounded)).waitUntilVisible(
        timeout: const Duration(seconds: 15),
      );

      // Tap × before submitting.
      await $(find.byIcon(Icons.close_rounded)).tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 5));

      expect(
        find.text('ACCUEIL').evaluate(),
        isNotEmpty,
        reason: 'Home nav not found after typing close',
      );
    },
  );

  // ── Voice: close from feedback screen → home ─────────────────────────────────
  //
  // After the simulated voice answer, _AnswerFeedback shows JUSTE!/À REVOIR
  // with its OWN _ProgressHeader × button.  That onClose path also calls
  // _stt.stopListening() + setListening(false) before context.go('/home').
  // This test verifies that path — distinct from tapping Continuer.

  patrolTest(
    'voice: close from feedback screen → navigates home',
    timeout: const Timeout(Duration(minutes: 5)),
    ($) async {
      addTearDown(() => deleteListsByName($, _listName));
      await launchAndSignIn($);
      await _openOrCreateList($);
      await _addWord($, _frWord, _koWord);
      await _startQuiz($); // voice mode (default)

      await $(find.byKey(const Key('mic_button'))).waitUntilVisible(
        timeout: const Duration(seconds: 30),
      );
      await $(find.byKey(const Key('mic_button'))).tap();

      // Simulate path fires after 800 ms — give 3 s for state update + rebuild.
      await $.pump(const Duration(seconds: 3));

      // _AnswerFeedback is now showing; tap its × instead of Continuer.
      await $(find.byIcon(Icons.close_rounded)).tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 5));

      expect(
        find.text('ACCUEIL').evaluate(),
        isNotEmpty,
        reason: 'Home nav not found after feedback-screen close',
      );
    },
  );

  // ── Quiz setup: back arrow → returns to list detail ──────────────────────────
  //
  // The AppBar leading arrow calls context.pop() — after tapping it the user
  // should land back on the list detail screen (Ajouter pill confirms it).

  patrolTest(
    'quiz setup: back arrow → returns to list detail',
    timeout: const Timeout(Duration(minutes: 5)),
    ($) async {
      addTearDown(() => deleteListsByName($, _listName));
      await launchAndSignIn($);
      await _openOrCreateList($);
      await _addWord($, _frWord, _koWord);

      // Navigate to quiz setup only.
      await $(find.text('Démarrer')).tap();
      await $.pump(const Duration(seconds: 3));
      await $(find.text('Préparer la session')).waitUntilVisible(
        timeout: const Duration(seconds: 45),
      );

      // Tap the AppBar back arrow.
      await $(find.byIcon(Icons.arrow_back_ios_new_rounded)).tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 5));

      // Ajouter pill is always visible on list detail — confirms we're back.
      expect(
        find.text('Ajouter').evaluate(),
        isNotEmpty,
        reason: 'List detail not found after quiz-setup back',
      );
    },
  );

  // ── Summary: Recommencer reloads the quiz ────────────────────────────────────
  //
  // After completing a session, Recommencer calls loadCards() again. Cards just
  // reviewed are not immediately due, so the quiz ends with 0/0 — but
  // crucially the screen stays in the quiz flow (not home).

  patrolTest(
    'summary: Recommencer reloads quiz session',
    timeout: const Timeout(Duration(minutes: 8)),
    ($) async {
      addTearDown(() => deleteListsByName($, _listName));
      await launchAndSignIn($);
      await _openOrCreateList($);
      await _addWord($, _frWord, _koWord);
      await _startQuiz($, mode: 'flashcard');

      // Complete the quiz.
      await $(find.text('Appuyer pour révéler')).waitUntilVisible(
        timeout: const Duration(seconds: 15),
      );
      await $(find.text('Appuyer pour révéler')).tap();
      await $(find.text('Bien')).waitUntilVisible(
        timeout: const Duration(seconds: 5),
      );
      await $(find.text('Bien')).tap();
      await $(find.text('SESSION TERMINÉE')).waitUntilVisible(
        timeout: const Duration(seconds: 10),
      );

      await $(find.text('Recommencer')).tap();

      // Patrol's tap() ends with pumpAndTrySettle which settles the widget tree
      // after loadCards() completes and the quiz card (or SESSION TERMINÉE)
      // renders. Check immediately — no extra waiting needed or possible (any
      // pump/Future.delayed after this point blocks indefinitely in the test
      // environment due to an unresolved interaction with the live binding).
      // Two valid outcomes: quiz card with 'Appuyer pour révéler', or an empty
      // session showing 'SESSION TERMINÉE' (0 cards — card just reviewed was
      // scheduled for a future date).
      final inQuizFlow = find.text('Appuyer pour révéler').evaluate().isNotEmpty ||
          find.text('SESSION TERMINÉE').evaluate().isNotEmpty;
      expect(inQuizFlow, isTrue,
          reason: 'Recommencer must reload the quiz, not navigate home');
    },
  );

  // ── Summary: Accueil navigates to home screen ────────────────────────────────

  patrolTest(
    'summary: Accueil navigates to home screen',
    timeout: const Timeout(Duration(minutes: 5)),
    ($) async {
      addTearDown(() => deleteListsByName($, _listName));
      await launchAndSignIn($);
      await _openOrCreateList($);
      await _addWord($, _frWord, _koWord);
      await _startQuiz($, mode: 'flashcard');

      await $(find.text('Appuyer pour révéler')).waitUntilVisible(
        timeout: const Duration(seconds: 15),
      );
      await $(find.text('Appuyer pour révéler')).tap();
      await $(find.text('Bien')).waitUntilVisible(
        timeout: const Duration(seconds: 5),
      );
      await $(find.text('Bien')).tap();
      await $(find.text('SESSION TERMINÉE')).waitUntilVisible(
        timeout: const Duration(seconds: 10),
      );

      await $(find.text('Accueil')).tap();
      // GoRouter navigation + transition animation; pumpAndSettle with timeout
      // is safe here (test mode, no long-running streams on the home screen).
      await $.pumpAndSettle(timeout: const Duration(seconds: 5));

      expect(
        find.text('ACCUEIL').evaluate(),
        isNotEmpty,
        reason: 'Home nav tab not found — Accueil button did not navigate home',
      );
    },
  );
}
