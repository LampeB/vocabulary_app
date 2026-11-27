// Daily-streak arithmetic shared by auth and social updates, testable without
// hitting Supabase.

/// Outcome of a streak recomputation.
class StreakUpdate {
  const StreakUpdate({required this.streak, required this.alreadyCountedToday});

  final int streak;

  /// True when the user already studied today — the caller should skip the write.
  final bool alreadyCountedToday;
}

/// Recomputes the streak for a study session happening on [today].
///
/// - Studied again the same day → unchanged, [StreakUpdate.alreadyCountedToday].
/// - Last study was yesterday → streak grows by one (kept the chain).
/// - Any older gap, or first ever study → streak resets to one.
///
/// [lastStudyDate] and [today] may carry a time component; only the calendar day
/// is compared.
StreakUpdate computeStreak({
  required DateTime today,
  DateTime? lastStudyDate,
  required int currentStreak,
}) {
  // Civil dates use UTC only as a zone-free calendar representation. A local
  // day can span 23 or 25 hours at a daylight-saving transition.
  final todayDate = DateTime.utc(today.year, today.month, today.day);

  if (lastStudyDate == null) {
    return const StreakUpdate(streak: 1, alreadyCountedToday: false);
  }

  final lastDay = DateTime.utc(
    lastStudyDate.year,
    lastStudyDate.month,
    lastStudyDate.day,
  );
  if (lastDay == todayDate) {
    return StreakUpdate(streak: currentStreak, alreadyCountedToday: true);
  }

  final yesterday = todayDate.subtract(const Duration(days: 1));
  return StreakUpdate(
    streak: lastDay == yesterday ? currentStreak + 1 : 1,
    alreadyCountedToday: false,
  );
}
