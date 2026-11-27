import 'package:timezone/timezone.dart' as tz;

/// The next occurrence of [hour]:[minute] at or after [now]. If today's slot has
/// already passed, rolls to the same time tomorrow.
tz.TZDateTime nextDailyReminder(tz.TZDateTime now, int hour, int minute) {
  final slotToday = tz.TZDateTime(
    now.location,
    now.year,
    now.month,
    now.day,
    hour,
    minute,
  );
  return slotToday.isBefore(now)
      ? tz.TZDateTime(
          now.location,
          now.year,
          now.month,
          now.day + 1,
          hour,
          minute,
        )
      : slotToday;
}

/// When to fire the "streak at risk" warning, or null to skip. Skipped when the
/// user has no streak ([streakDays] <= 0) or the cutoff ([hour]:00, default 8 PM)
/// has already passed today — no point warning about a streak after the deadline.
tz.TZDateTime? streakWarningSlot(
  tz.TZDateTime now,
  int streakDays, {
  int hour = 20,
}) {
  if (streakDays <= 0) return null;
  final warning = tz.TZDateTime(
    now.location,
    now.year,
    now.month,
    now.day,
    hour,
  );
  return warning.isBefore(now) ? null : warning;
}
