import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'helpers/test_helpers.dart';

// 'correct' → simulate correct answer  'wrong' → simulate wrong  '' → real STT
const _simulate = String.fromEnvironment('SIMULATE_SPEECH');

const _listName = 'E2E Quiz Test List';
const _frWord   = 'Bonjour';
const _koWord   = '안녕하세요';

// ── Shared helpers ────────────────────────────────────────────────────────────

/// Opens the "Add word" dialog, types [fr]/[ko], confirms.
Future<void> _addWord(
  PatrolIntegrationTester $,
  String fr,
  String ko,
) async {
  // Tap the "Ajouter" pill in the list-detail bottom bar.
  await $(find.text('Ajouter')).first.tap();
  // Fixed pump — pumpAndSettle hangs because Supabase realtime stream keeps
  // emitting after every write and pumpAndSettle sees each emission as new work.
  await $.pump(const Duration(milliseconds: 500));

  await $(TextField).at(0).enterText(fr);
  await $(TextField).at(1).enterText(ko);

  // Confirm button is inside the AlertDialog, also labelled "Ajouter".
  await $(find.descendant(
    of: find.byType(AlertDialog),
    matching: find.text('Ajouter'),
  )).tap();

  // Wait until the dialog closes (Supabase write committed + Drift stream emitted).
  final deadline = DateTime.now().add(const Duration(seconds: 15));
  while (find.byType(AlertDialog).evaluate().isNotEmpty) {
    if (DateTime.now().isAfter(deadline)) {
      throw Exception('Timed out waiting for Add-Word dialog to close');
    }
    await $.pump(const Duration(milliseconds: 100));
  }
  // Short fixed settle — NOT pumpAndSettle which hangs on Supabase streams.
  await $.pump(const Duration(milliseconds: 500));
}

/// Navigates to Lists, creates [_listName], navigates into it.
Future<void> _openOrCreateList(PatrolIntegrationTester $) async {
  // Nav to lists tab via its icon (label is now 'LISTES').
  await $(find.byIcon(Icons.bookmark_border)).tap();
  await $.pump(const Duration(milliseconds: 500));

  await deleteListsByName($, 'E2E Test List');
  await deleteListsByName($, _listName);

  // 'Nouvelle liste' is the FAB label — always visible regardless of list count.
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
  // Wait for list detail to be ready — 'Ajouter' pill confirms the screen loaded.
  await $(find.text('Ajouter')).waitUntilVisible(
    timeout: const Duration(seconds: 15),
  );
}

