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
Future<void> pumpScreen(
  WidgetTester tester, {
  required Widget screen,
  List<Override> overrides = const [],
  List<RouteBase> routes = const [],
}) async {
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
  await tester.pumpAndSettle();
}
