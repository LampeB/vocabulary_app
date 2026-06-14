// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'variant_progress.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$VariantProgressImpl _$$VariantProgressImplFromJson(
        Map<String, dynamic> json) =>
    _$VariantProgressImpl(
      id: json['id'] as String,
      userId: json['userId'] as String,
      variantId: json['variantId'] as String,
      direction: $enumDecode(_$QuizDirectionEnumMap, json['direction']),
      stability: (json['stability'] as num?)?.toDouble() ?? 0.0,
      difficulty: (json['difficulty'] as num?)?.toDouble() ?? 5.0,
      elapsedDays: (json['elapsedDays'] as num?)?.toInt() ?? 0,
      scheduledDays: (json['scheduledDays'] as num?)?.toInt() ?? 0,
      reps: (json['reps'] as num?)?.toInt() ?? 0,
      lapses: (json['lapses'] as num?)?.toInt() ?? 0,
      state: $enumDecodeNullable(_$CardStateEnumMap, json['state']) ??
          CardState.newCard,
      lastReview: json['lastReview'] == null
          ? null
          : DateTime.parse(json['lastReview'] as String),
      nextReview: json['nextReview'] == null
          ? null
          : DateTime.parse(json['nextReview'] as String),
      timesShown: (json['timesShown'] as num?)?.toInt() ?? 0,
      timesCorrect: (json['timesCorrect'] as num?)?.toInt() ?? 0,
      masteryLevel: (json['masteryLevel'] as num?)?.toDouble() ?? 0.0,
      isSynced: json['isSynced'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$$VariantProgressImplToJson(
        _$VariantProgressImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'variantId': instance.variantId,
      'direction': _$QuizDirectionEnumMap[instance.direction]!,
      'stability': instance.stability,
      'difficulty': instance.difficulty,
      'elapsedDays': instance.elapsedDays,
      'scheduledDays': instance.scheduledDays,
      'reps': instance.reps,
      'lapses': instance.lapses,
      'state': _$CardStateEnumMap[instance.state]!,
      'lastReview': instance.lastReview?.toIso8601String(),
      'nextReview': instance.nextReview?.toIso8601String(),
      'timesShown': instance.timesShown,
      'timesCorrect': instance.timesCorrect,
      'masteryLevel': instance.masteryLevel,
      'isSynced': instance.isSynced,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };

const _$QuizDirectionEnumMap = {
  QuizDirection.frToKo: 'frToKo',
  QuizDirection.koToFr: 'koToFr',
};

const _$CardStateEnumMap = {
  CardState.newCard: 'newCard',
  CardState.learning: 'learning',
  CardState.review: 'review',
  CardState.relearning: 'relearning',
};
