import 'dart:convert';

// ignore: implementation_imports — tests hydrate the global Localization
// directly; the public EasyLocalization widget loads its JSON through an async
// delegate that races the test binding (renders SizedBox.shrink after the
// first test in a process).
import 'package:easy_localization/src/localization.dart';
// ignore: implementation_imports
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Loads the real French translations into the global [Localization] that
/// `.tr()` (without a context) reads. Call once from `setUpAll`.
Future<void> initTestLocalization() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final raw = await rootBundle.loadString('assets/translations/fr.json');
  final translations =
      Translations(jsonDecode(raw) as Map<String, dynamic>);
  Localization.load(
    const Locale('fr'),
    translations: translations,
    fallbackTranslations: translations,
  );
}

/// Pumps [screen] inside `ProviderScope` (with [overrides]) and a
/// `MaterialApp.router`. Extra [routes] let a test observe navigation — e.g.
/// a `/quiz` stub that records `state.extra`.
///
/// Real French strings work (`find.text('Commencer…')`) because
/// [initTestLocalization] hydrated the global `.tr()` table; `WidgetKeys`
/// remain the preferred stable selectors.
/// Set [settle] to false for screens with perpetual animations (e.g. an
/// animating waveform) — pumpAndSettle would never return; a couple of fixed
/// pumps render the frame instead.
Future<void> pumpScreen(
  WidgetTester tester, {
  required Widget screen,
  List<Override> overrides = const [],
  List<RouteBase> routes = const [],
  bool settle = true,
}) async {
  // Phone-like viewport (360×780 logical). The flutter_test default is
  // 800×600 physical at DPR 3 → ~267 logical px wide, narrower than any real
  // phone, which causes spurious RenderFlex overflows in row-heavy screens.
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, __) => screen),
      ...routes,
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }
}

/// Call at the END of any test whose screen watches drift streams: closing a
/// drift query stream (on ProviderScope dispose) schedules a zero-duration
/// Timer, and the framework's automatic teardown checks the pending-timer
/// invariant before that timer can fire. Unmounting inside the test body and
/// pumping once lets it run.
Future<void> unmountScreen(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  // Advance the fake clock — a plain pump() elapses no time, so drift's
  // zero-duration close timers would still be "pending" at the invariant check.
  await tester.pump(const Duration(milliseconds: 1));
}
