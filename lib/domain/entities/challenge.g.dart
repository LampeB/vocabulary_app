// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'challenge.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ChallengeImpl _$$ChallengeImplFromJson(Map<String, dynamic> json) =>
    _$ChallengeImpl(
      id: json['id'] as String,
      listId: json['listId'] as String,
      listName: json['listName'] as String,
      challengerId: json['challengerId'] as String,
      challengedId: json['challengedId'] as String,
      challenger:
          AppUserSummaryC.fromJson(json['challenger'] as Map<String, dynamic>),
      challenged:
          AppUserSummaryC.fromJson(json['challenged'] as Map<String, dynamic>),
      status: $enumDecodeNullable(_$ChallengeStatusEnumMap, json['status']) ??
          ChallengeStatus.pending,
      challengerScore: (json['challengerScore'] as num?)?.toInt(),
      challengedScore: (json['challengedScore'] as num?)?.toInt(),
      wordCount: (json['wordCount'] as num?)?.toInt() ?? 0,
      expiresAt: json['expiresAt'] == null
          ? null
          : DateTime.parse(json['expiresAt'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$$ChallengeImplToJson(_$ChallengeImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'listId': instance.listId,
      'listName': instance.listName,
      'challengerId': instance.challengerId,
      'challengedId': instance.challengedId,
      'challenger': instance.challenger,
      'challenged': instance.challenged,
      'status': _$ChallengeStatusEnumMap[instance.status]!,
      'challengerScore': instance.challengerScore,
      'challengedScore': instance.challengedScore,
      'wordCount': instance.wordCount,
      'expiresAt': instance.expiresAt?.toIso8601String(),
      'createdAt': instance.createdAt.toIso8601String(),
    };

const _$ChallengeStatusEnumMap = {
  ChallengeStatus.pending: 'pending',
  ChallengeStatus.active: 'active',
  ChallengeStatus.completed: 'completed',
  ChallengeStatus.declined: 'declined',
  ChallengeStatus.expired: 'expired',
};

_$AppUserSummaryCImpl _$$AppUserSummaryCImplFromJson(
        Map<String, dynamic> json) =>
    _$AppUserSummaryCImpl(
      id: json['id'] as String,
      username: json['username'] as String,
      avatarUrl: json['avatarUrl'] as String?,
    );

Map<String, dynamic> _$$AppUserSummaryCImplToJson(
        _$AppUserSummaryCImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'username': instance.username,
      'avatarUrl': instance.avatarUrl,
    };
