import 'package:flutter/services.dart'
    show MethodChannel, MissingPluginException, PlatformException;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'notification_schedule.dart';

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
  final _scheduleGenerations = <int, int>{};
  final _platformOperations = <int, Future<void>>{};

  Future<tz.TZDateTime> _nowForScheduling() async {
    const channel = MethodChannel('vocab_kr/device_time_zone');
    var location = tz.local;
    try {
      final name = await channel.invokeMethod<String>('get');
      if (name != null) location = tz.getLocation(name);
    } on MissingPluginException {
      // Hosts without mobile scheduling use the configured fallback.
    } on PlatformException {
      // The configured fallback remains available.
    } on tz.LocationNotFoundException {
      // The bundled zone database may lag a newly added platform zone.
    }
    return tz.TZDateTime.now(location);
  }

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

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      final ok = await android.requestNotificationsPermission();
      // Request exact alarms separately (Android 12+).
      await android.requestExactAlarmsPermission();
      granted = ok ?? false;
    }

    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      final ok = await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      granted = ok ?? false;
    }

    return granted;
  }

  // ─── Daily study reminder ─────────────────────────────────────────────────

  Future<void> scheduleDailyReminder({int hour = 9, int minute = 0}) =>
      _schedule(
        _dailyReminderId,
        (now) => nextDailyReminder(now, hour, minute),
        _scheduleDailyReminder,
      );

  Future<void> _scheduleDailyReminder(tz.TZDateTime next) async {
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
  Future<void> scheduleStreakWarning(int streakDays) => _schedule(
    _streakWarningId,
    (now) => streakWarningSlot(now, streakDays),
    (warning) => _scheduleStreakWarning(streakDays, warning),
  );

  Future<void> _scheduleStreakWarning(
    int streakDays,
    tz.TZDateTime warning,
  ) async {
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

  int _invalidate(int id) => _scheduleGenerations.update(
    id,
    (generation) => generation + 1,
    ifAbsent: () => 1,
  );

  Future<void> _schedule(
    int id,
    tz.TZDateTime? Function(tz.TZDateTime) nextSlot,
    Future<void> Function(tz.TZDateTime) write,
  ) async {
    final generation = _invalidate(id);
    bool current() => _scheduleGenerations[id] == generation;
    await _orderPlatformOperation(id, () async {
      if (current()) await _plugin.cancel(id);
    });
    if (!current()) return;

    // Resolve the zone outside the platform queue. Cancel and subsequent
    // requests remain usable if this reply is slow or never arrives.
    final now = await _nowForScheduling();
    if (!current()) return;
    final slot = nextSlot(now);
    if (slot == null) return;
    await _orderPlatformOperation(id, () async {
      if (current()) await write(slot);
    });
  }

  Future<void> _orderPlatformOperation(int id, Future<void> Function() action) {
    final operation = (_platformOperations[id] ?? Future<void>.value()).then(
      (_) => action(),
    );
    _trackPlatformOperation(operation, [id]);
    return operation;
  }

  void _trackPlatformOperation(Future<void> operation, List<int> ids) {
    late final Future<void> settled;
    void release() {
      for (final id in ids) {
        if (identical(_platformOperations[id], settled)) {
          _platformOperations.remove(id);
        }
      }
    }

    settled = operation.then<void>(
      (_) => release(),
      onError: (Object _, StackTrace _) => release(),
    );
    for (final id in ids) {
      _platformOperations[id] = settled;
    }
  }

  Future<void> _cancel(int id) {
    _invalidate(id);
    return _orderPlatformOperation(id, () => _plugin.cancel(id));
  }

  Future<void> cancelDailyReminder() => _cancel(_dailyReminderId);
  Future<void> cancelStreakWarning() => _cancel(_streakWarningId);

  Future<void> cancelAll() {
    _invalidate(_dailyReminderId);
    _invalidate(_streakWarningId);
    final operation = Future.wait(
      _platformOperations.values,
    ).then((_) => _plugin.cancelAll());
    _trackPlatformOperation(operation, const [
      _dailyReminderId,
      _streakWarningId,
    ]);
    return operation;
  }

  void _onTapped(NotificationResponse response) {
    // Navigation is handled by the app shell listening to this stream.
    // For now, tapping any notification opens the home screen (default route).
  }
}
