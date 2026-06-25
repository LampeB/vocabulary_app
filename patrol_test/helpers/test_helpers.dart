import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
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

  // Replace the old fixed 4.5-second pump with an adaptive wait.
  // On the FIRST Patrol session after an ART cache wipe, cold JIT compilation
  // takes 6-15 min on Samsung S22 (debug mode) before the first frame renders.
  // Subsequent tests hit warm ART code and see the welcome screen in < 5 s.
  // waitUntilVisible here absorbs the cold-JIT cost so all real test steps
  // start with the app already visible and no timeout has been eaten.
  try {
    await $(find.text('J\'ai déjà un compte')).waitUntilVisible(
      // 28 min: cold ART JIT on Samsung S22 takes 15-20 min in debug mode.
      // All warm-JIT tests (any test after the first) find the element in < 5 s.
      timeout: const Duration(minutes: 28),
    );
  } catch (_) {
    // Welcome screen not found within 28 min — could be:
    //   • auth screen (Supabase session survived clearPackageData via Keystore)
    //   • home screen (same reason)
    // The guards below handle both cases.
  }

  // Welcome screen → navigate to sign-in.
  if ($(find.text('J\'ai déjà un compte')).exists) {
    await $(find.text('J\'ai déjà un compte')).tap();
    // Fixed pump — local navigation is instant, 500ms is plenty.
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
Future<void> deleteListsByName(PatrolIntegrationTester $, String name) async {
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
  final toDelete = lists.where((l) => l.name == name).toList();
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
