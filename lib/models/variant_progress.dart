class VariantProgress {
  final String id;
  final String variantId;
  final String direction; // 'lang1_to_lang2' ou 'lang2_to_lang1'
  final int timesShownAsQuestion;
  final int timesShownAsAnswer;
  final int timesAnsweredCorrectly;
  final int timesUserPreferred;
  final String? lastSeenDate;
  final String? nextReviewDate;
  final double masteryLevel;
  final bool isKnown;

  VariantProgress({
    required this.id,
    required this.variantId,
    required this.direction,
    this.timesShownAsQuestion = 0,
    this.timesShownAsAnswer = 0,
    this.timesAnsweredCorrectly = 0,
    this.timesUserPreferred = 0,
    this.lastSeenDate,
    this.nextReviewDate,
    double? masteryLevel,
    bool? isKnown,
  })  : masteryLevel = masteryLevel ?? _calculateMasteryLevel(timesAnsweredCorrectly, timesShownAsAnswer),
        isKnown = isKnown ?? _calculateIsKnown(masteryLevel, timesAnsweredCorrectly, timesShownAsAnswer);

  // Calcul du niveau de maîtrise
  static double _calculateMasteryLevel(int correct, int shown) {
    if (shown == 0) return 0.0;
    return correct / shown;
  }

  // Détermine si le mot est connu (seuil: 0.7)
  static bool _calculateIsKnown(double? providedMasteryLevel, int correct, int shown) {
    final level = providedMasteryLevel ?? _calculateMasteryLevel(correct, shown);
    return level >= 0.7;
  }

  // Conversion depuis Map (SQLite)
  factory VariantProgress.fromMap(Map<String, dynamic> map) {
    return VariantProgress(
      id: map['id'] as String,
      variantId: map['variant_id'] as String,
      direction: map['direction'] as String,
      timesShownAsQuestion: map['times_shown_as_question'] as int? ?? 0,
      timesShownAsAnswer: map['times_shown_as_answer'] as int? ?? 0,
      timesAnsweredCorrectly: map['times_answered_correctly'] as int? ?? 0,
      timesUserPreferred: map['times_user_preferred'] as int? ?? 0,
      lastSeenDate: map['last_seen_date'] as String?,
      nextReviewDate: map['next_review_date'] as String?,
      masteryLevel: map['mastery_level'] as double? ?? 0.0,
      isKnown: (map['is_known'] as int? ?? 0) == 1,
    );
  }

  // Conversion vers Map (SQLite)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'variant_id': variantId,
      'direction': direction,
      'times_shown_as_question': timesShownAsQuestion,
      'times_shown_as_answer': timesShownAsAnswer,
      'times_answered_correctly': timesAnsweredCorrectly,
      'times_user_preferred': timesUserPreferred,
      'last_seen_date': lastSeenDate,
      'next_review_date': nextReviewDate,
      'mastery_level': masteryLevel,
      'is_known': isKnown ? 1 : 0,
    };
  }

  // Copie avec modifications (recalcule masteryLevel et isKnown automatiquement)
  VariantProgress copyWith({
    String? id,
    String? variantId,
    String? direction,
    int? timesShownAsQuestion,
    int? timesShownAsAnswer,
    int? timesAnsweredCorrectly,
    int? timesUserPreferred,
    String? lastSeenDate,
    String? nextReviewDate,
  }) {
    final newShownAsAnswer = timesShownAsAnswer ?? this.timesShownAsAnswer;
    final newAnsweredCorrectly = timesAnsweredCorrectly ?? this.timesAnsweredCorrectly;

    return VariantProgress(
      id: id ?? this.id,
      variantId: variantId ?? this.variantId,
      direction: direction ?? this.direction,
      timesShownAsQuestion: timesShownAsQuestion ?? this.timesShownAsQuestion,
      timesShownAsAnswer: newShownAsAnswer,
      timesAnsweredCorrectly: newAnsweredCorrectly,
      timesUserPreferred: timesUserPreferred ?? this.timesUserPreferred,
      lastSeenDate: lastSeenDate ?? this.lastSeenDate,
      nextReviewDate: nextReviewDate ?? this.nextReviewDate,
      // Recalcul automatique
      masteryLevel: _calculateMasteryLevel(newAnsweredCorrectly, newShownAsAnswer),
      isKnown: _calculateIsKnown(null, newAnsweredCorrectly, newShownAsAnswer),
    );
  }

  @override
  String toString() {
    return 'VariantProgress(variant: $variantId, direction: $direction, mastery: ${(masteryLevel * 100).toStringAsFixed(1)}%, known: $isKnown)';
  }
}
