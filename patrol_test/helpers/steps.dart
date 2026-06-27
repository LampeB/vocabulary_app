import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:patrol/patrol.dart';
import 'package:vocab_kr/core/errors/failure.dart';
import 'package:vocab_kr/core/widget_keys.dart';
import 'package:vocab_kr/presentation/providers/lists/vocabulary_provider.dart';
import 'test_helpers.dart';

/// Quiz input modes. Names match the app's `QuizMode` enum, so they line up with
/// the widget keys (`WidgetKeys.startQuizType(quiz.name)`).
enum Quiz { voice, flashcard, typing, handsFree }

/// Study directions. Names match the app's `QuizDirectionChoice` enum.
enum Dir { frToKo, koToFr, both }

const _simulate = String.fromEnvironment('SIMULATE_SPEECH');

/// Readable, single-purpose E2E steps grouped Given / When / Then.
///
/// Usage in a scenario:
/// ```dart
/// final app = Steps($);
/// await app.given.signedIn();
/// await app.when.startsSession(list: 'Animaux', quiz: Quiz.voice);
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

ProviderContainer _container(PatrolIntegrationTester $) {
  final context = $.tester.element(find.byType(MaterialApp));
  return ProviderScope.containerOf(context);
}

Future<void> _grantMicIfAsked(PatrolIntegrationTester $) async {
  if (_simulate.isNotEmpty) return; // simulated runs never request the mic
  if (await $.platform.mobile.isPermissionDialogVisible()) {
    await $.platform.mobile.grantPermissionWhenInUse();
    await $.pump(const Duration(milliseconds: 500));
  }
}

// ── GIVEN ───────────────────────────────────────────────────────────────────

class GivenSteps {
  GivenSteps(this.$);
  final PatrolIntegrationTester $;

  /// The user is signed in and on the Today screen.
  Future<void> signedIn() => launchAndSignIn($);

  /// A fresh list named [name] exists containing exactly one word
  /// ([french] / [korean]). Seeded through the provider layer (fast, and avoids
  /// the flaky add-word dialog) after clearing any stale list of the same name.
  Future<void> aListWithWord({
    required String name,
    required String french,
    required String korean,
  }) async {
    await deleteListsByName($, name);
    final actions = _container($).read(listActionsProvider.notifier);
    final created = await actions.createList(name, null);
    final listId = created.valueOrNull?.id;
    if (listId == null) {
      throw StateError('Could not create list "$name" (free-plan quota?).');
    }
    await actions.addConcept(listId: listId, frWord: french, koWord: korean);
    // Let the Drift/Supabase streams emit before the UI reads them.
    await $.pump(const Duration(milliseconds: 800));
  }
}

// ── WHEN ────────────────────────────────────────────────────────────────────

class WhenSteps {
  WhenSteps(this.$);
  final PatrolIntegrationTester $;

  /// Opens Start-a-session (the centre nav button), builds a session for [list]
  /// with the given [quiz] type, and taps Commencer. Direction and word count
  /// keep the screen defaults (FR→KR, 20).
  Future<void> startsSession({
    required String list,
    required Quiz quiz,
  }) async {
    await $(find.byKey(const ValueKey(WidgetKeys.navStudy))).tap();
    await $(find.byKey(const ValueKey(WidgetKeys.startSessionStart)))
        .waitUntilVisible(timeout: const Duration(seconds: 30));

    await $(find.text(list)).tap(); // List section is open by default.
    await $(find.byKey(ValueKey(WidgetKeys.startQuizType(quiz.name)))).tap();
    await $(find.byKey(const ValueKey(WidgetKeys.startSessionStart))).tap();

    await _grantMicIfAsked($); // hands-free auto-listens → may prompt here
  }

  /// Voice mode: answer every card until the session ends. A one-word list pads
  /// to the chosen card count, so we tap the mic once per card (each simulated
  /// answer auto-advances) until the summary appears.
  Future<void> completesSessionByVoice() async {
    final summary = find.byKey(const ValueKey(WidgetKeys.summary));
    final mic = find.byKey(const ValueKey(WidgetKeys.micButton));
    await $(mic).waitUntilVisible(timeout: const Duration(seconds: 30));
    for (var i = 0; i < 120; i++) {
      if (summary.evaluate().isNotEmpty) return;
      if (mic.evaluate().isNotEmpty) {
        await $(mic).tap();
        await _grantMicIfAsked($);
      }
      await $.pump(const Duration(milliseconds: 1200));
    }
  }

  /// Taps Continuer on the verdict flood (manual modes: Cartes / Écrire).
  Future<void> tapsContinue() =>
      $(find.byKey(const ValueKey(WidgetKeys.feedbackContinue))).tap();
}

// ── THEN ────────────────────────────────────────────────────────────────────

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
