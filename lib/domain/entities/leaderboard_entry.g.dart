// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'leaderboard_entry.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$LeaderboardEntryImpl _$$LeaderboardEntryImplFromJson(
        Map<String, dynamic> json) =>
    _$LeaderboardEntryImpl(
      userId: json['userId'] as String,
      username: json['username'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      period: json['period'] as String,
      score: (json['score'] as num?)?.toInt() ?? 0,
      wordsMastered: (json['wordsMastered'] as num?)?.toInt() ?? 0,
      rank: (json['rank'] as num?)?.toInt(),
    );

Map<String, dynamic> _$$LeaderboardEntryImplToJson(
        _$LeaderboardEntryImpl instance) =>
    <String, dynamic>{
      'userId': instance.userId,
      'username': instance.username,
      'avatarUrl': instance.avatarUrl,
      'period': instance.period,
      'score': instance.score,
      'wordsMastered': instance.wordsMastered,
      'rank': instance.rank,
    };
