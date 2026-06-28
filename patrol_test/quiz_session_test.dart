import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'helpers/steps.dart';
import 'helpers/test_helpers.dart';

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

  // Voice quiz where every spoken answer is recognised correctly → the session
  // summary reports 100%.
  patrolTest('Voice quiz — all answers correct → 100%',
      timeout: const Timeout(Duration(minutes: 7)), ($) async {
    final app = Steps($);
    addTearDown(() => deleteListsByName($, _list));

    // Sign in and seed a list containing one word to study.
    await app.given.signedIn();
    await app.given.aListWithOneWord(name: _list, french: _fr, korean: _ko);
    // Recognition will return the correct word for each answer.
    await app.given.theLearnerWillAnswerCorrectly();

    // Open Start-a-session, pick the list, choose the Voice mode, and begin.
    await app.when.opensStartASession();
    await app.when.choosesList(_list);
    await app.when.choosesQuizType(Quiz.voice);
    await app.when.startsTheSession();
    // Tap the mic on every card to speak the answer.
    await app.when.answersEachCardByVoice();

    // The summary reports a perfect score.
    await app.then.sessionScoreIs(percent: 100);
  });

  // Voice quiz where every spoken answer is wrong → the session summary reports
  // 0%.
  patrolTest('Voice quiz — all answers wrong → 0%',
      timeout: const Timeout(Duration(minutes: 7)), ($) async {
    final app = Steps($);
    addTearDown(() => deleteListsByName($, _list));

    // Sign in and seed a list containing one word to study.
    await app.given.signedIn();
    await app.given.aListWithOneWord(name: _list, french: _fr, korean: _ko);
    // Recognition will return a wrong word for each answer.
    await app.given.theLearnerWillAnswerIncorrectly();

    // Open Start-a-session, pick the list, choose the Voice mode, and begin.
    await app.when.opensStartASession();
    await app.when.choosesList(_list);
    await app.when.choosesQuizType(Quiz.voice);
    await app.when.startsTheSession();
    // Tap the mic on every card; each is graded wrong.
    await app.when.answersEachCardByVoice();

    // The summary reports a zero score.
    await app.then.sessionScoreIs(percent: 0);
  });

  // Hands-free quiz: audio auto-plays, the app auto-listens and auto-advances
  // through every card on its own; with correct recognition the summary is 100%.
  patrolTest('Hands-free quiz — auto-completes at 100%',
      timeout: const Timeout(Duration(minutes: 8)), ($) async {
    final app = Steps($);
    addTearDown(() => deleteListsByName($, _list));

    // Sign in and seed a list containing one word to study.
    await app.given.signedIn();
    await app.given.aListWithOneWord(name: _list, french: _fr, korean: _ko);
    // Recognition will return the correct word for each auto-listened answer.
    await app.given.theLearnerWillAnswerCorrectly();

    // Open Start-a-session, pick the list, choose Hands-free, and begin.
    await app.when.opensStartASession();
    await app.when.choosesList(_list);
    await app.when.choosesQuizType(Quiz.handsFree);
    await app.when.startsTheSession();
    // No explicit answer step — hands-free answers every card itself; we just
    // wait for the summary.

    // The summary reports a perfect score.
    await app.then.sessionScoreIs(percent: 100);
  });
}
