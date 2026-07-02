import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vocab_kr/core/widget_keys.dart';
import 'package:vocab_kr/domain/entities/app_user.dart';
import 'package:vocab_kr/domain/entities/subscription_type.dart';
import 'package:vocab_kr/presentation/providers/auth/auth_provider.dart';
import 'package:vocab_kr/presentation/providers/purchases/purchase_provider.dart';
import 'package:vocab_kr/presentation/providers/settings/settings_provider.dart';
import 'package:vocab_kr/presentation/providers/settings/audio_settings_provider.dart';
import 'package:vocab_kr/presentation/screens/settings/settings_screen.dart';
import '../../helpers/pump_screen.dart';

/// Settings screen: theme pills drive themeModeProvider, audio rows drive
/// audioSettingsProvider, the subscription row reflects premium state and
/// routes to /paywall, and sign-out confirms before calling the auth notifier.

AppUser? _fakeUser;
_FakeAuthNotifier? _lastAuthNotifier;

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier() {
    _lastAuthNotifier = this;
  }
  bool signedOut = false;

  @override
  Future<AppUser?> build() async => _fakeUser;

  @override
  Future<void> signOut() async {
    signedOut = true;
  }
}

void main() {
  setUpAll(initTestLocalization);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    _fakeUser = null;
    _lastAuthNotifier = null;
  });

  String? pushedRoute;

  Future<void> pump(WidgetTester tester, {bool premium = false}) {
    pushedRoute = null;
    Page<void> stub(String name) => MaterialPage<void>(
        child: Scaffold(body: Text('stub:$name')));
    return pumpScreen(
      tester,
      screen: const SettingsScreen(),
      overrides: [
        authStateProvider.overrideWith(_FakeAuthNotifier.new),
        isPremiumProvider.overrideWithValue(premium),
      ],
      routes: [
        for (final r in ['/notifications', '/paywall', '/welcome'])
          GoRoute(
            path: r,
            pageBuilder: (_, __) {
              pushedRoute = r;
              return stub(r);
            },
          ),
      ],
    );
  }

  Future<void> scrollToText(WidgetTester tester, String text) async {
    await tester.scrollUntilVisible(find.text(text), 80,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
  }

  testWidgets('renders with the screen key', (tester) async {
    await pump(tester);
    expect(find.byKey(const ValueKey(WidgetKeys.screenSettings)),
        findsOneWidget);
  });

  testWidgets('tapping the dark theme pill sets ThemeMode.dark',
      (tester) async {
    await pump(tester);

    await tester.tap(find.byIcon(Icons.dark_mode_outlined));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
        tester.element(find.byKey(const ValueKey(WidgetKeys.screenSettings))));
    expect(container.read(themeModeProvider), ThemeMode.dark);
  });

  testWidgets('selecting the fast speech option persists rate 1.1',
      (tester) async {
    await pump(tester);
    final fastLabel = 'settings.audio_speed_fast'.tr();
    await scrollToText(tester, fastLabel);

    await tester.tap(find.text(fastLabel));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
        tester.element(find.byKey(const ValueKey(WidgetKeys.screenSettings))));
    expect(container.read(audioSettingsProvider).speechRate, 1.1);
  });

  testWidgets('free plan shows the upgrade button and it routes to /paywall',
      (tester) async {
    await pump(tester, premium: false);
    final upgrade = 'settings.upgrade_button'.tr();
    await scrollToText(tester, upgrade);

    await tester.tap(find.text(upgrade));
    await tester.pumpAndSettle();

    expect(pushedRoute, '/paywall');
  });

  testWidgets('premium plan hides the upgrade button', (tester) async {
    _fakeUser = AppUser(
      id: 'u',
      email: 't@t.fr',
      username: 'thomas',
      subscriptionType: SubscriptionType.premium,
      createdAt: DateTime(2026),
    );
    await pump(tester, premium: true);
    await scrollToText(tester, 'settings.subscription_premium'.tr());

    expect(find.text('settings.upgrade_button'.tr()), findsNothing);
  });

  testWidgets('sign-out: cancel closes the dialog without signing out',
      (tester) async {
    await pump(tester);
    await scrollToText(tester, 'settings.signout'.tr());
    await tester.tap(find.text('settings.signout'.tr()));
    await tester.pumpAndSettle();

    expect(find.text('settings.signout_dialog_title'.tr()), findsOneWidget);
    await tester.tap(find.text('common.cancel'.tr()));
    await tester.pumpAndSettle();

    expect(_lastAuthNotifier!.signedOut, isFalse);
    expect(pushedRoute, isNull);
  });

  testWidgets('sign-out: confirm calls signOut and lands on /welcome',
      (tester) async {
    await pump(tester);
    await scrollToText(tester, 'settings.signout'.tr());
    await tester.tap(find.text('settings.signout'.tr()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('settings.signout_confirm'.tr()));
    await tester.pumpAndSettle();

    expect(_lastAuthNotifier!.signedOut, isTrue);
    expect(pushedRoute, '/welcome');
  });

  testWidgets('notifications tile routes to /notifications', (tester) async {
    await pump(tester);
    final label = 'settings.notifications_reminders'.tr();
    await scrollToText(tester, label);

    await tester.tap(find.text(label));
    await tester.pumpAndSettle();

    expect(pushedRoute, '/notifications');
  });
}
