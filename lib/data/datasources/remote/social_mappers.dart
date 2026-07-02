// Pure row → entity mappers for the social datasource. Kept separate so the
// null-handling and rank assignment can be unit-tested without a live Supabase
// query.
import '../../../domain/entities/leaderboard_entry.dart';

/// Maps ordered `profiles` rows to leaderboard entries, assigning 1-based ranks
/// from the row order (the query sorts by total_words_mastered descending).
/// Missing username/score default to '' / 0.
List<LeaderboardEntry> leaderboardEntriesFromRows(
  List<Map<String, dynamic>> rows,
  LeaderboardPeriod period,
) =>
    rows
        .asMap()
        .entries
        .map((e) => LeaderboardEntry(
              userId: e.value['id'] as String,
              username: e.value['username'] as String? ?? '',
              avatarUrl: e.value['avatar_url'] as String?,
              period: period.name,
              score: e.value['total_words_mastered'] as int? ?? 0,
              wordsMastered: e.value['total_words_mastered'] as int? ?? 0,
              rank: e.key + 1,
            ))
        .toList();