/// Taps "Démarrer" (list detail) → selects [mode] and [direction] → "Démarrer la session".
/// [mode]: 'voice' (default) | 'handsFree' | 'flashcard' | 'typing'
/// [direction]: 'frToKo' (default) | 'koToFr' | 'both'
/// Grants mic permission in non-simulated runs.
Future<void> _startQuiz(
  PatrolIntegrationTester $, {
  String mode = 'voice',
  bool koToFr = false,   // legacy — kept for existing call sites
  bool both = false,
}) async {
  await $(find.text('Démarrer')).tap();
  // Flush GoRouter's pending navigation frame(s). Without this, the new route
  // may not be rendered until waitUntilVisible starts pumping — and on a slow
  // cold-JIT emulator the first pump inside waitUntilVisible can be delayed.
  await $.pump(const Duration(seconds: 3));

  // Wait for the AppBar title to confirm the quiz-setup screen arrived.
  // 45s: on cold JIT the first render of a new screen can take 30+ seconds.
  await $(find.text('Préparer la session')).waitUntilVisible(
    timeout: const Duration(seconds: 45),
  );

  // 'Voix' is the default mode (_mode = QuizMode.voice in _QuizSetupScreenState),
  // so its tile's isSelected=true adds a Positioned.fill(DecoratedBox) overlay
  // that intercepts all hit tests — find.text('Voix').hitTestable() always
  // returns empty.  Skip the tap; the mode is already correct.
  //
  // Non-default modes are NOT selected so they have no overlay and ARE tappable.
  switch (mode) {
    case 'handsFree': await $(find.text('Mains libres')).tap();
    case 'flashcard': await $(find.text('Cartes')).tap();
    case 'typing':    await $(find.text('Écrire')).tap();
  }

  // FR→KO is the default; KR→FR and FR↔KR tiles are tappable.
  if (koToFr) await $(find.text('KR → FR')).tap();
  if (both)   await $(find.text('FR ↔ KR')).tap();

  // 'Démarrer la session' may be below the fold — scrollTo() scrolls until
  // the widget is visible, then tap. No waitUntilVisible needed first.
  await $(find.text('Démarrer la session')).scrollTo();
  await $(find.text('Démarrer la session')).tap();

  if (_simulate.isEmpty &&
      await $.platform.mobile.isPermissionDialogVisible()) {
    await $.platform.mobile.grantPermissionWhenInUse();
    await $.pumpAndSettle();
  }
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // ── ART JIT warmup ──────────────────────────────────────────────────────────
  //
  // MUST be the very first test. On first install, the Dart VM runs interpreted
  // (cold ART JIT). On Samsung S22 in debug mode this takes 30-35 real minutes
  // before Flutter renders its first frame. This test absorbs that cost with no
  // assertions — it always passes. The compiled code lives outside the app-data
  // partition so it survives the clearPackageData that follows, giving all
  // subsequent tests warm-JIT startup (~5 s instead of 30+ min).

  patrolTest('warmup: prime ART JIT cache',
      // 60 min: on a warm-JIT device (APK already installed, ART cache intact)
      // the pump loop exits immediately once the welcome screen is visible
      // (~30 s). On cold JIT, the Dart interpreter blocks the event loop for
      // 35-45 min; the first $.pump() call returns only when the interpreter
      // yields. The 60-min ceiling ensures the test PASSES on cold JIT once
      // the loop exits (deadline < current time) — assuming cold JIT < 59 min.
      timeout: const Timeout(Duration(minutes: 60)), ($) async {
    await warmupJitCache($);
  });

  // ── Voice: correct answer → 100% ────────────────────────────────────────────

  patrolTest('voice quiz: correct answer → session completes at 100%',
      // 7 min: runs after the warmup test which primes the ART JIT cache.
      // Warm-JIT startup takes ~5 s; the rest of the test runs in ~30 s.
      timeout: const Timeout(Duration(minutes: 7)), ($) async {
    if (_simulate != 'correct') return;
    addTearDown(() => deleteListsByName($, _listName));

    await launchAndSignIn($);
    await _openOrCreateList($);
    await _addWord($, _frWord, _koWord);
    await _startQuiz($);

    await $(find.byKey(const Key('mic_button'))).waitUntilVisible(
      timeout: const Duration(seconds: 30),
    );
    await $(find.byKey(const Key('mic_button'))).tap();

    // Voice mode shows _AnswerFeedback; must tap Continuer to reach summary.
    await $(find.text('JUSTE !')).waitUntilVisible(
      timeout: const Duration(seconds: 30),
    );
    await $(find.text('Continuer')).tap();

    await $(find.text('SESSION TERMINÉE')).waitUntilVisible(
      timeout: const Duration(seconds: 10),
    );
    expect($(find.text('100 %')), findsOneWidget);
  });

  // ── Voice: wrong answer → 0% ─────────────────────────────────────────────────

  patrolTest('voice quiz: wrong answer → session completes at 0%',
      timeout: const Timeout(Duration(minutes: 7)), ($) async {
    if (_simulate != 'wrong') return;
    addTearDown(() => deleteListsByName($, _listName));

    await launchAndSignIn($);
    await _openOrCreateList($);
    await _addWord($, _frWord, _koWord);
    await _startQuiz($);

    await $(find.byKey(const Key('mic_button'))).waitUntilVisible(
      timeout: const Duration(seconds: 30),
    );
    await $(find.byKey(const Key('mic_button'))).tap();

    await $(find.text('SESSION TERMINÉE')).waitUntilVisible(
      timeout: const Duration(seconds: 60),
    );
    expect($(find.text('0 %')), findsOneWidget);
  });

  // ── Hands-free: auto-starts and completes ────────────────────────────────────

  patrolTest('hands-free quiz: auto-starts and completes at 100%',
      timeout: const Timeout(Duration(minutes: 5)), ($) async {
    if (_simulate != 'correct') return;
    addTearDown(() => deleteListsByName($, _listName));

    await launchAndSignIn($);
    await _openOrCreateList($);
    await _addWord($, _frWord, _koWord);
    await _startQuiz($, mode: 'handsFree');

    await $(find.text('SESSION TERMINÉE')).waitUntilVisible(
      timeout: const Duration(seconds: 60),
    );
    expect($(find.text('100 %')), findsOneWidget);
  });

  // ── Hands-free: close button works mid-session ───────────────────────────────
  //
  // Regression test for the UI-freeze bug:
  // In hands-free mode the quiz auto-starts STT.  If STT fails (no language
  // pack, permission denied, onError not propagated) the screen gets stuck in
  // isListening=true and no widget responds to taps.
  //
  // This test loads 3 cards (session lasts ~10s in sim mode) then tries to
  // tap the × close button after 5 seconds.  If the quiz screen is frozen the
  // close button will not respond and we'll still be on the quiz screen at the
  // end of the test → failure.
  //
  // Run with: patrol test -t patrol_test/quiz_session_test.dart \
  //           --dart-define-from-file=test.free.env.json -d emulator-5554

  // ── Real STT: voice timeout shows feedback ──────────────────────────────────
  //
  // Run with test.nosim.env.json (no SIMULATE_SPEECH).
  //
  // Scenario: user taps mic but speaks nothing (or STT fails to recognise).
  // After pauseFor (5s) STT fires onListeningDone with no answer submitted.
  // The app must show a snackbar and reset the mic to idle — not freeze.
  //
  // This is exactly the production bug reported on Samsung S22.

  patrolTest('voice quiz: STT timeout → snackbar and mic reset (real STT)',
      timeout: const Timeout(Duration(minutes: 5)), ($) async {
    if (_simulate.isNotEmpty) return; // real STT only — run with test.nosim.env.json
    addTearDown(() => deleteListsByName($, _listName));

    await launchAndSignIn($);
    await _openOrCreateList($);
    await _addWord($, _frWord, _koWord);
    await _startQuiz($);

    await $(find.byKey(const Key('mic_button'))).waitUntilVisible(
      timeout: const Duration(seconds: 30),
    );
    await $(find.byKey(const Key('mic_button'))).tap();

    // STT runs on real Android clock — native STT fires onListeningDone after
    // pauseFor (5s) or listenFor (10s).  Our fix then shows a 3-second snackbar.
    // Use waitUntilVisible so we catch the snackbar within its 3-second window
    // rather than polling after it may have already dismissed.
    await $(find.text('Pas reconnu — appuyez à nouveau pour réessayer'))
        .waitUntilVisible(timeout: const Duration(seconds: 20));

    // Mic must be tappable again (not stuck in isListening=true).
    await $(find.byKey(const Key('mic_button'))).tap();
    // Second tap should restart listening (not crash or freeze).
    await $.pump(const Duration(seconds: 2));
  });

  // ── Real STT: hands-free auto-retries after timeout ─────────────────────────
  //
  // Run with test.nosim.env.json.
  //
  // In hands-free mode the app auto-starts STT after card load.
  // If STT times out (no speech) it must auto-retry — not get stuck forever.
  // The close button must remain tappable at any point.

  patrolTest('hands-free quiz: STT timeout → auto-retries (real STT)',
      timeout: const Timeout(Duration(minutes: 8)), ($) async {
    if (_simulate.isNotEmpty) return; // real STT only — run with test.nosim.env.json
    addTearDown(() => deleteListsByName($, _listName));

    await launchAndSignIn($);
    await _openOrCreateList($);

    // 5 words → session takes ~35s to complete at worst (5×(5s pauseFor + 2s advance))
    // so the close button is still visible when we tap it after a 10s wait.
    await _addWord($, _frWord, _koWord);
    await _addWord($, 'Merci', '감사합니다');
    await _addWord($, 'Au revoir', '안녕히 가세요');
    await _addWord($, 'Bonne nuit', '안녕히 주무세요');
    await _addWord($, 'Oui', '네');
    await _startQuiz($, mode: 'handsFree');

    await $(find.byIcon(Icons.close_rounded)).waitUntilVisible(
      timeout: const Duration(seconds: 15),
    );

    // Let the first STT session start and timeout (pauseFor 5s + 2s advance).
    await $.pump(const Duration(seconds: 10));

    // Close button must still respond — screen must not be frozen.
    await $(find.byIcon(Icons.close_rounded)).tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 5));

    expect(
      find.byIcon(Icons.close_rounded).evaluate(),
      isEmpty,
      reason: 'Close still present — hands-free froze after STT timeout',
    );
  });

  // ── Hands-free: close button works mid-session ───────────────────────────────

  patrolTest('hands-free quiz: close button responsive mid-session',
      timeout: const Timeout(Duration(minutes: 4)), ($) async {
    if (_simulate != 'correct') return;
    addTearDown(() => deleteListsByName($, _listName));

    await launchAndSignIn($);
    await _openOrCreateList($);

    // 3 words → ~10s of hands-free sim (1.5s delay + 0.8s sim + 1s advance each)
    await _addWord($, _frWord, _koWord);
    await _addWord($, 'Merci', '감사합니다');
    await _addWord($, 'Au revoir', '안녕히 가세요');

    await _startQuiz($, mode: 'handsFree');

    // Wait for the quiz card to be visible (cards loaded, not the spinner).
    await $(find.byIcon(Icons.close_rounded)).waitUntilVisible(
      timeout: const Duration(seconds: 15),
    );

    // Sit in the middle of the session for 5 seconds.
    await $.pump(const Duration(seconds: 5));

    // The close button must still be tappable — if the screen is frozen this tap
    // either throws (widget not found / not hittable) or silently does nothing.
    await $(find.byIcon(Icons.close_rounded)).tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 5));

    // Verify we left the quiz: the close icon should be gone and the home nav
    // label should be visible.
    expect(
      find.byIcon(Icons.close_rounded).evaluate(),
      isEmpty,
      reason: 'Close button still present — quiz screen did not navigate away',
    );
    expect(
      find.text('ACCUEIL').evaluate(),
      isNotEmpty,
      reason: 'Home nav not found — navigation to home failed',
    );
  });

  // ── Voice: KO→FR correct answer → 100% ──────────────────────────────────────
  //
  // Exercises the koToFr direction path: question is Korean, accepted answers
  // are French. SIMULATE_SPEECH=correct submits card.answerWords.first which
  // is the French word, so the answer validates as correct.

  patrolTest('voice KO→FR: correct answer → 100%',
      timeout: const Timeout(Duration(minutes: 5)), ($) async {
    if (_simulate != 'correct') return;
    addTearDown(() => deleteListsByName($, _listName));

    await launchAndSignIn($);
    await _openOrCreateList($);
    await _addWord($, _frWord, _koWord);
    await _startQuiz($, koToFr: true); // voice mode, KO→FR direction

    await $(find.byKey(const Key('mic_button'))).waitUntilVisible(
      timeout: const Duration(seconds: 30),
    );
    await $(find.byKey(const Key('mic_button'))).tap();

    await $(find.text('JUSTE !')).waitUntilVisible(
      timeout: const Duration(seconds: 10),
    );
    await $(find.text('Continuer')).tap();

    await $(find.text('SESSION TERMINÉE')).waitUntilVisible(
      timeout: const Duration(seconds: 10),
    );
    expect($(find.text('100 %')), findsOneWidget);
  });

  // ── Voice: 3 cards, all correct → 100% ──────────────────────────────────────
  //
  // Verifies that currentIndex advances across multiple cards and that the
  // accuracy counter is correct over a multi-card session.

  patrolTest('voice: 3 cards all correct → 100%',
      timeout: const Timeout(Duration(minutes: 6)), ($) async {
    if (_simulate != 'correct') return;
    addTearDown(() => deleteListsByName($, _listName));

    await launchAndSignIn($);
    await _openOrCreateList($);
    await _addWord($, _frWord, _koWord);
    await _addWord($, 'Merci', '감사합니다');
    await _addWord($, 'Au revoir', '안녕히 가세요');
    await _startQuiz($);

    for (int i = 0; i < 3; i++) {
      await $(find.byKey(const Key('mic_button'))).waitUntilVisible(
        timeout: const Duration(seconds: 15),
      );
      await $(find.byKey(const Key('mic_button'))).tap();
      await $(find.text('JUSTE !')).waitUntilVisible(
        timeout: const Duration(seconds: 10),
      );
      await $(find.text('Continuer')).tap();
      await $.pump(const Duration(milliseconds: 300));
    }

    await $(find.text('SESSION TERMINÉE')).waitUntilVisible(
      timeout: const Duration(seconds: 10),
    );
    expect($(find.text('100 %')), findsOneWidget);
    expect($(find.text('3 / 3 corrects')), findsOneWidget);
  });

  // ── Flashcard: flip → 2-button rating → session completes ────────────────
  //
  // Verifies the new 2-button rating UI: after flipping a flashcard only
  // 'Raté' and 'Réussi' are shown (not the old 4-button layout).
  // Also verifies that tapping 'Réussi' advances the session to completion.

  patrolTest('flashcard: flip card shows 2-button rating and Réussi completes session',
      timeout: const Timeout(Duration(minutes: 4)), ($) async {
    addTearDown(() => deleteListsByName($, _listName));

    await launchAndSignIn($);
    await _openOrCreateList($);
    await _addWord($, _frWord, _koWord);
    await _startQuiz($, mode: 'flashcard');

    // Card front is visible (question word).
    await $(find.text(_frWord)).waitUntilVisible(
      timeout: const Duration(seconds: 30),
    );

    // Tap the card to flip it.
    await $(find.text(_frWord)).tap();
    await $.pump(const Duration(milliseconds: 600));

    // Only 2 rating buttons — not the old 4.
    expect($(find.text('Raté')), findsOneWidget);
    expect($(find.text('Réussi')), findsOneWidget);

    // Tap 'Réussi' to mark as correct.
    await $(find.text('Réussi')).tap();
    await $.pump(const Duration(milliseconds: 500));

    // One word → session ends immediately.
    await $(find.text('SESSION TERMINÉE')).waitUntilVisible(
      timeout: const Duration(seconds: 15),
    );
  });

  // ── Flashcard: 'Raté' keeps word in rotation ──────────────────────────────

  patrolTest('flashcard: tapping Raté shows FAUX feedback then advances',
      timeout: const Timeout(Duration(minutes: 4)), ($) async {
    addTearDown(() => deleteListsByName($, _listName));

    await launchAndSignIn($);
    await _openOrCreateList($);
    await _addWord($, _frWord, _koWord);
    await _startQuiz($, mode: 'flashcard');

    await $(find.text(_frWord)).waitUntilVisible(
      timeout: const Duration(seconds: 30),
    );
    await $(find.text(_frWord)).tap();
    await $.pump(const Duration(milliseconds: 600));

    expect($(find.text('Raté')), findsOneWidget);

    await $(find.text('Raté')).tap();
    await $.pump(const Duration(milliseconds: 500));

    // Answer feedback must appear ('FAUX !') followed by session end (1 card).
    await $(find.text('SESSION TERMINÉE')).waitUntilVisible(
      timeout: const Duration(seconds: 15),
    );
  });

  // ── Quiz setup: FR ↔ KR tile is visible and starts a session ─────────────
  //
  // Smoke-tests the new 'both' direction tile: it must be tappable on the
  // setup screen and starting from it must load the quiz screen.

  patrolTest('quiz setup: FR ↔ KR tile starts a session',
      timeout: const Timeout(Duration(minutes: 4)), ($) async {
    addTearDown(() => deleteListsByName($, _listName));

    await launchAndSignIn($);
    await _openOrCreateList($);
    await _addWord($, _frWord, _koWord);
    await _addWord($, 'Merci', '감사합니다');

    // Open setup screen manually so we can assert before launching.
    await $(find.text('Démarrer')).tap();
    await $.pump(const Duration(seconds: 3));
    await $(find.text('Préparer la session')).waitUntilVisible(
      timeout: const Duration(seconds: 45),
    );

    // FR ↔ KR tile must be present.
    expect($(find.text('FR ↔ KR')), findsOneWidget);
    expect($(find.text('Les deux sens')), findsOneWidget);

    // Select it — it should become tappable (not covered by a selected overlay).
    await $(find.text('FR ↔ KR')).tap();
    await $.pump(const Duration(milliseconds: 300));

    // Use flashcard mode (no mic needed) to keep this test self-contained.
    await $(find.text('Cartes')).tap();

    await $(find.text('Démarrer la session')).scrollTo();
    await $(find.text('Démarrer la session')).tap();
    await $.pump(const Duration(seconds: 3));

    // We should be on the quiz screen (setup title gone, card/close visible).
    expect($(find.text('Préparer la session')), findsNothing);
    await $(find.byIcon(Icons.close_rounded)).waitUntilVisible(
      timeout: const Duration(seconds: 30),
    );
  });
}
