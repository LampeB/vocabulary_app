import 'package:freezed_annotation/freezed_annotation.dart';
import '../../core/utils/fsrs_algorithm.dart';

part 'variant_progress.freezed.dart';
part 'variant_progress.g.dart';

// CardState is re-exported from fsrs_algorithm.dart
enum QuizDirection { frToKo, koToFr }

@freezed
class VariantProgress with _$VariantProgress {
  const factory VariantProgress({
    required String id,
    required String userId,
    required String variantId,
    required QuizDirection direction,
    @Default(0.0) double stability,
    @Default(5.0) double difficulty,
    @Default(0) int elapsedDays,
    @Default(0) int scheduledDays,
    @Default(0) int reps,
    @Default(0) int lapses,
    @Default(CardState.newCard) CardState state,
    DateTime? lastReview,
    DateTime? nextReview,
    @Default(0) int timesShown,
    @Default(0) int timesCorrect,
    @Default(0.0) double masteryLevel,
    @Default(false) bool isSynced,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _VariantProgress;

  factory VariantProgress.fromJson(Map<String, dynamic> json) =>
      _$VariantProgressFromJson(json);
}
