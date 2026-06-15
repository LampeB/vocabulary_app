import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:vocab_kr/presentation/providers/auth/auth_provider.dart';
import 'helpers/test_helpers.dart';

void main() {
  // ── Sign-in flow ──────────────────────────────────────────────────────────

  patrolTest('sign-in lands on Today screen',
      timeout: const Timeout(Duration(minutes: 2)), ($) async {
    await launchAndSignIn($);

    // The shell's bottom nav shows 'Today' as the first tab.
    expect($('Today'), findsOneWidget);
  });

  // ── Profile screen shows username ─────────────────────────────────────────
  //
  // Regression test for the empty-profile bug:
  // auth listener overwrote the profile-loaded state with a profileless user.
  //
  // We verify the Riverpod provider directly instead of navigating to the
  // profile screen: GoRouter navigation in integration tests triggers
  // mid-layout Scaffold animation assertions in Flutter's test binding,
  // which fail the test before any assertion can run.

  patrolTest('profile data is loaded after sign-in',
      timeout: const Timeout(Duration(minutes: 2)), ($) async {
    await launchAndSignIn($);

    // MaterialApp is a child of ProviderScope, so its element's context can
    // walk up to the scope. ProviderScope itself is not a valid context here.
    final container = ProviderScope.containerOf(
      $.tester.element(find.byType(MaterialApp)),
    );
    final user = container.read(currentUserProvider);

    expect(user, isNotNull);
    expect(user!.username, isNotEmpty);
  });
}
