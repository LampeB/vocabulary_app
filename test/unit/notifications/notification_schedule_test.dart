import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/presentation/providers/notifications/notification_provider.dart';
import 'package:vocab_kr/services/notifications/notification_schedule.dart';

/// The *when/whether* of notifications is pure wall-clock logic (extracted from
/// NotificationService so it's testable without the native plugin or a device).
void main() {
  group('nextDailyReminder', () {
    test("today's slot when the time is still ahead", () {
      final now = DateTime(2026, 7, 2, 8, 0);
      expect(nextDailyReminder(now, 9, 0), DateTime(2026, 7, 2, 9, 0));
    });

    test('rolls to tomorrow when the slot already passed', () {
      final now = DateTime(2026, 7, 2, 10, 0);
      expect(nextDailyReminder(now, 9, 0), DateTime(2026, 7, 3, 9, 0));
    });

    test('exactly at the slot counts as today (not before → not rolled)', () {
      final now = DateTime(2026, 7, 2, 9, 0, 0);
      expect(nextDailyReminder(now, 9, 0), DateTime(2026, 7, 2, 9, 0));
    });

    test('one second past the slot rolls to tomorrow', () {
      final now = DateTime(2026, 7, 2, 9, 0, 1);
      expect(nextDailyReminder(now, 9, 0), DateTime(2026, 7, 3, 9, 0));
    });

    test('rolls across a month boundary', () {
      final now = DateTime(2026, 7, 31, 23, 0);
      expect(nextDailyReminder(now, 9, 0), DateTime(2026, 8, 1, 9, 0));
    });
  });

  group('streakWarningSlot', () {
    test('no streak → skip (null)', () {
      expect(streakWarningSlot(DateTime(2026, 7, 2, 12, 0), 0), isNull);
    });

    test('negative streak → skip (null)', () {
      expect(streakWarningSlot(DateTime(2026, 7, 2, 12, 0), -1), isNull);
    });

    test('active streak before 8 PM → today at 20:00', () {
      expect(streakWarningSlot(DateTime(2026, 7, 2, 18, 0), 5),
          DateTime(2026, 7, 2, 20, 0));
    });

    test('active streak already past 8 PM → skip (null)', () {
      expect(streakWarningSlot(DateTime(2026, 7, 2, 21, 0), 5), isNull);
    });

    test('exactly at 8 PM still schedules (not before → kept)', () {
      expect(streakWarningSlot(DateTime(2026, 7, 2, 20, 0), 5),
          DateTime(2026, 7, 2, 20, 0));
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
