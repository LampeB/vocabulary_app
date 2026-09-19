import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'helpers/steps.dart';
import 'helpers/test_helpers.dart';

// The V0 supports three first-class learning routes. These tests exercise the
// actual pair selection and answer direction, not merely a reverse card inside
// the default French → Korean route.
const _englishKorean = 'E2E English Korean';
const _koreanFrench = 'E2E Korean French';

void main() {
  patrolTest('Language pairs — English to Korean list studies forward',
      timeout: const Timeout(Duration(minutes: 7)),
      config: kFastSettle, ($) async {
    final app = Steps($);
    addTearDown(() => deleteAllLists($));

    await app.given.signedIn();
    await app.given.aCleanSlate();
    await app.given.aListWithOneWord(
      name: _englishKorean,
      french: 'hello',
      korean: '안녕하세요',
      langA: 'en',
      langB: 'ko',
    );

    await app.when.opensStartASession();
    await app.when.choosesLanguagePair('en', 'ko');
    await app.when.choosesList(_englishKorean);
    await app.when.choosesQuizType(Quiz.typing);
    await app.when.startsTheSession();
    await app.when.typesCorrectAnswerForEachCard('안녕하세요');

    await app.then.sessionScoreIs(percent: 100);
  });

  patrolTest('Language pairs — Korean to French list studies forward',
      timeout: const Timeout(Duration(minutes: 7)),
      config: kFastSettle, ($) async {
    final app = Steps($);
    addTearDown(() => deleteAllLists($));

    await app.given.signedIn();
    await app.given.aCleanSlate();
    await app.given.aListWithOneWord(
      name: _koreanFrench,
      french: '안녕하세요',
      korean: 'bonjour',
      langA: 'ko',
      langB: 'fr',
    );

    await app.when.opensStartASession();
    await app.when.choosesLanguagePair('ko', 'fr');
    await app.when.choosesList(_koreanFrench);
    await app.when.choosesQuizType(Quiz.typing);
    await app.when.startsTheSession();
    await app.when.typesCorrectAnswerForEachCard('bonjour');

    await app.then.sessionScoreIs(percent: 100);
  });
}
