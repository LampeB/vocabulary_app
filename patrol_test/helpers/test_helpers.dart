import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:vocab_kr/core/widget_keys.dart';
import 'package:vocab_kr/main.dart' as app;
import 'package:vocab_kr/presentation/providers/lists/vocabulary_provider.dart';

// Injected via --dart-define-from-file=test.env.json
const kTestEmail    = String.fromEnvironment('TEST_EMAIL');
const kTestPassword = String.fromEnvironment('TEST_PASSWORD');
const kTestUsername = String.fromEnvironment('TEST_USERNAME');

/// Launches the app and signs in with [kTestEmail] / [kTestPassword].
/// Handles three starting states: welcome screen, auth screen, already signed in.
Future<void> launchAndSignIn(PatrolIntegrationTester $) async {
  unawaited(app.main());

  // Settle into one of two known states, breaking on whichever appears first:
  //   • the welcome screen        → we still need to sign in;
  //   • the signed-in nav shell   → a previous test's Supabase session survived
  //     in this process, so we're already home.
  // Polling (instead of waitUntilVisible on the welcome text) is what keeps the
  // 2nd..Nth test fast: when already signed in the welcome screen never appears,
  // so waiting it out would otherwise burn the full timeout PER test.
  final welcome = find.text('J\'ai déjà un compte');
  final shell = find.byKey(const ValueKey(WidgetKeys.navStudy));
  final deadline = DateTime.now().add(const Duration(minutes: 5));
  while (DateTime.now().isBefore(deadline)) {
    if (welcome.evaluate().isNotEmpty || shell.evaluate().isNotEmpty) break;
    try {
      await $.pump(const Duration(milliseconds: 400));
    } catch (_) {
      break;
    }
  }

  // Already signed in → nothing to do.
  if (shell.evaluate().isNotEmpty) return;

  // Welcome screen → navigate to sign-in.
  if ($(welcome).exists) {
    await $(welcome).tap();
    // Local navigation is instant; 500ms is plenty.
    await $.pump(const Duration(milliseconds: 500));
  }

  // Auth screen → sign in.
  if ($(find.byKey(const Key('email_field'))).exists) {
    await $(find.byKey(const Key('email_field'))).enterText(kTestEmail);
    // Brief settle after email entry: on Samsung a SmartLock/autofill overlay
    // can briefly cover the password field, AND a pending Supabase session
    // check may resolve here and navigate the app to home — making the
    // password field disappear before we reach it.  The 2 s pump lets both
    // settle; we then re-check whether the password field is still present.
    await $.pump(const Duration(seconds: 2));
    if ($(find.byKey(const Key('password_field'))).exists) {
      await $(find.byKey(const Key('password_field'))).enterText(kTestPassword);
      await $(find.byKey(const Key('auth_submit_button'))).tap();
      // Allow time for Supabase auth + profile load.
      await $.pump(const Duration(seconds: 4));
      // Fixed pump — NOT pumpAndSettle which hangs on home-screen providers.
      await $.pump(const Duration(milliseconds: 1000));
    }
    // else: the session resolved mid-sign-in → router already navigating to home.
  }

  // At this point we should be on the home (Today) screen.
}

/// Launches the app and pumps until the welcome screen appears or 36 min elapses.
///
/// Use this as the body of a dedicated [patrolTest] with a 38-minute timeout
/// placed FIRST in the suite. It absorbs the cold ART JIT cost (30-35 min on
/// Samsung S22 in debug mode) so every subsequent test runs on warm JIT code.
///
/// The ART JIT code cache is stored outside `/data/data/<package>/` and therefore
/// survives the clearPackageData call that follows this test.
Future<void> warmupJitCache(PatrolIntegrationTester $) async {
  unawaited(app.main());
  final deadline = DateTime.now().add(const Duration(minutes: 36));
  while (DateTime.now().isBefore(deadline)) {
    try {
      await $.pump(const Duration(seconds: 5));
    } catch (_) {
      break; // binding disposed (test torn down) — exit loop
    }
    if ($(find.text('J\'ai déjà un compte')).exists) break; // JIT warm
  }
}

/// Deletes all lists named [name] via Riverpod (bypasses the UI).
/// Call this before creating a test list to avoid hitting the free-plan quota
/// when the test account has accumulated stale lists from previous runs.
Future<void> deleteListsByName(PatrolIntegrationTester $, String name) =>
    _deleteLists($, (l) => l.name == name);

/// Deletes EVERY list owned by the test account via Riverpod (bypasses the UI).
/// A fast data-layer reset — use it as a test precondition so the free-plan list
/// quota is guaranteed empty regardless of what previous runs left behind.
Future<void> deleteAllLists(PatrolIntegrationTester $) =>
    _deleteLists($, (_) => true);

/// Shared core: deletes the lists matching [where] through the provider layer.
Future<void> _deleteLists(
    PatrolIntegrationTester $, bool Function(dynamic list) where) async {
  // The widget tree may be transitioning between tests; bail out gracefully.
  final BuildContext context;
  try {
    context = $.tester.element(find.byType(MaterialApp));
  } catch (_) {
    return;
  }

  ProviderContainer container;
  try {
    container = ProviderScope.containerOf(context);
  } catch (_) {
    return;
  }

  final lists = container.read(myListsProvider).valueOrNull ?? [];
  final toDelete = lists.where(where).toList();
  // Parallel deletes with a per-call cap so that a slow Supabase connection
  // cannot cause tearDown to hang for the HTTP timeout (60-120 s).
  await Future.wait(toDelete.map((list) async {
    try {
      await container.read(listActionsProvider.notifier)
          .deleteList(list.id)
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      // Swallow TimeoutException and Supabase errors — stale lists are
      // acceptable; a hanging tearDown is not.
    }
  }));
  // Fixed pump — NOT pumpAndSettle which hangs on Supabase realtime streams
  // emitting updates after each delete.
  try {
    await $.pump(const Duration(milliseconds: 500));
  } catch (_) {}
}
