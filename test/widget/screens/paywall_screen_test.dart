import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/core/widget_keys.dart';
import 'package:vocab_kr/presentation/providers/purchases/purchase_provider.dart';
import 'package:vocab_kr/presentation/screens/paywall/paywall_screen.dart';
import '../../helpers/pump_screen.dart';

/// Paywall screen: static content + how it renders each offerings state
/// (loading skeleton, error/empty fallback). Building real RevenueCat
/// Package/Offerings objects to exercise the purchase buttons is
/// disproportionate — the purchase flow itself is device/mock-only by
/// decision (see docs/test-coverage-roadmap.md).
///
/// The screen has a permanently animating waveform, so every pump uses
/// settle: false.
void main() {
  setUpAll(initTestLocalization);

  Future<void> pump(WidgetTester tester,
      {required FutureOr<dynamic> Function() offerings}) {
    return pumpScreen(
      tester,
      screen: const PaywallScreen(),
      overrides: [
        offeringsProvider.overrideWith((ref) async {
          final r = await offerings();
          return r;
        }),
      ],
      settle: false,
    );
  }

  testWidgets('renders the hero, title and feature list', (tester) async {
    await pump(tester, offerings: () => null);

    expect(
        find.byKey(const ValueKey(WidgetKeys.screenPaywall)), findsOneWidget);
    expect(find.text('paywall.title'.tr()), findsOneWidget);
    expect(find.byIcon(Icons.workspace_premium_outlined), findsOneWidget);
  });

  testWidgets('null offerings (store unreachable) shows the fallback message',
      (tester) async {
    await pump(tester, offerings: () => null);
    await tester.pump();

    expect(find.text('paywall.offerings_unavailable'.tr()), findsOneWidget);
  });

  testWidgets('offerings error also degrades to the fallback message',
      (tester) async {
    await pump(tester, offerings: () => throw Exception('store down'));
    await tester.pump();

    expect(find.text('paywall.offerings_unavailable'.tr()), findsOneWidget);
  });

  testWidgets('while offerings load, no fallback is shown yet',
      (tester) async {
    final gate = Completer<dynamic>();
    await pump(tester, offerings: () => gate.future);

    expect(find.text('paywall.offerings_unavailable'.tr()), findsNothing);
    gate.complete(null); // let the pending future finish before teardown
    await tester.pump();
  });
}
