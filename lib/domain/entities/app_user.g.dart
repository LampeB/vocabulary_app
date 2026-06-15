// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AppUserImpl _$$AppUserImplFromJson(Map<String, dynamic> json) =>
    _$AppUserImpl(
      id: json['id'] as String,
      email: json['email'] as String,
      username: json['username'] as String,
      displayName: json['displayName'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      bio: json['bio'] as String?,
      totalWordsMastered: (json['totalWordsMastered'] as num?)?.toInt() ?? 0,
      currentStreak: (json['currentStreak'] as num?)?.toInt() ?? 0,
      longestStreak: (json['longestStreak'] as num?)?.toInt() ?? 0,
      lastStudyDate: json['lastStudyDate'] == null
          ? null
          : DateTime.parse(json['lastStudyDate'] as String),
      subscriptionType: json['subscriptionType'] == null
          ? SubscriptionType.free
          : _subscriptionTypeFromJson(json['subscriptionType'] as String?),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$$AppUserImplToJson(_$AppUserImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'email': instance.email,
      'username': instance.username,
      'displayName': instance.displayName,
      'avatarUrl': instance.avatarUrl,
      'bio': instance.bio,
      'totalWordsMastered': instance.totalWordsMastered,
      'currentStreak': instance.currentStreak,
      'longestStreak': instance.longestStreak,
      'lastStudyDate': instance.lastStudyDate?.toIso8601String(),
      'subscriptionType': _subscriptionTypeToJson(instance.subscriptionType),
      'createdAt': instance.createdAt.toIso8601String(),
    };
