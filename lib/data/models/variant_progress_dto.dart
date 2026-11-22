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

/// Maps a remote `variant_progress` row to a local companion, normalizing
/// legacy direction spellings and marking the row synced (it just came from
/// the server). Inverse of [VariantProgressDto.toRemoteMap].
VariantProgressTableCompanion variantProgressCompanionFromRemote(
        Map<String, dynamic> m) =>
    VariantProgressTableCompanion(
      id: Value(m['id'] as String),
      userId: Value(m['user_id'] as String),
      variantId: Value(m['variant_id'] as String),
      direction: Value(QuizDirection.parse(m['direction'] as String).name),
      stability: Value((m['stability'] as num).toDouble()),
      difficulty: Value((m['difficulty'] as num).toDouble()),
      elapsedDays: Value((m['elapsed_days'] as num).toInt()),
      scheduledDays: Value((m['scheduled_days'] as num).toInt()),
      reps: Value((m['reps'] as num).toInt()),
      lapses: Value((m['lapses'] as num).toInt()),
      state: Value(CardState.values.byName(m['state'] as String).name),
      lastReview: Value(m['last_review'] == null
          ? null
          : DateTime.parse(m['last_review'] as String)),
      nextReview: Value(m['next_review'] == null
          ? null
          : DateTime.parse(m['next_review'] as String)),
      timesShown: Value((m['times_shown'] as num).toInt()),
      timesCorrect: Value((m['times_correct'] as num).toInt()),
      masteryLevel: Value((m['mastery_level'] as num).toDouble()),
      isSynced: const Value(true),
      createdAt: Value(DateTime.parse(m['created_at'] as String)),
      updatedAt: Value(DateTime.parse(m['updated_at'] as String)),
    );

extension VariantProgressFromLocal on VariantProgressTableData {
  VariantProgress toDomain() => VariantProgress(
        id: id,
        userId: userId,
        variantId: variantId,
        direction: QuizDirection.parse(direction),
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
