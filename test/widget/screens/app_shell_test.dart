import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vocab_kr/core/widget_keys.dart';
import 'package:vocab_kr/presentation/widgets/app_shell.dart';
import '../../helpers/pump_screen.dart';

/// App shell: the offline banner appears/disappears with connectivity, nav
/// tabs route to their destinations, with five equally sized V0 slots.

void main() {
  setUpAll(initTestLocalization);

  testWidgets(
    'tabs keep readable labels and selected keyboard navigation at 320px double text',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          ShellRoute(
            builder: (_, _, child) => AppShell(child: child),
            routes: [
              for (final path in [
                '/home',
                '/lists',
                '/grammar',
                '/stats',
                '/profile',
              ])
                GoRoute(path: path, builder: (_, _) => const Text('Content')),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            connectivityStreamProvider.overrideWith(
              (ref) => Stream.value([ConnectivityResult.wifi]),
            ),
            pushOnReconnectProvider.overrideWith((ref) {}),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      final home = find.byKey(ValueKey(WidgetKeys.navTab('home')));
      expect(
        tester.getSemantics(home).getSemanticsData().flagsCollection.isSelected,
        Tristate.isTrue,
      );
      final label = find.descendant(of: home, matching: find.byType(Text));
      Focus.of(tester.element(label)).requestFocus();
      await tester.pump();
      for (var i = 0; i < 3; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/stats');
      final active = find.byKey(ValueKey(WidgetKeys.navTab('stats')));
      expect(
        tester
            .getSemantics(active)
            .getSemanticsData()
            .flagsCollection
            .isSelected,
        Tristate.isTrue,
      );
      expect(
        find.descendant(
          of: find.byKey(ValueKey(WidgetKeys.navTab('lists'))),
          matching: find.byType(FittedBox),
        ),
        findsNothing,
      );
      for (final tab in ['home', 'lists', 'grammar', 'stats', 'profile']) {
        expect(
          tester.getSize(find.byKey(ValueKey(WidgetKeys.navTab(tab)))).width,
          closeTo(64, .1),
        );
      }
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  String? navigatedTo;

  Future<void> pump(
    WidgetTester tester, {
    required List<ConnectivityResult> connectivity,
  }) {
    navigatedTo = null;
    return pumpScreen(
      tester,
      screen: const AppShell(child: Text('page-content')),
      overrides: [
        connectivityStreamProvider.overrideWith(
          (ref) => Stream.value(connectivity),
        ),
      ],
      routes: [
        for (final r in ['/home', '/lists', '/grammar', '/stats', '/profile'])
          GoRoute(
            path: r,
            pageBuilder: (_, state) {
              navigatedTo = state.uri.toString();
              return const MaterialPage<void>(
                child: Scaffold(body: SizedBox()),
              );
            },
          ),
      ],
    );
  }

  testWidgets('online: renders the child without the offline banner', (
    tester,
  ) async {
    await pump(tester, connectivity: [ConnectivityResult.wifi]);

    expect(find.text('page-content'), findsOneWidget);
    expect(find.text('shell.offline_banner'.tr()), findsNothing);
    expect(find.byIcon(Icons.wifi_off), findsNothing);
  });

  testWidgets('offline: shows the banner above the content', (tester) async {
    await pump(tester, connectivity: [ConnectivityResult.none]);

    expect(find.text('shell.offline_banner'.tr()), findsOneWidget);
    expect(find.byIcon(Icons.wifi_off), findsOneWidget);
    expect(find.text('page-content'), findsOneWidget); // content still usable
  });

  testWidgets('V0 navigation has five equal slots and no raised study button', (
    tester,
  ) async {
    await pump(tester, connectivity: [ConnectivityResult.wifi]);

    for (final tab in ['home', 'lists', 'grammar', 'stats', 'profile']) {
      expect(find.byKey(ValueKey(WidgetKeys.navTab(tab))), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('nav.study')), findsNothing);
  });

  testWidgets('the lessons slot routes to the grammar hub', (tester) async {
    await pump(tester, connectivity: [ConnectivityResult.wifi]);

    await tester.tap(find.byKey(ValueKey(WidgetKeys.navTab('grammar'))));
    await tester.pumpAndSettle();
    expect(navigatedTo, '/grammar');
  });

  testWidgets('quiz and its summary omit the general tabs and footer space', (
    tester,
  ) async {
    const home = ValueKey('home-content');
    const quiz = ValueKey('quiz-content');
    const summary = ValueKey(WidgetKeys.summary);
    final finished = ValueNotifier(false);
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        ShellRoute(
          builder: (_, _, child) => AppShell(child: child),
          routes: [
            GoRoute(
              path: '/home',
              builder: (_, _) => const SizedBox.expand(key: home),
            ),
            GoRoute(
              path: '/quiz',
              builder: (_, _) => ValueListenableBuilder(
                valueListenable: finished,
                builder: (_, done, _) =>
                    SizedBox.expand(key: done ? summary : quiz),
              ),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    addTearDown(finished.dispose);
    tester.view.padding = const FakeViewPadding(bottom: 24);
    addTearDown(tester.view.resetPadding);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          connectivityStreamProvider.overrideWith(
            (ref) => Stream.value([ConnectivityResult.none]),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    final homeTab = find.byKey(ValueKey(WidgetKeys.navTab('home')));
    expect(homeTab, findsOneWidget);
    expect(find.byIcon(Icons.wifi_off), findsOneWidget);

    unawaited(router.push<void>('/quiz'));
    await tester.pumpAndSettle();
    final shell = find.byType(Scaffold);
    void expectFullSession(Key key) {
      expect(tester.getRect(find.byKey(key)), tester.getRect(shell));
      for (final tab in ['home', 'lists', 'grammar', 'stats', 'profile']) {
        expect(find.byKey(ValueKey(WidgetKeys.navTab(tab))), findsNothing);
      }
      expect(find.byIcon(Icons.wifi_off), findsNothing);
    }

    expectFullSession(quiz);
    finished.value = true;
    await tester.pumpAndSettle();
    expectFullSession(summary);
    router.pop();
    await tester.pumpAndSettle();
    expect(homeTab, findsOneWidget);
  });
}
