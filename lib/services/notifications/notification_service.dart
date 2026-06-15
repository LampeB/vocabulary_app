import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const _dailyReminderId = 1;
  static const _streakWarningId = 2;

  static const _studyChannelId = 'study_reminders';
  static const _studyChannelName = 'Study Reminders';
  static const _streakChannelId = 'streak_alerts';
  static const _streakChannelName = 'Streak Alerts';

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iOS = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: iOS),
      onDidReceiveNotificationResponse: _onTapped,
    );
    _initialized = true;
  }

  // Returns true if the user granted permission (either platform).
  Future<bool> requestPermissions() async {
    var granted = false;

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final ok = await android.requestNotificationsPermission();
      // Request exact alarms separately (Android 12+).
      await android.requestExactAlarmsPermission();
      granted = ok ?? false;
    }

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final ok = await ios.requestPermissions(
          alert: true, badge: true, sound: true);
      granted = ok ?? false;
    }

    return granted;
  }

  // ─── Daily study reminder ─────────────────────────────────────────────────

  Future<void> scheduleDailyReminder({int hour = 9, int minute = 0}) async {
    await cancelDailyReminder();

    final now = tz.TZDateTime.now(tz.local);
    var next = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, hour, minute);
    if (next.isBefore(now)) next = next.add(const Duration(days: 1));

    try {
      await _plugin.zonedSchedule(
        _dailyReminderId,
        'Time to study! 🇫🇷🇰🇷',
        'Your vocabulary is waiting — keep the streak alive!',
        next,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _studyChannelId,
            _studyChannelName,
            channelDescription: 'Daily vocabulary study reminders',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } on PlatformException {
      // SCHEDULE_EXACT_ALARM permission not granted (Android 12+). Silently skip.
    }
  }

  // ─── Streak-at-risk warning ───────────────────────────────────────────────

  // Schedules a one-off warning for today at 20:00 if the user has a streak
  // and hasn't studied yet. Call after app launch / profile load.
  Future<void> scheduleStreakWarning(int streakDays) async {
    await cancelStreakWarning();
    if (streakDays == 0) return;

    final now = tz.TZDateTime.now(tz.local);
    final warning =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, 20, 0);
    if (warning.isBefore(now)) return; // already past 8 PM — skip today

    try {
      await _plugin.zonedSchedule(
        _streakWarningId,
        'Don\'t break your streak! 🔥',
        '$streakDays-day streak at risk — study before midnight.',
        warning,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _streakChannelId,
            _streakChannelName,
            channelDescription: 'Alert when your daily streak is at risk',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: false,
            presentSound: true,
          ),
        ),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } on PlatformException {
      // SCHEDULE_EXACT_ALARM permission not granted (Android 12+). Silently skip.
    }
  }

  Future<void> cancelDailyReminder() => _plugin.cancel(_dailyReminderId);
  Future<void> cancelStreakWarning() => _plugin.cancel(_streakWarningId);
  Future<void> cancelAll() => _plugin.cancelAll();

  void _onTapped(NotificationResponse response) {
    // Navigation is handled by the app shell listening to this stream.
    // For now, tapping any notification opens the home screen (default route).
  }
}
