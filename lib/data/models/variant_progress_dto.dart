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
        'last_review': lastReview?.toUtc().toIso8601String(),
        'next_review': nextReview?.toUtc().toIso8601String(),
        'times_shown': timesShown,
        'times_correct': timesCorrect,
        'mastery_level': masteryLevel,
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };
}

/// Maps a remote `variant_progress` row to a local companion, normalizing
/// legacy direction spellings and marking the row synced (it just came from
/// the server). Inverse of [VariantProgressDto.toRemoteMap].
VariantProgressTableCompanion variantProgressCompanionFromRemote(
        Map<String, dynamic> row) =>
    variantProgressFromRemote(row).toCompanion(false);

VariantProgressTableData variantProgressFromRemote(Map<String, dynamic> row) =>
    VariantProgressTableData(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      variantId: row['variant_id'] as String,
      direction: QuizDirection.parse(row['direction'] as String).name,
      stability: (row['stability'] as num).toDouble(),
      difficulty: (row['difficulty'] as num).toDouble(),
      elapsedDays: (row['elapsed_days'] as num).toInt(),
      scheduledDays: (row['scheduled_days'] as num).toInt(),
      reps: (row['reps'] as num).toInt(),
      lapses: (row['lapses'] as num).toInt(),
      state: CardState.values.byName(row['state'] as String).name,
      lastReview: _localDateTime(row['last_review'] as String?),
      nextReview: _localDateTime(row['next_review'] as String?),
      timesShown: (row['times_shown'] as num).toInt(),
      timesCorrect: (row['times_correct'] as num).toInt(),
      masteryLevel: (row['mastery_level'] as num).toDouble(),
      isSynced: true,
      createdAt: _localDateTime(row['created_at'] as String)!,
      updatedAt: _localDateTime(row['updated_at'] as String)!,
    );

// Match Drift's second-precision storage when comparing rows before a write.
DateTime? _localDateTime(String? value) {
  if (value == null) return null;
  final time = DateTime.parse(value);
  return DateTime.fromMillisecondsSinceEpoch(
      (time.millisecondsSinceEpoch ~/ 1000) * 1000);
}

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
