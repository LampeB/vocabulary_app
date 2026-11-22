import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/core/utils/streak.dart';

/// Daily-streak day-boundary rules (extracted from the social datasource's
/// updateStreak). Pure → host-testable without Supabase.
void main() {
  group('computeStreak', () {
    test('first ever study → streak 1', () {
      final u = computeStreak(
          today: DateTime(2026, 7, 2), lastStudyDate: null, currentStreak: 0);
      expect(u.streak, 1);
      expect(u.alreadyCountedToday, isFalse);
    });

    test('already studied today → unchanged and flagged, ignoring time', () {
      final u = computeStreak(
        today: DateTime(2026, 7, 2, 22, 0),
        lastStudyDate: DateTime(2026, 7, 2, 8, 0),
        currentStreak: 5,
      );
      expect(u.streak, 5);
      expect(u.alreadyCountedToday, isTrue);
    });

    test('studied yesterday → streak grows by one', () {
      final u = computeStreak(
        today: DateTime(2026, 7, 2),
        lastStudyDate: DateTime(2026, 7, 1),
        currentStreak: 5,
      );
      expect(u.streak, 6);
      expect(u.alreadyCountedToday, isFalse);
    });

    test('a two-day gap resets the streak to 1', () {
      final u = computeStreak(
        today: DateTime(2026, 7, 2),
        lastStudyDate: DateTime(2026, 6, 30),
        currentStreak: 12,
      );
      expect(u.streak, 1);
    });

    test('yesterday across a month boundary still counts as consecutive', () {
      final u = computeStreak(
        today: DateTime(2026, 8, 1),
        lastStudyDate: DateTime(2026, 7, 31),
        currentStreak: 9,
      );
      expect(u.streak, 10);
    });
  });
}
