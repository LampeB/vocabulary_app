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
  final welcome = find.text('J\'ai déjà un compte');
  final shell = find.byKey(const ValueKey(WidgetKeys.navStudy));

  // Launch the app ONLY if it isn't already running. Re-calling app.main() on
  // every test leaks providers/Supabase listeners and destabilises the Patrol
  // process after ~10 tests (hang/crash). If the binding tore the tree down
  // between tests (no MaterialApp), we relaunch as before; otherwise we reuse
  // the already-running app — one launch for the whole suite.
  final alreadyRunning = find.byType(MaterialApp).evaluate().isNotEmpty;
  if (!alreadyRunning) {
    unawaited(app.main());
    // Poll for welcome (signed-out) or the shell (a prior Supabase session
    // survived in this process). Polling keeps it fast when already signed in.
    final deadline = DateTime.now().add(const Duration(minutes: 5));
    while (DateTime.now().isBefore(deadline)) {
      if (welcome.evaluate().isNotEmpty || shell.evaluate().isNotEmpty) break;
      try {
        await $.pump(const Duration(milliseconds: 400));
      } catch (_) {
        break;
      }
    }
  } else {
    try {
      await $.pump(const Duration(milliseconds: 300));
    } catch (_) {}
  }

  // Sign in if we're not already in the signed-in shell.
  if (shell.evaluate().isEmpty) {
    if ($(welcome).exists) {
      await $(welcome).tap();
      await $.pump(const Duration(milliseconds: 500));
    }
    if ($(find.byKey(const Key('email_field'))).exists) {
      await $(find.byKey(const Key('email_field'))).enterText(kTestEmail);
      // Brief settle: a SmartLock/autofill overlay or a resolving Supabase
      // session check can briefly hide the password field.
      await $.pump(const Duration(seconds: 2));
      if ($(find.byKey(const Key('password_field'))).exists) {
        await $(find.byKey(const Key('password_field'))).enterText(kTestPassword);
        await $(find.byKey(const Key('auth_submit_button'))).tap();
        // Allow time for Supabase auth + profile load. Fixed pump — NOT
        // pumpAndSettle, which hangs on home-screen providers.
        await $.pump(const Duration(seconds: 4));
        await $.pump(const Duration(milliseconds: 1000));
      }
    }
  }

  // Reset to Home so every test starts from a known screen when the app is
  // reused across tests (the home tab lives in the persistent shell).
  final homeTab = find.byKey(ValueKey(WidgetKeys.navTab('home')));
  if (homeTab.evaluate().isNotEmpty) {
    try {
      await $(homeTab).tap();
      await $.pump(const Duration(milliseconds: 500));
    } catch (_) {}
  }
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
