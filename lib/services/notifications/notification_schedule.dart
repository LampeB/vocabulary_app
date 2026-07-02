// Pure scheduling rules for local notifications — no plugin/timezone imports so
// they can be unit-tested on the host. NotificationService calls these to decide
// *when* (and *whether*) to fire, then rebuilds the tz-aware time from the
// returned wall-clock components.

/// The next occurrence of [hour]:[minute] at or after [now]. If today's slot has
/// already passed, rolls to the same time tomorrow.
DateTime nextDailyReminder(DateTime now, int hour, int minute) {
  final slotToday = DateTime(now.year, now.month, now.day, hour, minute);
  return slotToday.isBefore(now)
      ? slotToday.add(const Duration(days: 1))
      : slotToday;
}

/// When to fire the "streak at risk" warning, or null to skip. Skipped when the
/// user has no streak ([streakDays] <= 0) or the cutoff ([hour]:00, default 8 PM)
/// has already passed today — no point warning about a streak after the deadline.
DateTime? streakWarningSlot(DateTime now, int streakDays, {int hour = 20}) {
  if (streakDays <= 0) return null;
  final warning = DateTime(now.year, now.month, now.day, hour, 0);
  return warning.isBefore(now) ? null : warning;
}
