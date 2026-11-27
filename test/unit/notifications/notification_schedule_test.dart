import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:vocab_kr/presentation/providers/notifications/notification_provider.dart';
import 'package:vocab_kr/services/notifications/notification_schedule.dart';
import 'package:vocab_kr/services/notifications/notification_service.dart';

Future<NotificationService> _mockNotifications(
  WidgetTester tester, {
  required FutureOr<String> Function() timeZone,
  required FutureOr<Object?> Function(MethodCall) onNotification,
}) async {
  const zone = MethodChannel('vocab_kr/device_time_zone');
  const notifications = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );
  final messenger = tester.binding.defaultBinaryMessenger;
  AndroidFlutterLocalNotificationsPlugin.registerWith();
  messenger.setMockMethodCallHandler(zone, (_) async => timeZone());
  messenger.setMockMethodCallHandler(notifications, (call) async {
    if (call.method == 'initialize') return true;
    return onNotification(call);
  });
  addTearDown(() {
    messenger.setMockMethodCallHandler(zone, null);
    messenger.setMockMethodCallHandler(notifications, null);
  });
  final service = NotificationService.instance;
  await service.init();
  return service;
}

/// The *when/whether* of notifications is pure wall-clock logic (extracted from
/// NotificationService so it's testable without the native plugin or a device).
void main() {
  setUpAll(tz_data.initializeTimeZones);

  testWidgets(
    'daily schedule sends 09:00 in the device zone to Android',
    (tester) async {
      final schedules = <Map<Object?, Object?>>[];
      final service = await _mockNotifications(
        tester,
        timeZone: () => 'Europe/Paris',
        onNotification: (call) {
          if (call.method == 'zonedSchedule') {
            schedules.add(call.arguments as Map<Object?, Object?>);
          }
          return null;
        },
      );
      await service.scheduleDailyReminder();
      expect(schedules.single['timeZoneName'], 'Europe/Paris');
      expect(schedules.single['scheduledDateTime'], endsWith('T09:00:00'));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  for (final streak in [false, true]) {
    testWidgets(
      'cancel invalidates the pending device zone lookup (streak: $streak)',
      (tester) async {
        final zone = ['Europe/Paris', 'Pacific/Tahiti', 'Asia/Tokyo']
            .firstWhere(
              (name) => tz.TZDateTime.now(tz.getLocation(name)).hour < 18,
            );
        final delayedZone = Completer<String>();
        final calls = <MethodCall>[];
        var lookups = 0;
        final service = await _mockNotifications(
          tester,
          timeZone: () => ++lookups == 1 ? delayedZone.future : zone,
          onNotification: (call) {
            calls.add(call);
            return null;
          },
        );
        final old = streak
            ? service.scheduleStreakWarning(7)
            : service.scheduleDailyReminder(hour: 9);
        await tester.pump();
        expect(lookups, 1);

        if (streak) {
          await service.cancelStreakWarning();
        } else {
          await service.cancelDailyReminder();
        }
        expect(calls.map((call) => call.method), ['cancel', 'cancel']);
        if (streak) {
          await service.scheduleStreakWarning(11);
        } else {
          await service.scheduleDailyReminder(hour: 11);
        }
        expect(lookups, 2);
        delayedZone.complete(zone);
        await old;

        final schedule = calls
            .where((call) => call.method == 'zonedSchedule')
            .single;
        expect(schedule.arguments['id'], streak ? 2 : 1);
        if (streak) {
          expect(schedule.arguments['body'], contains('11-day'));
        } else {
          expect(
            schedule.arguments['scheduledDateTime'],
            endsWith('T11:00:00'),
          );
        }
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }

  testWidgets(
    'cancelAll drains an active platform write and invalidates the other ID',
    (tester) async {
      final nativeWrite = Completer<void>();
      final delayedZone = Completer<String>();
      final operations = <String>[];
      var lookups = 0;
      var writes = 0;
      final service = await _mockNotifications(
        tester,
        timeZone: () => ++lookups == 2 ? delayedZone.future : 'Europe/Paris',
        onNotification: (call) async {
          operations.add(call.method);
          if (call.method == 'zonedSchedule' && ++writes == 1) {
            await nativeWrite.future;
          }
          return null;
        },
      );
      final active = service.scheduleDailyReminder();
      await tester.pump();
      expect(writes, 1);
      final stale = service.scheduleStreakWarning(4);
      await tester.pump();
      expect(lookups, 2);
      final cancellation = service.cancelAll();
      final replacement = service.scheduleDailyReminder(hour: 11);
      await tester.pump();
      expect(operations, ['cancel', 'zonedSchedule', 'cancel']);

      nativeWrite.complete();
      await active;
      await cancellation;
      await replacement;
      delayedZone.complete('Europe/Paris');
      await stale;
      expect(operations, [
        'cancel',
        'zonedSchedule',
        'cancel',
        'cancelAll',
        'cancel',
        'zonedSchedule',
      ]);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  group('nextDailyReminder', () {
    test("today's slot when the time is still ahead", () {
      final now = tz.TZDateTime(tz.UTC, 2026, 7, 2, 8, 0);
      expect(
        nextDailyReminder(now, 9, 0),
        tz.TZDateTime(tz.UTC, 2026, 7, 2, 9, 0),
      );
    });

    test('rolls to tomorrow when the slot already passed', () {
      final now = tz.TZDateTime(tz.UTC, 2026, 7, 2, 10, 0);
      expect(
        nextDailyReminder(now, 9, 0),
        tz.TZDateTime(tz.UTC, 2026, 7, 3, 9, 0),
      );
    });

    test('exactly at the slot counts as today (not before → not rolled)', () {
      final now = tz.TZDateTime(tz.UTC, 2026, 7, 2, 9, 0, 0);
      expect(
        nextDailyReminder(now, 9, 0),
        tz.TZDateTime(tz.UTC, 2026, 7, 2, 9, 0),
      );
    });

    test('one second past the slot rolls to tomorrow', () {
      final now = tz.TZDateTime(tz.UTC, 2026, 7, 2, 9, 0, 1);
      expect(
        nextDailyReminder(now, 9, 0),
        tz.TZDateTime(tz.UTC, 2026, 7, 3, 9, 0),
      );
    });

    test('rolls across a month boundary', () {
      final now = tz.TZDateTime(tz.UTC, 2026, 7, 31, 23, 0);
      expect(
        nextDailyReminder(now, 9, 0),
        tz.TZDateTime(tz.UTC, 2026, 8, 1, 9, 0),
      );
    });

    for (final (month, day, elapsed) in [(3, 28, 22), (10, 24, 24)]) {
      test('Paris keeps 09:00 when clocks change after $month/$day', () {
        final paris = tz.getLocation('Europe/Paris');
        final now = tz.TZDateTime(paris, 2026, month, day, 10);
        final next = nextDailyReminder(now, 9, 0);
        expect(next, tz.TZDateTime(paris, 2026, month, day + 1, 9));
        expect(next.difference(now), Duration(hours: elapsed));
      });
    }
  });

  group('streakWarningSlot', () {
    test('uses the scheduling zone for the date and cutoff', () {
      final paris = tz.getLocation('Europe/Paris');
      final instant = DateTime.utc(2026, 7, 2, 18, 30);
      expect(streakWarningSlot(tz.TZDateTime.from(instant, paris), 3), isNull);
      expect(
        streakWarningSlot(tz.TZDateTime.from(instant, tz.UTC), 3),
        isNotNull,
      );
      final nearMidnight = tz.TZDateTime.from(
        DateTime.utc(2026, 7, 2, 22, 30),
        paris,
      );
      expect(
        streakWarningSlot(nearMidnight, 3),
        tz.TZDateTime(paris, 2026, 7, 3, 20),
      );
    });

    test('no streak → skip (null)', () {
      expect(
        streakWarningSlot(tz.TZDateTime(tz.UTC, 2026, 7, 2, 12, 0), 0),
        isNull,
      );
    });

    test('negative streak → skip (null)', () {
      expect(
        streakWarningSlot(tz.TZDateTime(tz.UTC, 2026, 7, 2, 12, 0), -1),
        isNull,
      );
    });

    test('active streak before 8 PM → today at 20:00', () {
      expect(
        streakWarningSlot(tz.TZDateTime(tz.UTC, 2026, 7, 2, 18, 0), 5),
        tz.TZDateTime(tz.UTC, 2026, 7, 2, 20, 0),
      );
    });

    test('active streak already past 8 PM → skip (null)', () {
      expect(
        streakWarningSlot(tz.TZDateTime(tz.UTC, 2026, 7, 2, 21, 0), 5),
        isNull,
      );
    });

    test('exactly at 8 PM still schedules (not before → kept)', () {
      expect(
        streakWarningSlot(tz.TZDateTime(tz.UTC, 2026, 7, 2, 20, 0), 5),
        tz.TZDateTime(tz.UTC, 2026, 7, 2, 20, 0),
      );
    });
  });

  group('StudyNotifSettings', () {
    test('sensible defaults: daily on at 09:00, streak on', () {
      const s = StudyNotifSettings();
      expect(s.dailyReminderEnabled, isTrue);
      expect(s.reminderHour, 9);
      expect(s.reminderMinute, 0);
      expect(s.streakWarningEnabled, isTrue);
      expect(s.reminderTimeLabel, '09:00');
    });

    test('reminderTimeLabel zero-pads hour and minute', () {
      const s = StudyNotifSettings(reminderHour: 7, reminderMinute: 5);
      expect(s.reminderTimeLabel, '07:05');
    });

    test('copyWith changes only the given field', () {
      const s = StudyNotifSettings();
      final updated = s.copyWith(reminderHour: 21, streakWarningEnabled: false);
      expect(updated.reminderHour, 21);
      expect(updated.streakWarningEnabled, isFalse);
      expect(updated.reminderMinute, 0); // untouched
      expect(updated.dailyReminderEnabled, isTrue); // untouched
    });
  });
}
