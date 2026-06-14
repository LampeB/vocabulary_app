import 'package:freezed_annotation/freezed_annotation.dart';

part 'friendship.freezed.dart';
part 'friendship.g.dart';

enum FriendRequestStatus { pending, accepted, declined }

@freezed
class FriendRequest with _$FriendRequest {
  const factory FriendRequest({
    required String id,
    required String fromUserId,
    required String toUserId,
    @Default(FriendRequestStatus.pending) FriendRequestStatus status,
    required DateTime createdAt,
  }) = _FriendRequest;

  factory FriendRequest.fromJson(Map<String, dynamic> json) =>
      _$FriendRequestFromJson(json);
}

@freezed
class Friendship with _$Friendship {
  const factory Friendship({
    required String id,
    required String userAId,
    required String userBId,
    required AppUserSummary friend,
    required DateTime createdAt,
  }) = _Friendship;

  factory Friendship.fromJson(Map<String, dynamic> json) =>
      _$FriendshipFromJson(json);
}

@freezed
class AppUserSummary with _$AppUserSummary {
  const factory AppUserSummary({
    required String id,
    required String username,
    String? displayName,
    String? avatarUrl,
    @Default(0) int currentStreak,
    @Default(0) int totalWordsMastered,
  }) = _AppUserSummary;

  factory AppUserSummary.fromJson(Map<String, dynamic> json) =>
      _$AppUserSummaryFromJson(json);
}
