import 'package:drift/drift.dart' show Value;
import '../../core/utils/fsrs_algorithm.dart' show CardState;
import '../../domain/entities/variant_progress.dart';
import '../datasources/local/app_database.dart';

extension VariantProgressDto on VariantProgress {
  VariantProgressTableCompanion toLocalCompanion() =>
      VariantProgressTableCompanion(
        id: Value(id),
        userId: Value(userId),
        variantId: Value(variantId),
        direction: Value(direction.name),
        stability: Value(stability),
        difficulty: Value(difficulty),
        elapsedDays: Value(elapsedDays),
        scheduledDays: Value(scheduledDays),
        reps: Value(reps),
        lapses: Value(lapses),
        state: Value(state.name),
        lastReview: Value(lastReview),
        nextReview: Value(nextReview),
        timesShown: Value(timesShown),
        timesCorrect: Value(timesCorrect),
        masteryLevel: Value(masteryLevel),
        isSynced: Value(isSynced),
        createdAt: Value(createdAt),
        updatedAt: Value(updatedAt),
      );

  Map<String, dynamic> toRemoteMap() => {
        'id': id,
        'user_id': userId,
        'variant_id': variantId,
        'direction': direction.name,
        'stability': stability,
        'difficulty': difficulty,
        'elapsed_days': elapsedDays,
        'scheduled_days': scheduledDays,
        'reps': reps,
        'lapses': lapses,
        'state': state.name,
        'last_review': lastReview?.toIso8601String(),
        'next_review': nextReview?.toIso8601String(),
        'times_shown': timesShown,
        'times_correct': timesCorrect,
        'mastery_level': masteryLevel,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

extension VariantProgressFromLocal on VariantProgressTableData {
  VariantProgress toDomain() => VariantProgress(
        id: id,
        userId: userId,
        variantId: variantId,
        direction: QuizDirection.values.byName(direction),
        stability: stability,
        difficulty: difficulty,
        elapsedDays: elapsedDays,
        scheduledDays: scheduledDays,
        reps: reps,
        lapses: lapses,
        state: CardState.values.byName(state),
        lastReview: lastReview,
        nextReview: nextReview,
        timesShown: timesShown,
        timesCorrect: timesCorrect,
        masteryLevel: masteryLevel,
        isSynced: isSynced,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}
