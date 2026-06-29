import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'helpers/steps.dart';
import 'helpers/test_helpers.dart';

// End-to-end *user flows* driven entirely through the real UI (no provider
// seeding). These exercise the management screens — create list, add/edit/delete
// words — and then a study session, the way a real learner would. Everything is
// selected by widget key, so locale/copy changes can't break them.

const _flowList = 'E2E Flow Test List';
const _studyList = 'E2E Flow Study List';

void main() {
  // The headline journey: connect → build & curate a list → start a quiz where a
  // value is chosen in EVERY section of the start screen.
  patrolTest(
      'Full flow — create a list, add-edit-delete words, then start a custom quiz',
      timeout: const Timeout(Duration(minutes: 9)),
      config: kFastSettle, ($) async {
    final app = Steps($);
    addTearDown(() => deleteAllLists($)); // leave a clean slate (even on failure)

    // ── Connect (and start from a clean slate so the list quota is free) ──────
    await app.given.signedIn();
    await app.given.aCleanSlate();

    // ── Create a list ─────────────────────────────────────────────────────────
    await app.when.tapsNavTab(NavTab.lists);
    await app.then.onScreen(Screen.lists);
    await app.when.createsList(_flowList);
    await app.then.seesText(_flowList);

    // ── Add words ─────────────────────────────────────────────────────────────
    await app.when.opensList(_flowList);
    await app.then.onScreen(Screen.listDetail);
    await app.when.addsWord('Bonjour', '안녕하세요');
    await app.when.addsWord('Merci', '감사합니다');
    await app.then.seesText('Bonjour');
    await app.then.seesText('Merci');

    // ── Edit one word ─────────────────────────────────────────────────────────
    await app.when.entersEditMode();
    await app.when.editsWord(fromFr: 'Bonjour', toFr: 'Bonsoir', toKo: '안녕하세요');
    await app.then.seesText('Bonsoir');
    await app.then.doesNotSeeText('Bonjour');

    // ── Delete one word ───────────────────────────────────────────────────────
    await app.when.deletesWord('Merci');
    await app.then.doesNotSeeText('Merci');
    await app.then.seesText('Bonsoir'); // the kept word survives

    // ── Leave the list screen ─────────────────────────────────────────────────
    await app.when.leavesListDetail();
    await app.then.onScreen(Screen.lists);

    // ── Start a quiz, choosing a value in every section ───────────────────────
    await app.when.opensStartASession();
    await app.then.onScreen(Screen.startSession);
    await app.when.choosesSessionType(); // section 0 — Vocabulaire
    await app.when.choosesList(_flowList); // section 1 — the list
    await app.when.choosesQuizType(Quiz.typing); // section 2 — Écrire
    await app.when.choosesDirection(Dir.koToFr); // section 3 — KO→FR
    await app.when.choosesCardCount(10); // section 4 — 10 cards
    await app.when.startsTheSession();

    // KO→FR → the expected answer is the French word; only 'Bonsoir' remains and
    // the 1-word list pads up to the chosen 10 cards.
    await app.when.typesCorrectAnswerForEachCard('Bonsoir');
    await app.then.sessionScoreIs(percent: 100);
  });

  // A second flow: a learner builds a one-word list in the UI and immediately
  // studies it with flashcards, grading every card "known" → 100%. Proves the
  // UI-built data flows straight into a study session.
  patrolTest('Flow — build a list in the UI, then study it with flashcards',
      timeout: const Timeout(Duration(minutes: 8)),
      config: kFastSettle, ($) async {
    final app = Steps($);
    addTearDown(() => deleteAllLists($)); // leave a clean slate (even on failure)

    await app.given.signedIn();
    await app.given.aCleanSlate();

    await app.when.tapsNavTab(NavTab.lists);
    await app.then.onScreen(Screen.lists);
    await app.when.createsList(_studyList);
    await app.when.opensList(_studyList);
    await app.when.addsWord('Pomme', '사과');
    await app.then.seesText('Pomme');

    await app.when.opensStartASession();
    await app.then.onScreen(Screen.startSession);
    await app.when.choosesList(_studyList);
    await app.when.choosesQuizType(Quiz.flashcard);
    await app.when.startsTheSession();
    await app.when.answersEachCardAsKnown();

    await app.then.sessionScoreIs(percent: 100);
  });
}
