import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_user.freezed.dart';
part 'app_user.g.dart';

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
    @Default(false) bool isPremium,
    required DateTime createdAt,
  }) = _AppUser;

  factory AppUser.fromJson(Map<String, dynamic> json) => _$AppUserFromJson(json);
}
