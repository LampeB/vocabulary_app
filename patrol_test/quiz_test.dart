import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'helpers/steps.dart';
import 'helpers/test_helpers.dart';

// One consolidated quiz E2E suite covering all four study modes. Voice and
// hands-free use the runtime STT simulator (given.theLearnerWillAnswer…);
// Cartes self-grades and Écrire types, so they don't need it.

const _list = 'E2E Quiz Test List';
const _fr = 'Bonjour';
const _ko = '안녕하세요';

void main() {
  // (No ART-JIT warmup test: that was a physical Samsung-S22 hack. On the x86_64
  // CI emulator there's no cold-JIT penalty, and the warmup's wait-for-welcome
  // loop would otherwise burn the whole job budget.)

  // ── Voice ───────────────────────────────────────────────────────────────────

  // Voice quiz where every spoken answer is recognised correctly → 100%.
  patrolTest('Voice — all answers correct → 100%',
      timeout: const Timeout(Duration(minutes: 7)),
      config: kFastSettle, ($) async {
    final app = Steps($);
    addTearDown(() => deleteAllLists($)); // leave a clean slate (even on failure)

    await app.given.signedIn();
    await app.given.aCleanSlate(); // start from a clean slate
    await app.given.aListWithOneWord(name: _list, french: _fr, korean: _ko);
    await app.given.theLearnerWillAnswerCorrectly();

    await app.when.opensStartASession();
    await app.when.choosesList(_list);
    await app.when.choosesQuizType(Quiz.voice);
    await app.when.startsTheSession();
    await app.when.answersEachCardByVoice();

    await app.then.sessionScoreIs(percent: 100);
  });

  // Voice quiz where every spoken answer is wrong → 0%.
  patrolTest('Voice — all answers wrong → 0%',
      timeout: const Timeout(Duration(minutes: 7)),
      config: kFastSettle, ($) async {
    final app = Steps($);
    addTearDown(() => deleteAllLists($)); // leave a clean slate (even on failure)

    await app.given.signedIn();
    await app.given.aCleanSlate(); // start from a clean slate
    await app.given.aListWithOneWord(name: _list, french: _fr, korean: _ko);
    await app.given.theLearnerWillAnswerIncorrectly();

    await app.when.opensStartASession();
    await app.when.choosesList(_list);
    await app.when.choosesQuizType(Quiz.voice);
    await app.when.startsTheSession();
    await app.when.answersEachCardByVoice();

    await app.then.sessionScoreIs(percent: 0);
  });

  // ── Hands-free ────────────────────────────────────────────────────────────────

  // Hands-free auto-plays, auto-listens and auto-advances every card on its own;
  // with correct recognition the summary is 100%.
  patrolTest('Hands-free — auto-completes at 100%',
      timeout: const Timeout(Duration(minutes: 8)),
      config: kFastSettle, ($) async {
    final app = Steps($);
    addTearDown(() => deleteAllLists($)); // leave a clean slate (even on failure)

    await app.given.signedIn();
    await app.given.aCleanSlate(); // start from a clean slate
    await app.given.aListWithOneWord(name: _list, french: _fr, korean: _ko);
    await app.given.theLearnerWillAnswerCorrectly();

    await app.when.opensStartASession();
    await app.when.choosesList(_list);
    await app.when.choosesQuizType(Quiz.handsFree);
    await app.when.startsTheSession();
    // No answer step — hands-free answers every card itself.

    await app.then.sessionScoreIs(percent: 100);
  });

  // ── Cartes (flashcards, self-graded) ──────────────────────────────────────────

  // Flip each card and self-grade "Je savais" → 100%.
  patrolTest('Cartes — all known → 100%',
      timeout: const Timeout(Duration(minutes: 7)),
      config: kFastSettle, ($) async {
    final app = Steps($);
    addTearDown(() => deleteAllLists($)); // leave a clean slate (even on failure)

    await app.given.signedIn();
    await app.given.aCleanSlate(); // start from a clean slate
    await app.given.aListWithOneWord(name: _list, french: _fr, korean: _ko);

    await app.when.opensStartASession();
    await app.when.choosesList(_list);
    await app.when.choosesQuizType(Quiz.flashcard);
    await app.when.startsTheSession();
    await app.when.answersEachCardAsKnown();

    await app.then.sessionScoreIs(percent: 100);
  });

  // Flip each card and self-grade "À revoir" → 0%.
  patrolTest('Cartes — all forgotten → 0%',
      timeout: const Timeout(Duration(minutes: 7)),
      config: kFastSettle, ($) async {
    final app = Steps($);
    addTearDown(() => deleteAllLists($)); // leave a clean slate (even on failure)

    await app.given.signedIn();
    await app.given.aCleanSlate(); // start from a clean slate
    await app.given.aListWithOneWord(name: _list, french: _fr, korean: _ko);

    await app.when.opensStartASession();
    await app.when.choosesList(_list);
    await app.when.choosesQuizType(Quiz.flashcard);
    await app.when.startsTheSession();
    await app.when.answersEachCardAsForgotten();

    await app.then.sessionScoreIs(percent: 0);
  });

  // ── Écrire (typing) ───────────────────────────────────────────────────────────

  // Type the correct Korean word on every card → 100%.
  patrolTest('Écrire — correct typed answer → 100%',
      timeout: const Timeout(Duration(minutes: 7)),
      config: kFastSettle, ($) async {
    final app = Steps($);
    addTearDown(() => deleteAllLists($)); // leave a clean slate (even on failure)

    await app.given.signedIn();
    await app.given.aCleanSlate(); // start from a clean slate
    await app.given.aListWithOneWord(name: _list, french: _fr, korean: _ko);

    await app.when.opensStartASession();
    await app.when.choosesList(_list);
    await app.when.choosesQuizType(Quiz.typing);
    await app.when.startsTheSession();
    // FR→KR (default), so the expected answer is the Korean word.
    await app.when.typesCorrectAnswerForEachCard(_ko);

    await app.then.sessionScoreIs(percent: 100);
  });

  // Type a wrong answer on every card → 0%.
  patrolTest('Écrire — wrong typed answer → 0%',
      timeout: const Timeout(Duration(minutes: 7)),
      config: kFastSettle, ($) async {
    final app = Steps($);
    addTearDown(() => deleteAllLists($)); // leave a clean slate (even on failure)

    await app.given.signedIn();
    await app.given.aCleanSlate(); // start from a clean slate
    await app.given.aListWithOneWord(name: _list, french: _fr, korean: _ko);

    await app.when.opensStartASession();
    await app.when.choosesList(_list);
    await app.when.choosesQuizType(Quiz.typing);
    await app.when.startsTheSession();
    await app.when.typesWrongAnswerForEachCard();

    await app.then.sessionScoreIs(percent: 0);
  });

  // ── Direction (KO→FR) ─────────────────────────────────────────────────────────

  // Reverse direction: the question is Korean and the expected answer is French.
  // Typing the correct French word on every card → 100%. Proves direction
  // selection routes through to validation (the default is FR→KO).
  patrolTest('Écrire KO→FR — correct French answer → 100%',
      timeout: const Timeout(Duration(minutes: 7)),
      config: kFastSettle, ($) async {
    final app = Steps($);
    addTearDown(() => deleteAllLists($)); // leave a clean slate (even on failure)

    await app.given.signedIn();
    await app.given.aCleanSlate(); // start from a clean slate
    await app.given.aListWithOneWord(name: _list, french: _fr, korean: _ko);

    await app.when.opensStartASession();
    await app.when.choosesList(_list);
    await app.when.choosesQuizType(Quiz.typing);
    await app.when.choosesDirection(Dir.koToFr);
    await app.when.startsTheSession();
    await app.when.typesCorrectAnswerForEachCard(_fr);

    await app.then.sessionScoreIs(percent: 100);
  });

  // ── Per-card verdict flood ────────────────────────────────────────────────────

  // A correct typed answer flashes the correct (teal) verdict on that card.
  patrolTest('Écrire — correct answer shows the correct verdict',
      timeout: const Timeout(Duration(minutes: 7)),
      config: kFastSettle, ($) async {
    final app = Steps($);
    addTearDown(() => deleteAllLists($)); // leave a clean slate (even on failure)

    await app.given.signedIn();
    await app.given.aCleanSlate(); // start from a clean slate
    await app.given.aListWithOneWord(name: _list, french: _fr, korean: _ko);

    await app.when.opensStartASession();
    await app.when.choosesList(_list);
    await app.when.choosesQuizType(Quiz.typing);
    await app.when.startsTheSession();
    await app.when.typesAnswerForOneCard(_ko); // FR→KR default → Korean answer

    await app.then.verdictIsCorrect();
  });

  // A wrong typed answer flashes the wrong (orange) verdict on that card.
  patrolTest('Écrire — wrong answer shows the wrong verdict',
      timeout: const Timeout(Duration(minutes: 7)),
      config: kFastSettle, ($) async {
    final app = Steps($);
    addTearDown(() => deleteAllLists($)); // leave a clean slate (even on failure)

    await app.given.signedIn();
    await app.given.aCleanSlate(); // start from a clean slate
    await app.given.aListWithOneWord(name: _list, french: _fr, korean: _ko);

    await app.when.opensStartASession();
    await app.when.choosesList(_list);
    await app.when.choosesQuizType(Quiz.typing);
    await app.when.startsTheSession();
    await app.when.typesAnswerForOneCard('___nope___');

    await app.then.verdictIsWrong();
  });

  // ── Card count ────────────────────────────────────────────────────────────────

  // Choosing a card count (10) drives a 10-card session that still completes;
  // the one-word list pads up to 10 and every correct answer → 100%.
  // SKIPPED: a 10-card session runs the feedback-flood animation ~10× and
  // intermittently trips a mid-layout Scaffold animation assertion in the
  // integration-test binding, aborting the run. Re-enable once the study
  // animations freeze under MediaQuery.disableAnimations. See test-scenarios §4.0.
  patrolTest('Écrire — chosen card count of 10 completes at 100%',
      skip: true,
      timeout: const Timeout(Duration(minutes: 8)),
      config: kFastSettle, ($) async {
    final app = Steps($);
    addTearDown(() => deleteAllLists($)); // leave a clean slate (even on failure)

    await app.given.signedIn();
    await app.given.aCleanSlate(); // start from a clean slate
    await app.given.aListWithOneWord(name: _list, french: _fr, korean: _ko);

    await app.when.opensStartASession();
    await app.when.choosesList(_list);
    await app.when.choosesQuizType(Quiz.typing);
    await app.when.choosesDirection(Dir.frToKo); // advances accordion to count
    await app.when.choosesCardCount(10);
    await app.when.startsTheSession();
    await app.when.typesCorrectAnswerForEachCard(_ko);

    await app.then.sessionScoreIs(percent: 100);
  });
}
