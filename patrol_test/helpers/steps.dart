import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:patrol/patrol.dart';
import 'package:vocab_kr/core/errors/failure.dart';
import 'package:vocab_kr/core/stt_simulator.dart';
import 'package:vocab_kr/core/widget_keys.dart';
import 'package:vocab_kr/presentation/providers/lists/vocabulary_provider.dart';
import 'test_helpers.dart';

/// Shared Patrol config for the whole E2E suite.
///
/// Uses the default `trySettle` policy. This is correct *now that the app
/// freezes its study/social animations under TEST_MODE* — with no perpetual
/// ticker, `pumpAndSettle` completes in ~one frame, so actions stay fast AND we
/// keep proper settling between steps. (We briefly used `noSettle` to dodge the
/// never-settling animations; that introduced races — e.g. `enterText` +
/// validate firing before the text registered — so it's reverted.)
const kFastSettle = PatrolTesterConfig(printLogs: true);

/// Quiz input modes. Names match the app's `QuizMode` enum, so they line up with
/// the widget keys (`WidgetKeys.startQuizType(quiz.name)`).
enum Quiz { voice, flashcard, typing, handsFree }

/// Study directions. Names match the app's `QuizDirectionChoice` enum.
enum Dir { frToKo, koToFr, both }

/// App screens, each identified by the stable key on its root Scaffold
/// (`WidgetKeys.screen*`). Used by `then.onScreen(...)` to assert arrival.
enum Screen {
  welcome,
  home,
  lists,
  listDetail,
  startSession,
  social,
  profile,
  stats,
  settings,
  notifications,
  paywall,
  importLink,
}

/// Bottom-nav destinations. Names match `WidgetKeys.navTab(name)`.
enum NavTab { home, lists, social, profile }

/// Tappable navigation tiles on the Profile screen.
enum ProfileTile { stats, settings, notifications, signOut }

/// Maps a [Screen] to the widget-key on its root Scaffold.
String _screenRootKey(Screen s) => switch (s) {
      Screen.welcome => WidgetKeys.screenWelcome,
      Screen.home => WidgetKeys.screenHome,
      Screen.lists => WidgetKeys.screenLists,
      Screen.listDetail => WidgetKeys.screenListDetail,
      Screen.startSession => WidgetKeys.screenStartSession,
      Screen.social => WidgetKeys.screenSocial,
      Screen.profile => WidgetKeys.screenProfile,
      Screen.stats => WidgetKeys.screenStats,
      Screen.settings => WidgetKeys.screenSettings,
      Screen.notifications => WidgetKeys.screenNotifications,
      Screen.paywall => WidgetKeys.screenPaywall,
      Screen.importLink => WidgetKeys.screenImport,
    };

