import '../../domain/entities/friendship.dart';
import '../../domain/entities/challenge.dart';
import '../../domain/entities/leaderboard_entry.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/social_repository.dart';
import '../../core/errors/failure.dart';
import '../../core/errors/app_exception.dart';
import '../datasources/remote/social_remote_datasource.dart';

class SocialRepositoryImpl implements SocialRepository {
  SocialRepositoryImpl(this._remote);
  final SocialRemoteDataSource _remote;

  @override
  Future<Result<List<AppUser>>> searchUsers(String query) =>
      _remote.searchUsers(query);

  @override
  Stream<List<Friendship>> watchFriends() =>
      Stream.fromFuture(_remote.getFriends());

  @override
  Stream<List<FriendRequest>> watchPendingRequests() =>
      Stream.fromFuture(_remote.getPendingRequests());

  @override
  Future<Result<void>> sendFriendRequest(String toUserId) =>
      _remote.sendFriendRequest(toUserId);

  @override
  Future<Result<void>> acceptFriendRequest(String requestId) =>
      _remote.acceptFriendRequest(requestId);

  @override
  Future<Result<void>> declineFriendRequest(String requestId) =>
      _remote.declineFriendRequest(requestId);

  @override
  Future<Result<void>> removeFriend(String friendshipId) =>
      _remote.removeFriend(friendshipId);

  // ─── Challenges (Phase 6+) ────────────────────────────────────────────────

  @override
  Stream<List<Challenge>> watchChallenges() => Stream.value(const []);

  @override
  Future<Result<Challenge>> sendChallenge({
    required String toUserId,
    required String listId,
    int daysToComplete = 7,
  }) async =>
      const Failure(UnknownException('Challenges coming soon'));

  @override
  Future<Result<void>> acceptChallenge(String challengeId) async =>
      const Failure(UnknownException('Challenges coming soon'));

  @override
  Future<Result<void>> declineChallenge(String challengeId) async =>
      const Failure(UnknownException('Challenges coming soon'));

  @override
  Future<Result<void>> submitChallengeScore(
          String challengeId, int score) async =>
      const Failure(UnknownException('Challenges coming soon'));

  // ─── Leaderboard ─────────────────────────────────────────────────────────────

  @override
  Future<Result<List<LeaderboardEntry>>> getLeaderboard({
    required LeaderboardPeriod period,
    bool friendsOnly = false,
    int limit = 100,
  }) =>
      _remote.getLeaderboard(period: period, limit: limit);

  @override
  Future<Result<LeaderboardEntry?>> getMyRank(LeaderboardPeriod period) =>
      _remote.getMyRank(period);
}
