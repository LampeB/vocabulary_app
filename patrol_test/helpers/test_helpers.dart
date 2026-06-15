import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:vocab_kr/main.dart' as app;
import 'package:vocab_kr/presentation/providers/lists/vocabulary_provider.dart';

// Injected via --dart-define-from-file=test.env.json
const kTestEmail = String.fromEnvironment('TEST_EMAIL');
const kTestPassword = String.fromEnvironment('TEST_PASSWORD');

/// Launches the app and signs in with [kTestEmail] / [kTestPassword].
/// Handles three starting states: welcome screen, auth screen, already signed in.
Future<void> launchAndSignIn(PatrolIntegrationTester $) async {
  unawaited(app.main());

  // Give the splash screen and Supabase init time to complete.
  await $.pump(const Duration(seconds: 4));
  await $.pumpAndSettle();

  // Welcome screen → navigate to sign-in.
  if ($(find.text('I already have an account')).exists) {
    await $('I already have an account').tap();
    await $.pumpAndSettle();
  }

  // Auth screen → sign in.
  if ($(find.byKey(const Key('email_field'))).exists) {
    await $(find.byKey(const Key('email_field'))).enterText(kTestEmail);
    await $(find.byKey(const Key('password_field'))).enterText(kTestPassword);
    await $(find.byKey(const Key('auth_submit_button'))).tap();
    // Allow time for Supabase auth + profile load.
    await $.pump(const Duration(seconds: 4));
    await $.pumpAndSettle();
  }

  // At this point we should be on the home (Today) screen.
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
  for (final list in lists.where((l) => l.name == name)) {
    try {
      await container.read(listActionsProvider.notifier).deleteList(list.id);
    } catch (_) {
      // Container may have been disposed if next test started a new ProviderScope.
    }
  }
  try {
    await $.pumpAndSettle();
  } catch (_) {}
}
