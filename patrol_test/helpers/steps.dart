import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:patrol/patrol.dart';
import 'package:vocab_kr/core/errors/failure.dart';
import 'package:vocab_kr/core/stt_simulator.dart';
import 'package:vocab_kr/core/widget_keys.dart';
import 'package:vocab_kr/presentation/providers/lists/vocabulary_provider.dart';
import 'test_helpers.dart';

/// Quiz input modes. Names match the app's `QuizMode` enum, so they line up with
/// the widget keys (`WidgetKeys.startQuizType(quiz.name)`).
enum Quiz { voice, flashcard, typing, handsFree }

/// Study directions. Names match the app's `QuizDirectionChoice` enum.
enum Dir { frToKo, koToFr, both }

/// Readable E2E steps grouped Given / When / Then. Each step does ONE thing and
/// is named for it, so a scenario reads top-to-bottom like a description of the
/// user's actions. Usage:
///
/// ```dart
/// final app = Steps($);
/// await app.given.signedIn();
/// await app.when.opensStartASession();
/// await app.then.sessionScoreIs(percent: 100);
/// ```
class Steps {
  Steps(this.$)
      : given = GivenSteps($),
        when = WhenSteps($),
        then = ThenSteps($);

  final PatrolIntegrationTester $;
  final GivenSteps given;
  final WhenSteps when;
  final ThenSteps then;
}

ProviderContainer _container(PatrolIntegrationTester $) =>
    ProviderScope.containerOf($.tester.element(find.byType(MaterialApp)));

Future<void> _grantMicIfAsked(PatrolIntegrationTester $) async {
  if (SttSimulator.isOn) return; // simulated runs never request the mic
  if (await $.platform.mobile.isPermissionDialogVisible()) {
    await $.platform.mobile.grantPermissionWhenInUse();
    await $.pump(const Duration(milliseconds: 500));
  }
}

// ── GIVEN — preconditions ─────────────────────────────────────────────────────

class GivenSteps {
  GivenSteps(this.$);
  final PatrolIntegrationTester $;

  /// The user is signed in and on the Today screen.
  Future<void> signedIn() => launchAndSignIn($);

  /// A fresh list [name] exists with exactly one word ([french] / [korean]).
  /// Seeded via the provider layer (fast, and avoids the add-word dialog) after
  /// removing any stale list of the same name.
  Future<void> aListWithOneWord({
    required String name,
    required String french,
    required String korean,
  }) async {
    await deleteListsByName($, name);
    final actions = _container($).read(listActionsProvider.notifier);
    final listId = (await actions.createList(name, null)).valueOrNull?.id;
    if (listId == null) {
      throw StateError('Could not create list "$name" (free-plan quota?).');
    }
    await actions.addConcept(listId: listId, frWord: french, koWord: korean);
    await $.pump(const Duration(milliseconds: 800)); // let the streams settle
  }

  /// Speech recognition will return the card's correct word for every answer.
  Future<void> theLearnerWillAnswerCorrectly() async =>
      SttSimulator.mode = SttSimulator.correct;

  /// Speech recognition will return a wrong word for every answer.
  Future<void> theLearnerWillAnswerIncorrectly() async =>
      SttSimulator.mode = SttSimulator.wrong;
}

// ── WHEN — actions ────────────────────────────────────────────────────────────

class WhenSteps {
  WhenSteps(this.$);
  final PatrolIntegrationTester $;

  /// Opens the Start-a-session screen via the raised centre nav button.
  Future<void> opensStartASession() async {
    await $(find.byKey(const ValueKey(WidgetKeys.navStudy))).tap();
    await $(find.byKey(const ValueKey(WidgetKeys.startSessionStart)))
        .waitUntilVisible(timeout: const Duration(seconds: 30));
  }

  /// Picks the list to study (its accordion section is open by default).
  Future<void> choosesList(String name) => $(find.text(name)).tap();

  /// Picks the quiz input mode (voice / flashcard / typing / hands-free).
  Future<void> choosesQuizType(Quiz quiz) =>
      $(find.byKey(ValueKey(WidgetKeys.startQuizType(quiz.name)))).tap();

  /// Taps Commencer to start the session (grants the mic on real-STT runs).
  Future<void> startsTheSession() async {
    await $(find.byKey(const ValueKey(WidgetKeys.startSessionStart))).tap();
    await _grantMicIfAsked($);
  }

