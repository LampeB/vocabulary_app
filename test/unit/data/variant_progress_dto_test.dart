import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/core/utils/fsrs_algorithm.dart';
import 'package:vocab_kr/data/models/variant_progress_dto.dart';
import 'package:vocab_kr/domain/entities/variant_progress.dart';

VariantProgress _makeProgress({
  QuizDirection direction = QuizDirection.frToKo,
  CardState state = CardState.newCard,
  DateTime? lastReview,
  DateTime? nextReview,
}) {
  final now = DateTime.utc(2025, 6, 1, 12, 0, 0);
  return VariantProgress(
    id: 'id-1',
    userId: 'user-1',
    variantId: 'variant-1',
    direction: direction,
    state: state,
    lastReview: lastReview,
    nextReview: nextReview,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('toRemoteMap — field names', () {
    late Map<String, dynamic> map;

    setUp(() {
      map = _makeProgress().toRemoteMap();
    });

    test('uses snake_case keys', () {
      expect(map.containsKey('user_id'), isTrue);
      expect(map.containsKey('variant_id'), isTrue);
      expect(map.containsKey('elapsed_days'), isTrue);
      expect(map.containsKey('scheduled_days'), isTrue);
      expect(map.containsKey('times_shown'), isTrue);
      expect(map.containsKey('times_correct'), isTrue);
      expect(map.containsKey('mastery_level'), isTrue);
      expect(map.containsKey('last_review'), isTrue);
      expect(map.containsKey('next_review'), isTrue);
      expect(map.containsKey('created_at'), isTrue);
      expect(map.containsKey('updated_at'), isTrue);
    });

    test('does NOT use camelCase keys', () {
      expect(map.containsKey('userId'), isFalse);
      expect(map.containsKey('variantId'), isFalse);
      expect(map.containsKey('elapsedDays'), isFalse);
    });
  });

  group('toRemoteMap — enum serialisation', () {
    test('frToKo direction serialises to "frToKo"', () {
      final map = _makeProgress(direction: QuizDirection.frToKo).toRemoteMap();
      expect(map['direction'], 'frToKo');
    });

    test('koToFr direction serialises to "koToFr"', () {
      final map = _makeProgress(direction: QuizDirection.koToFr).toRemoteMap();
      expect(map['direction'], 'koToFr');
    });

    test('newCard state serialises to "newCard"', () {
      final map = _makeProgress(state: CardState.newCard).toRemoteMap();
      expect(map['state'], 'newCard');
    });

    test('review state serialises to "review"', () {
      final map = _makeProgress(state: CardState.review).toRemoteMap();
      expect(map['state'], 'review');
    });

    test('learning state serialises to "learning"', () {
      final map = _makeProgress(state: CardState.learning).toRemoteMap();
      expect(map['state'], 'learning');
    });

    test('relearning state serialises to "relearning"', () {
      final map = _makeProgress(state: CardState.relearning).toRemoteMap();
      expect(map['state'], 'relearning');
    });
  });

  group('toRemoteMap — nullable dates', () {
    test('null lastReview produces null in map, not a string', () {
      final map = _makeProgress(lastReview: null).toRemoteMap();
      expect(map['last_review'], isNull);
    });

    test('null nextReview produces null in map, not a string', () {
      final map = _makeProgress(nextReview: null).toRemoteMap();
      expect(map['next_review'], isNull);
    });

    test('non-null DateTime produces an ISO 8601 string', () {
      final dt = DateTime.utc(2025, 6, 15, 10, 30);
      final map = _makeProgress(lastReview: dt).toRemoteMap();
      expect(map['last_review'], isA<String>());
      expect((map['last_review'] as String).contains('T'), isTrue);
    });
  });
}
