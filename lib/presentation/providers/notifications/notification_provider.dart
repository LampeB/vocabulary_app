import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/notifications/notification_service.dart';

// ─── Settings model ───────────────────────────────────────────────────────────

class StudyNotifSettings {
  const StudyNotifSettings({
    this.dailyReminderEnabled = true,
    this.reminderHour = 9,
    this.reminderMinute = 0,
    this.streakWarningEnabled = true,
  });

  final bool dailyReminderEnabled;
  final int reminderHour;
  final int reminderMinute;
  final bool streakWarningEnabled;

  StudyNotifSettings copyWith({
    bool? dailyReminderEnabled,
    int? reminderHour,
    int? reminderMinute,
    bool? streakWarningEnabled,
  }) =>
      StudyNotifSettings(
        dailyReminderEnabled:
            dailyReminderEnabled ?? this.dailyReminderEnabled,
        reminderHour: reminderHour ?? this.reminderHour,
        reminderMinute: reminderMinute ?? this.reminderMinute,
        streakWarningEnabled:
            streakWarningEnabled ?? this.streakWarningEnabled,
      );

  String get reminderTimeLabel {
    final h = reminderHour.toString().padLeft(2, '0');
    final m = reminderMinute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

// ─── Keys ─────────────────────────────────────────────────────────────────────

const _kDailyEnabled = 'notif_daily_enabled';
const _kHour = 'notif_hour';
const _kMinute = 'notif_minute';
const _kStreakEnabled = 'notif_streak_enabled';

// ─── Providers ────────────────────────────────────────────────────────────────

final notificationServiceProvider = Provider<NotificationService>(
  (_) => NotificationService.instance,
);

class NotificationSettingsNotifier extends Notifier<StudyNotifSettings> {
  @override
  StudyNotifSettings build() {
    // Kick off async load; state starts at defaults.
    Future.microtask(_load);
    return const StudyNotifSettings();
  }

  NotificationService get _svc => ref.read(notificationServiceProvider);

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = StudyNotifSettings(
      dailyReminderEnabled: prefs.getBool(_kDailyEnabled) ?? true,
      reminderHour: prefs.getInt(_kHour) ?? 9,
      reminderMinute: prefs.getInt(_kMinute) ?? 0,
      streakWarningEnabled: prefs.getBool(_kStreakEnabled) ?? true,
    );
    await _applyDailyReminder();
  }

  Future<void> setDailyReminder({
    required bool enabled,
    int? hour,
    int? minute,
  }) async {
    state = state.copyWith(
      dailyReminderEnabled: enabled,
      reminderHour: hour,
      reminderMinute: minute,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDailyEnabled, enabled);
    if (hour != null) await prefs.setInt(_kHour, hour);
    if (minute != null) await prefs.setInt(_kMinute, minute);
    await _applyDailyReminder();
  }

  Future<void> setStreakWarning(bool enabled) async {
    state = state.copyWith(streakWarningEnabled: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kStreakEnabled, enabled);
    if (!enabled) await _svc.cancelStreakWarning();
  }

  Future<void> _applyDailyReminder() async {
    if (state.dailyReminderEnabled) {
      await _svc.scheduleDailyReminder(
          hour: state.reminderHour, minute: state.reminderMinute);
    } else {
      await _svc.cancelDailyReminder();
    }
  }

  // Called from home screen / on login, passing the user's current streak.
  Future<void> maybeScheduleStreakWarning(int streakDays) async {
    if (!state.streakWarningEnabled) return;
    await _svc.scheduleStreakWarning(streakDays);
  }
}

final notificationSettingsProvider =
    NotifierProvider<NotificationSettingsNotifier, StudyNotifSettings>(
        NotificationSettingsNotifier.new);

// Convenience provider to check & schedule streak warning after user loads.
// Watch this in HomeScreen; it's a no-op after the first call per session.
final streakWarningScheduledProvider =
    FutureProvider.autoDispose<void>((ref) async {
  // Runs once per scope; watches currentUserProvider via the auth chain.
  // The actual scheduling is triggered from HomeScreen by reading the notifier.
});
