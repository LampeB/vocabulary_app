import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vocab_kr/core/widget_keys.dart';
import 'package:vocab_kr/presentation/widgets/app_shell.dart';
import '../../helpers/pump_screen.dart';

/// App shell: the offline banner appears/disappears with connectivity, nav
/// tabs route to their destinations, and the study button opens the
/// start-session flow.

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
          '/social',
          '/profile',
          '/start-session'
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

  testWidgets('nav tabs route to their destinations', (tester) async {
    await pump(tester, connectivity: [ConnectivityResult.wifi]);

    await tester.tap(find.byKey(ValueKey(WidgetKeys.navTab('lists'))));
    await tester.pumpAndSettle();
    expect(navigatedTo, '/lists');
  });

  testWidgets('the raised study button opens start-session', (tester) async {
    await pump(tester, connectivity: [ConnectivityResult.wifi]);

    await tester.tap(find.byKey(const ValueKey(WidgetKeys.navStudy)));
    await tester.pumpAndSettle();
    expect(navigatedTo, '/start-session');
  });
}
