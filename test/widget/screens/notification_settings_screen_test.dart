import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vocab_kr/core/widget_keys.dart';
import 'package:vocab_kr/presentation/providers/notifications/notification_provider.dart';
import 'package:vocab_kr/presentation/screens/notifications/notification_settings_screen.dart';
import 'package:vocab_kr/services/notifications/notification_service.dart';
import '../../helpers/pump_screen.dart';

/// Notification settings screen driving the REAL notifier (mocked prefs) with
/// a recording fake NotificationService — covers the screen wiring and the
/// notifier's persistence/scheduling paths in one go.

class _RecordingNotifService implements NotificationService {
  final calls = <String>[];
  @override
  Future<void> scheduleDailyReminder({int hour = 9, int minute = 0}) async {
    calls.add('schedule:$hour:$minute');
  }

  @override
  Future<void> cancelDailyReminder() async => calls.add('cancelDaily');
  @override
  Future<void> cancelStreakWarning() async => calls.add('cancelStreak');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(initTestLocalization);

  late _RecordingNotifService svc;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    svc = _RecordingNotifService();
  });

  Future<void> pump(WidgetTester tester) => pumpScreen(
        tester,
        screen: const NotificationSettingsScreen(),
        overrides: [notificationServiceProvider.overrideWithValue(svc)],
      );

  ProviderContainer container(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(
          find.byKey(const ValueKey(WidgetKeys.screenNotifications))));

  testWidgets('renders with both toggles on by default and schedules 09:00',
      (tester) async {
    await pump(tester);

    expect(find.byKey(const ValueKey(WidgetKeys.screenNotifications)),
        findsOneWidget);
    final s = container(tester).read(notificationSettingsProvider);
    expect(s.dailyReminderEnabled, isTrue);
    expect(s.streakWarningEnabled, isTrue);
    // The notifier's load applies the enabled reminder on build.
    expect(svc.calls, contains('schedule:9:0'));
  });

  testWidgets('turning the daily reminder off persists and cancels it',
      (tester) async {
    await pump(tester);

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();

    expect(container(tester).read(notificationSettingsProvider)
        .dailyReminderEnabled, isFalse);
    expect(svc.calls, contains('cancelDaily'));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('notif_daily_enabled'), isFalse);
  });

  testWidgets('turning the streak warning off cancels the pending warning',
      (tester) async {
    await pump(tester);

    await tester.tap(find.byType(Switch).last);
    await tester.pumpAndSettle();

    expect(container(tester).read(notificationSettingsProvider)
        .streakWarningEnabled, isFalse);
    expect(svc.calls, contains('cancelStreak'));
  });

  testWidgets('picking a reminder time reschedules at the chosen time',
      (tester) async {
    await pump(tester);

    // Open the time tile (shows the current 09:00 label).
    await tester.tap(find.text('09:00'));
    await tester.pumpAndSettle();
    // Confirm the picker with its default value.
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(svc.calls.where((c) => c.startsWith('schedule:')).length,
        greaterThanOrEqualTo(2)); // initial apply + reschedule
  });
}
