import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'helpers/steps.dart';
import 'helpers/test_helpers.dart';

// The Écrire (typing) half of the quiz suite — split from quiz_test.dart so no
// single patrol invocation runs more than ~6 tests: each per-test app spawn has
// a small chance of dying silently on the CI emulator, and shorter suites make
// a clean attempt (and cheap retries) far more likely. See
// docs/test-coverage-roadmap.md "umbrella run-level flakiness".

const _list = 'E2E Quiz Test List';
const _fr = 'Bonjour';
const _ko = '안녕하세요';

void main() {

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
  patrolTest('Écrire — chosen card count of 10 completes at 100%',
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
