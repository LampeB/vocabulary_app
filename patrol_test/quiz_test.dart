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
  // ART JIT warmup — MUST run first; absorbs the cold-JIT cost on Samsung S22 so
  // every later test starts on warm code. See test_helpers.warmupJitCache.
  patrolTest('warmup: prime ART JIT cache',
      timeout: const Timeout(Duration(minutes: 60)), ($) async {
    await warmupJitCache($);
  });

  // ── Voice ───────────────────────────────────────────────────────────────────

  // Voice quiz where every spoken answer is recognised correctly → 100%.
  patrolTest('Voice — all answers correct → 100%',
      timeout: const Timeout(Duration(minutes: 7)), ($) async {
    final app = Steps($);
    addTearDown(() => deleteListsByName($, _list));

    await app.given.signedIn();
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
      timeout: const Timeout(Duration(minutes: 7)), ($) async {
    final app = Steps($);
    addTearDown(() => deleteListsByName($, _list));

    await app.given.signedIn();
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
      timeout: const Timeout(Duration(minutes: 8)), ($) async {
    final app = Steps($);
    addTearDown(() => deleteListsByName($, _list));

    await app.given.signedIn();
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
      timeout: const Timeout(Duration(minutes: 7)), ($) async {
    final app = Steps($);
    addTearDown(() => deleteListsByName($, _list));

    await app.given.signedIn();
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
      timeout: const Timeout(Duration(minutes: 7)), ($) async {
    final app = Steps($);
    addTearDown(() => deleteListsByName($, _list));

    await app.given.signedIn();
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
      timeout: const Timeout(Duration(minutes: 7)), ($) async {
    final app = Steps($);
    addTearDown(() => deleteListsByName($, _list));

    await app.given.signedIn();
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
      timeout: const Timeout(Duration(minutes: 7)), ($) async {
    final app = Steps($);
    addTearDown(() => deleteListsByName($, _list));

    await app.given.signedIn();
    await app.given.aListWithOneWord(name: _list, french: _fr, korean: _ko);

    await app.when.opensStartASession();
    await app.when.choosesList(_list);
    await app.when.choosesQuizType(Quiz.typing);
    await app.when.startsTheSession();
    await app.when.typesWrongAnswerForEachCard();

    await app.then.sessionScoreIs(percent: 0);
  });
}
