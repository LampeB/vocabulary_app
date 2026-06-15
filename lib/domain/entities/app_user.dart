import 'package:freezed_annotation/freezed_annotation.dart';
import 'subscription_type.dart';

part 'app_user.freezed.dart';
part 'app_user.g.dart';

SubscriptionType _subscriptionTypeFromJson(String? v) =>
    SubscriptionType.fromString(v);
String _subscriptionTypeToJson(SubscriptionType t) => t.name;

@freezed
class AppUser with _$AppUser {
  const factory AppUser({
    required String id,
    required String email,
    required String username,
    String? displayName,
    String? avatarUrl,
    String? bio,
    @Default(0) int totalWordsMastered,
    @Default(0) int currentStreak,
    @Default(0) int longestStreak,
    DateTime? lastStudyDate,
    @JsonKey(
      fromJson: _subscriptionTypeFromJson,
      toJson: _subscriptionTypeToJson,
    )
    @Default(SubscriptionType.free)
    SubscriptionType subscriptionType,
    required DateTime createdAt,
  }) = _AppUser;

  factory AppUser.fromJson(Map<String, dynamic> json) =>
      _$AppUserFromJson(json);
}
