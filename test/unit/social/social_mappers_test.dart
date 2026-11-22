import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/data/datasources/remote/social_mappers.dart';
import 'package:vocab_kr/domain/entities/leaderboard_entry.dart';

/// Leaderboard rows arrive already sorted; the mapper's job is to assign 1-based
/// ranks and null-fill missing fields. Pure → host-testable.
void main() {
  group('leaderboardEntriesFromRows', () {
    test('assigns 1-based ranks in row order', () {
      final rows = [
        {'id': 'a', 'username': 'ann', 'total_words_mastered': 90},
        {'id': 'b', 'username': 'bob', 'total_words_mastered': 50},
        {'id': 'c', 'username': 'cy', 'total_words_mastered': 10},
      ];

      final entries =
          leaderboardEntriesFromRows(rows, LeaderboardPeriod.weekly);

      expect(entries.map((e) => e.rank), [1, 2, 3]);
      expect(entries.map((e) => e.userId), ['a', 'b', 'c']);
      expect(entries.first.score, 90);
      expect(entries.first.period, 'weekly');
    });

    test('score mirrors wordsMastered', () {
      final entries = leaderboardEntriesFromRows(
        [
          {'id': 'a', 'username': 'ann', 'total_words_mastered': 42}
        ],
        LeaderboardPeriod.allTime,
      );
      expect(entries.single.score, 42);
      expect(entries.single.wordsMastered, 42);
      expect(entries.single.period, 'allTime');
    });

    test('missing username / score default to empty / zero', () {
      final entries = leaderboardEntriesFromRows(
        [
          {'id': 'a'}
        ],
        LeaderboardPeriod.monthly,
      );
      expect(entries.single.username, '');
      expect(entries.single.score, 0);
      expect(entries.single.wordsMastered, 0);
      expect(entries.single.avatarUrl, isNull);
      expect(entries.single.rank, 1);
    });

    test('empty input → empty list', () {
      expect(leaderboardEntriesFromRows([], LeaderboardPeriod.weekly), isEmpty);
    });
  });
}