/// Maps a [ProfileTile] to its widget-key.
String _profileTileKey(ProfileTile t) => switch (t) {
      ProfileTile.stats => WidgetKeys.profileTileStats,
      ProfileTile.settings => WidgetKeys.profileTileSettings,
      ProfileTile.notifications => WidgetKeys.profileTileNotifications,
      ProfileTile.signOut => WidgetKeys.profileSignOut,
    };

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

  /// No list named [name] exists — clears stale data before a UI-driven create
  /// so the free-plan quota isn't already full from a previous run.
  Future<void> noListNamed(String name) => deleteListsByName($, name);

  /// A clean slate: deletes EVERY existing list via the data layer, so the
  /// free-plan list quota is empty before a UI-driven create. Fast (no UI).
  Future<void> aCleanSlate() => deleteAllLists($);
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

  /// Taps a bottom-nav tab (Home / Lists / Social / Profile). The nav bar lives
  /// in the shell, so it stays visible on every signed-in screen.
  Future<void> tapsNavTab(NavTab tab) async {
    await $(find.byKey(ValueKey(WidgetKeys.navTab(tab.name)))).tap();
    await $.pump(const Duration(milliseconds: 600));
  }

  /// Opens a list's detail screen by tapping its card (from the Lists screen).
  Future<void> opensList(String name) async {
    await $(find.text(name)).tap();
    await $.pump(const Duration(milliseconds: 600));
  }

  /// Opens a Profile navigation tile (Stats / Settings / Notifications / Sign out).
  /// Scrolls it into view first — the lower tiles sit below the fold.
  Future<void> opensProfileTile(ProfileTile tile) async {
    final f = find.byKey(ValueKey(_profileTileKey(tile)));
    await $(f).scrollTo();
    await $(f).tap();
    await $.pump(const Duration(milliseconds: 600));
  }

  /// Opens Notification settings via the Home header bell.
  Future<void> opensNotificationsFromBell() async {
    await $(find.byKey(const ValueKey(WidgetKeys.homeBell))).tap();
    await $.pump(const Duration(milliseconds: 600));
  }

  // ── Auth flows ──────────────────────────────────────────────────────────────

  /// Signs out via the Profile sign-out tile + confirmation (→ Welcome).
  Future<void> signsOut() async {
    await tapsNavTab(NavTab.profile);
    final tile = find.byKey(const ValueKey(WidgetKeys.profileSignOut));
    await $(tile).scrollTo();
    await $(tile).tap();
    await $(find.byKey(const ValueKey(WidgetKeys.signOutConfirm))).tap();
    await $.pump(const Duration(milliseconds: 800));
  }

  /// From the Welcome screen, opens the sign-in screen.
  Future<void> goesToSignIn() async {
    await $(find.text('J\'ai déjà un compte')).tap();
    await $.pump(const Duration(milliseconds: 600));
  }

  /// On the sign-in screen, requests a password reset for [email]
  /// (forgot-password link → email → send).
  Future<void> requestsPasswordReset(String email) async {
    await $(find.byKey(const ValueKey(WidgetKeys.authForgotPassword))).tap();
    final field = find.byKey(const ValueKey(WidgetKeys.authResetEmail));
    await $(field).waitUntilVisible(timeout: const Duration(seconds: 15));
    await $(field).enterText(email);
    await $(find.byKey(const ValueKey(WidgetKeys.authResetSend))).tap();
    await $.pump(const Duration(milliseconds: 800));
  }

  // ── List & word management (UI-driven, not provider-seeded) ─────────────────

  /// Pumps until [finder] disappears — e.g. a dialog's keyed confirm button
  /// after a submit. A bounded poll (no pumpAndSettle, which hangs on the
  /// Supabase realtime stream emitting after each write).
  Future<void> _waitUntilGone(Finder finder,
      {Duration timeout = const Duration(seconds: 15)}) async {
    final deadline = DateTime.now().add(timeout);
    while (finder.evaluate().isNotEmpty) {
      if (DateTime.now().isAfter(deadline)) return;
      await $.pump(const Duration(milliseconds: 150));
    }
    await $.pump(const Duration(milliseconds: 300));
  }

  /// Creates a vocabulary list via the FAB + name dialog (must be on Lists).
  Future<void> createsList(String name) async {
    await $(find.byKey(const ValueKey(WidgetKeys.listsFab))).tap();
    final field = find.byKey(const ValueKey(WidgetKeys.listNameField));
    await $(field).waitUntilVisible(timeout: const Duration(seconds: 15));
    await $(field).enterText(name);
    await $(find.byKey(const ValueKey(WidgetKeys.listNameConfirm))).tap();
    await _waitUntilGone(find.byKey(const ValueKey(WidgetKeys.listNameConfirm)));
    await $(find.text(name)).waitUntilVisible(timeout: const Duration(seconds: 30));
  }

  /// Adds a word ([fr]/[ko]) via the add-word dialog (must be in List Detail).
  Future<void> addsWord(String fr, String ko) async {
    await $(find.byKey(const ValueKey(WidgetKeys.listDetailAddWord))).tap();
    final frField = find.byKey(const ValueKey(WidgetKeys.addWordFr));
    await $(frField).waitUntilVisible(timeout: const Duration(seconds: 15));
    await $(frField).enterText(fr);
    await $(find.byKey(const ValueKey(WidgetKeys.addWordKo))).enterText(ko);
    await $(find.byKey(const ValueKey(WidgetKeys.addWordConfirm))).tap();
    await _waitUntilGone(find.byKey(const ValueKey(WidgetKeys.addWordConfirm)));
  }

  /// Switches List Detail into edit mode (reveals per-word edit/delete icons).
  Future<void> entersEditMode() async {
    await $(find.byKey(const ValueKey(WidgetKeys.listDetailMenu))).tap();
    await $(find.byKey(const ValueKey(WidgetKeys.listDetailEditItem))).tap();
    await $.pump(const Duration(milliseconds: 400));
  }

  /// Edits the word whose French side is [fromFr], replacing it with
  /// [toFr]/[toKo]. Requires edit mode (see [entersEditMode]).
  Future<void> editsWord({
    required String fromFr,
    required String toFr,
    required String toKo,
  }) async {
    await $(find.byKey(ValueKey(WidgetKeys.conceptEditIcon(fromFr)))).tap();
    final frField = find.byKey(const ValueKey(WidgetKeys.editWordFr));
    await $(frField).waitUntilVisible(timeout: const Duration(seconds: 15));
    await $(frField).enterText(toFr);
    await $(find.byKey(const ValueKey(WidgetKeys.editWordKo))).enterText(toKo);
    await $(find.byKey(const ValueKey(WidgetKeys.editWordConfirm))).tap();
    await _waitUntilGone(find.byKey(const ValueKey(WidgetKeys.editWordConfirm)));
  }

  /// Deletes the word whose French side is [fr] (trash icon + confirm).
  /// Requires edit mode (see [entersEditMode]).
  Future<void> deletesWord(String fr) async {
    await $(find.byKey(ValueKey(WidgetKeys.conceptDeleteIcon(fr)))).tap();
    final confirm = find.byKey(const ValueKey(WidgetKeys.deleteWordConfirm));
    await $(confirm).waitUntilVisible(timeout: const Duration(seconds: 15));
    await $(confirm).tap();
    await _waitUntilGone(confirm);
  }

  /// Leaves List Detail via the app-bar back button (returns to Lists).
  Future<void> leavesListDetail() async {
    await $(find.byKey(const ValueKey(WidgetKeys.listDetailBack))).tap();
    await $.pump(const Duration(milliseconds: 600));
  }

  /// Opens the Start-session "Type" section and (re)selects Vocabulaire —
  /// the only enabled session type. Lets a scenario touch every section.
  Future<void> choosesSessionType() async {
    await $(find.byKey(ValueKey(WidgetKeys.startSection(0)))).tap();
    await $(find.byKey(ValueKey(WidgetKeys.startType('vocab')))).tap();
    await $.pump(const Duration(milliseconds: 300));
  }

  /// Picks the list to study (its accordion section is open by default).
  Future<void> choosesList(String name) => $(find.text(name)).tap();

  /// Picks the quiz input mode (voice / flashcard / typing / hands-free).
  Future<void> choosesQuizType(Quiz quiz) =>
      $(find.byKey(ValueKey(WidgetKeys.startQuizType(quiz.name)))).tap();

  /// Picks the study direction (FR→KO / KO→FR / both). Defaults to FR→KO, so
  /// only call this when a scenario needs the reverse or both directions.
  Future<void> choosesDirection(Dir dir) =>
      $(find.byKey(ValueKey(WidgetKeys.startDirection(dir.name)))).tap();

  /// Picks how many cards the session runs. This OVERRIDES `TEST_CARD_LIMIT`,
  /// so a chosen count of 10 yields a 10-card session even in CI — keep it small.
  Future<void> choosesCardCount(int n) =>
      $(find.byKey(ValueKey(WidgetKeys.startCount(n)))).tap();

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

  /// Typing: enter [text] and validate exactly ONE card, then stop on the
  /// verdict flood (does NOT tap Continue). Pair with `then.verdictIs…` to
  /// assert the per-card feedback. Typing's flood is manual, so it persists.
  Future<void> typesAnswerForOneCard(String text) async {
    final input = find.byKey(const ValueKey(WidgetKeys.ecrireInput));
    await $(input).waitUntilVisible(timeout: const Duration(seconds: 30));
    await $(input).enterText(text);
    await $(find.byKey(const ValueKey(WidgetKeys.ecrireValidate))).tap();
    await $.pump(const Duration(milliseconds: 600));
  }

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

  /// The given [screen] is showing (its root Scaffold is visible).
  Future<void> onScreen(Screen screen) =>
      $(find.byKey(ValueKey(_screenRootKey(screen))))
          .waitUntilVisible(timeout: const Duration(seconds: 30));

  /// The given user-data [text] (a word or list name — not localized UI copy)
  /// is visible on screen.
  Future<void> seesText(String text) =>
      $(find.text(text)).waitUntilVisible(timeout: const Duration(seconds: 15));

  /// The given [text] is not present on screen.
  Future<void> doesNotSeeText(String text) async {
    expect(find.text(text), findsNothing);
  }

  /// The password-reset request was handled — a success OR error response is
  /// shown. Delivery isn't asserted, and Supabase rate-limits resets so *success*
  /// isn't guaranteed; this proves the form → submit → response flow works.
  Future<void> passwordResetResponded() async {
    final ok = find.byKey(const ValueKey(WidgetKeys.authResetSuccess));
    final err = find.byKey(const ValueKey(WidgetKeys.authResetError));
    final deadline = DateTime.now().add(const Duration(seconds: 20));
    while (DateTime.now().isBefore(deadline)) {
      if (ok.evaluate().isNotEmpty || err.evaluate().isNotEmpty) return;
      await $.pump(const Duration(milliseconds: 200));
    }
    throw StateError('No password-reset response snackbar appeared');
  }

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
