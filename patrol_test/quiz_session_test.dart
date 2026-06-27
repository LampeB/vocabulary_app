import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'helpers/steps.dart';
import 'helpers/test_helpers.dart';

// 'correct' → simulate a correct answer · 'wrong' → simulate wrong · '' → real STT
const _simulate = String.fromEnvironment('SIMULATE_SPEECH');

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

  patrolTest('Voice quiz — correct answer scores 100%',
      timeout: const Timeout(Duration(minutes: 7)), ($) async {
    if (_simulate != 'correct') return;
    addTearDown(() => deleteListsByName($, _list));
    final app = Steps($);

    await app.given.signedIn();
    await app.given.aListWithWord(name: _list, french: _fr, korean: _ko);

    await app.when.startsSession(list: _list, quiz: Quiz.voice);
    await app.when.completesSessionByVoice();

    await app.then.sessionScoreIs(percent: 100);
  });

  patrolTest('Voice quiz — wrong answer scores 0%',
      timeout: const Timeout(Duration(minutes: 7)), ($) async {
    if (_simulate != 'wrong') return;
    addTearDown(() => deleteListsByName($, _list));
    final app = Steps($);

    await app.given.signedIn();
    await app.given.aListWithWord(name: _list, french: _fr, korean: _ko);

    await app.when.startsSession(list: _list, quiz: Quiz.voice);
    await app.when.completesSessionByVoice();

    await app.then.sessionScoreIs(percent: 0);
  });

  patrolTest('Hands-free quiz — auto-completes at 100%',
      timeout: const Timeout(Duration(minutes: 8)), ($) async {
    if (_simulate != 'correct') return;
    addTearDown(() => deleteListsByName($, _list));
    final app = Steps($);

    await app.given.signedIn();
    await app.given.aListWithWord(name: _list, french: _fr, korean: _ko);

    // Hands-free auto-plays, auto-listens, and auto-advances every card — so
    // there's no explicit "answer" step; we just wait for the summary.
    await app.when.startsSession(list: _list, quiz: Quiz.handsFree);

    await app.then.sessionScoreIs(percent: 100);
  });
}
