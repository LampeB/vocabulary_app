import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vocab_kr/core/widget_keys.dart';
import 'package:vocab_kr/presentation/widgets/app_shell.dart';
import '../../helpers/pump_screen.dart';

/// App shell: the offline banner appears/disappears with connectivity, nav
/// tabs route to their destinations, with five equally sized V0 slots.

void main() {
  setUpAll(initTestLocalization);

  String? navigatedTo;

  Future<void> pump(WidgetTester tester,
      {required List<ConnectivityResult> connectivity}) {
    navigatedTo = null;
    return pumpScreen(
      tester,
      screen: const AppShell(child: Text('page-content')),
      overrides: [
        connectivityStreamProvider
            .overrideWith((ref) => Stream.value(connectivity)),
      ],
      routes: [
        for (final r in [
          '/home',
          '/lists',
          '/grammar',
          '/stats',
          '/profile',
        ])
          GoRoute(
            path: r,
            pageBuilder: (_, state) {
              navigatedTo = state.uri.toString();
              return const MaterialPage<void>(
                  child: Scaffold(body: SizedBox()));
            },
          ),
      ],
    );
  }

  testWidgets('online: renders the child without the offline banner',
      (tester) async {
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

  testWidgets('V0 navigation has five equal slots and no raised study button',
      (tester) async {
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
}
