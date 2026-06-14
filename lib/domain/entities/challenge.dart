import 'package:freezed_annotation/freezed_annotation.dart';

part 'challenge.freezed.dart';
part 'challenge.g.dart';

enum ChallengeStatus { pending, active, completed, declined, expired }

@freezed
class Challenge with _$Challenge {
  const factory Challenge({
    required String id,
    required String listId,
    required String listName,
    required String challengerId,
    required String challengedId,
    required AppUserSummaryC challenger,
    required AppUserSummaryC challenged,
    @Default(ChallengeStatus.pending) ChallengeStatus status,
    int? challengerScore,
    int? challengedScore,
    @Default(0) int wordCount,
    DateTime? expiresAt,
    required DateTime createdAt,
  }) = _Challenge;

  factory Challenge.fromJson(Map<String, dynamic> json) =>
      _$ChallengeFromJson(json);
}

@freezed
class AppUserSummaryC with _$AppUserSummaryC {
  const factory AppUserSummaryC({
    required String id,
    required String username,
    String? avatarUrl,
  }) = _AppUserSummaryC;

  factory AppUserSummaryC.fromJson(Map<String, dynamic> json) =>
      _$AppUserSummaryCFromJson(json);
}