  /// Answers every card by voice until the session ends: taps the mic once per
  /// card (each simulated answer auto-advances). A one-word list pads to the
  /// chosen card count, hence the loop. The answer's correctness comes from the
  /// `given.theLearnerWillAnswer…` step set earlier.
  Future<void> answersEachCardByVoice() async {
    final summary = find.byKey(const ValueKey(WidgetKeys.summary));
    final mic = find.byKey(const ValueKey(WidgetKeys.micButton));
    await $(mic).waitUntilVisible(timeout: const Duration(seconds: 30));
    for (var i = 0; i < 120; i++) {
      if (summary.evaluate().isNotEmpty) return; // reached the summary
      if (mic.evaluate().isNotEmpty) {
        await $(mic).tap();
        await _grantMicIfAsked($);
      }
      await $.pump(const Duration(milliseconds: 1200));
    }
  }

  /// Flashcards: flip and self-grade every card as "Je savais" (known) until the
  /// session ends. Cartes isn't auto-advanced, so each card is flip → grade →
  /// Continuer.
  Future<void> answersEachCardAsKnown() => _gradeEachCard(WidgetKeys.gradeKnew);

  /// Flashcards: flip and self-grade every card as "À revoir" (forgotten).
  Future<void> answersEachCardAsForgotten() =>
      _gradeEachCard(WidgetKeys.gradeAgain);

  Future<void> _gradeEachCard(String gradeKey) async {
    final summary = find.byKey(const ValueKey(WidgetKeys.summary));
    final card = find.byKey(const ValueKey(WidgetKeys.cartesCard));
    final grade = find.byKey(ValueKey(gradeKey));
    final cont = find.byKey(const ValueKey(WidgetKeys.feedbackContinue));
    await $(card).waitUntilVisible(timeout: const Duration(seconds: 30));
    for (var i = 0; i < 240; i++) {
      if (summary.evaluate().isNotEmpty) return;
      if (grade.evaluate().isNotEmpty) {
        await $(grade).tap(); // back is showing → grade it
      } else if (cont.evaluate().isNotEmpty) {
        await $(cont).tap(); // verdict flood → next card
      } else if (card.evaluate().isNotEmpty) {
        await $(card).tap(); // front is showing → flip to reveal
      }
      await $.pump(const Duration(milliseconds: 400));
    }
  }

  /// Typing: enter [word] and validate on every card until the session ends.
  Future<void> typesCorrectAnswerForEachCard(String word) =>
      _typeEachCard(word);

  /// Typing: enter a deliberately wrong answer on every card.
  Future<void> typesWrongAnswerForEachCard() => _typeEachCard('___nope___');

  Future<void> _typeEachCard(String text) async {
    final summary = find.byKey(const ValueKey(WidgetKeys.summary));
    final input = find.byKey(const ValueKey(WidgetKeys.ecrireInput));
    final validate = find.byKey(const ValueKey(WidgetKeys.ecrireValidate));
    final cont = find.byKey(const ValueKey(WidgetKeys.feedbackContinue));
    await $(input).waitUntilVisible(timeout: const Duration(seconds: 30));
    for (var i = 0; i < 240; i++) {
      if (summary.evaluate().isNotEmpty) return;
      if (input.evaluate().isNotEmpty) {
        await $(input).enterText(text);
        await $(validate).tap();
      } else if (cont.evaluate().isNotEmpty) {
        await $(cont).tap(); // verdict flood → next card
      }
      await $.pump(const Duration(milliseconds: 400));
    }
  }
}

// ── THEN — assertions ─────────────────────────────────────────────────────────

class ThenSteps {
  ThenSteps(this.$);
  final PatrolIntegrationTester $;

  /// The verdict flood shows "correct" (teal).
  Future<void> verdictIsCorrect() =>
      $(find.byKey(const ValueKey(WidgetKeys.feedbackCorrect)))
          .waitUntilVisible(timeout: const Duration(seconds: 30));

  /// The verdict flood shows "wrong" (orange).
  Future<void> verdictIsWrong() =>
      $(find.byKey(const ValueKey(WidgetKeys.feedbackWrong)))
          .waitUntilVisible(timeout: const Duration(seconds: 30));

  /// The session has finished and the summary shows [percent] accuracy.
  /// Generous timeout: hands-free auto-advances through every padded card.
  Future<void> sessionScoreIs({required int percent}) async {
    await $(find.byKey(const ValueKey(WidgetKeys.summary)))
        .waitUntilVisible(timeout: const Duration(minutes: 4));
    expect(find.text('$percent %'), findsOneWidget);
  }
}
