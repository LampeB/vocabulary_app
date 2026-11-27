import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/notifications/notification_service.dart';
import '../auth/auth_provider.dart';

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
  }) => StudyNotifSettings(
    dailyReminderEnabled: dailyReminderEnabled ?? this.dailyReminderEnabled,
    reminderHour: reminderHour ?? this.reminderHour,
    reminderMinute: reminderMinute ?? this.reminderMinute,
    streakWarningEnabled: streakWarningEnabled ?? this.streakWarningEnabled,
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
  Future<void>? _restored;
  Future<void> get restored => _restored ?? Future<void>.value();

  @override
  StudyNotifSettings build() {
    var active = true;
    ref.onDispose(() => active = false);
    final load = _restored = Future<void>.microtask(() async {
      final prefs = await SharedPreferences.getInstance();
      if (!active) return;
      state = StudyNotifSettings(
        dailyReminderEnabled: prefs.getBool(_kDailyEnabled) ?? true,
        reminderHour: prefs.getInt(_kHour) ?? 9,
        reminderMinute: prefs.getInt(_kMinute) ?? 0,
        streakWarningEnabled: prefs.getBool(_kStreakEnabled) ?? true,
      );
    });
    // A pending device time-zone lookup for one reminder must not delay
    // reading the user's preferences for the other.
    unawaited(
      load
          .then((_) async {
            if (active) await _applyDailyReminder();
          })
          .catchError((Object error) {
            debugPrint('Daily reminder restoration failed: $error');
          }),
    );
    return const StudyNotifSettings();
  }

  NotificationService get _svc => ref.read(notificationServiceProvider);

  Future<void> setDailyReminder({
    required bool enabled,
    int? hour,
    int? minute,
  }) async {
    await restored;
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
    await restored;
    state = state.copyWith(streakWarningEnabled: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kStreakEnabled, enabled);
    if (!enabled) await _svc.cancelStreakWarning();
  }

  Future<void> _applyDailyReminder() async {
    if (state.dailyReminderEnabled) {
      await _svc.scheduleDailyReminder(
        hour: state.reminderHour,
        minute: state.reminderMinute,
      );
    } else {
      await _svc.cancelDailyReminder();
    }
  }

  // Called from home screen / on login, passing the user's current streak.
  Future<void> maybeScheduleStreakWarning(int streakDays) async {
    await restored;
    if (!state.streakWarningEnabled) return;
    await _svc.scheduleStreakWarning(streakDays);
  }
}

final notificationSettingsProvider =
    NotifierProvider<NotificationSettingsNotifier, StudyNotifSettings>(
      NotificationSettingsNotifier.new,
    );

/// Runs while the signed-in session is present, including the V3 home route.
final authenticatedRemindersProvider = FutureProvider.autoDispose<void>((
  ref,
) async {
  final profile = ref.watch(
    currentUserProvider.select(
      (user) => user == null
          ? null
          : (user.id, user.currentStreak, user.lastStudyDate),
    ),
  );
  if (profile == null) return;
  final (_, streakDays, lastStudyDate) = profile;
  var active = true;
  ref.onDispose(() => active = false);
  ref.watch(
    notificationSettingsProvider.select(
      (settings) => settings.streakWarningEnabled,
    ),
  );
  await ref.read(notificationSettingsProvider.notifier).restored;
  if (!active) return;

  final now = DateTime.now();
  final studiedToday =
      lastStudyDate?.year == now.year &&
      lastStudyDate?.month == now.month &&
      lastStudyDate?.day == now.day;
  final service = ref.read(notificationServiceProvider);
  if (!ref.read(notificationSettingsProvider).streakWarningEnabled ||
      streakDays <= 0 ||
      studiedToday) {
    await service.cancelStreakWarning();
  } else {
    await service.scheduleStreakWarning(streakDays);
  }
});
