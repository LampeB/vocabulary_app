import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/notifications/notification_service.dart';
import '../auth/auth_provider.dart';
import '../lists/vocabulary_provider.dart' show appDatabaseProvider;

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
  Locale _locale = const Locale('fr');
  Locale? _appliedDailyLocale;

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

  Future<void> useLocale(Locale locale) async {
    _locale = locale;
    await restored;
    if (_locale == locale && _appliedDailyLocale != locale) {
      await _applyDailyReminder();
    }
  }

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
    _appliedDailyLocale = _locale;
    if (state.dailyReminderEnabled) {
      await _svc.scheduleDailyReminder(
        hour: state.reminderHour,
        minute: state.reminderMinute,
        locale: _locale,
      );
    } else {
      await _svc.cancelDailyReminder();
    }
  }

  // Called from home screen / on login, passing the user's current streak.
  Future<void> maybeScheduleStreakWarning(int streakDays) async {
    await restored;
    if (!state.streakWarningEnabled) return;
    await _svc.scheduleStreakWarning(streakDays, locale: _locale);
  }
}

final notificationSettingsProvider =
    NotifierProvider<NotificationSettingsNotifier, StudyNotifSettings>(
      NotificationSettingsNotifier.new,
    );

/// A locally completed day takes effect before the remote profile refresh.
final localStudyDayProvider = StateProvider.family<DateTime?, String>(
  (_, _) => null,
);

bool _isToday(DateTime? day, DateTime now) =>
    day?.year == now.year && day?.month == now.month && day?.day == now.day;

/// Restores and localizes reminders across the signed-in routes.
final authenticatedRemindersProvider = FutureProvider.autoDispose
    .family<void, Locale>((ref, locale) async {
      final profile = ref.watch(
        currentUserProvider.select(
          (user) => user == null
              ? null
              : (user.id, user.currentStreak, user.lastStudyDate),
        ),
      );
      final service = ref.read(notificationServiceProvider);
      if (profile == null) {
        await service.cancelStreakWarning();
        return;
      }
      final (accountId, streakDays, lastStudyDate) = profile;
      final locallyStudied = ref.watch(localStudyDayProvider(accountId));
      var active = true;
      ref.onDispose(() => active = false);
      ref.watch(
        notificationSettingsProvider.select(
          (settings) => settings.streakWarningEnabled,
        ),
      );
      final settings = ref.read(notificationSettingsProvider.notifier);
      unawaited(
        settings.useLocale(locale).catchError((Object error) {
          debugPrint('Daily reminder localization failed: $error');
        }),
      );
      await settings.restored;
      if (!active) return;

      final now = DateTime.now();
      if (_isToday(locallyStudied, now)) {
        return; // quiz completion already cancelled
      }
      if (!ref.read(notificationSettingsProvider).streakWarningEnabled ||
          streakDays <= 0 ||
          _isToday(lastStudyDate, now)) {
        await service.cancelStreakWarning();
        return;
      }
      final recent = await ref
          .read(appDatabaseProvider)
          .quizSessionDao
          .getSessionsByUser(accountId, limit: 1);
      if (!active) return;
      if (_isToday(recent.firstOrNull?.completedAt.toLocal(), DateTime.now())) {
        await service.cancelStreakWarning();
      } else {
        await service.scheduleStreakWarning(streakDays, locale: locale);
      }
    });
