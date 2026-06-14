import '../entities/friendship.dart';
import '../entities/challenge.dart';
import '../entities/leaderboard_entry.dart';
import '../entities/app_user.dart';
import '../../core/errors/failure.dart';

abstract interface class SocialRepository {
  // Search
  Future<Result<List<AppUser>>> searchUsers(String query);

  // Friends
  Stream<List<Friendship>> watchFriends();
  Stream<List<FriendRequest>> watchPendingRequests();
  Future<Result<void>> sendFriendRequest(String toUserId);
  Future<Result<void>> acceptFriendRequest(String requestId);
  Future<Result<void>> declineFriendRequest(String requestId);
  Future<Result<void>> removeFriend(String friendshipId);

  // Challenges
  Stream<List<Challenge>> watchChallenges();
  Future<Result<Challenge>> sendChallenge({
    required String toUserId,
    required String listId,
    int daysToComplete = 7,
  });
  Future<Result<void>> acceptChallenge(String challengeId);
  Future<Result<void>> declineChallenge(String challengeId);
  Future<Result<void>> submitChallengeScore(String challengeId, int score);

  // Leaderboard
  Future<Result<List<LeaderboardEntry>>> getLeaderboard({
    required LeaderboardPeriod period,
    bool friendsOnly = false,
    int limit = 100,
  });
  Future<Result<LeaderboardEntry?>> getMyRank(LeaderboardPeriod period);
}
