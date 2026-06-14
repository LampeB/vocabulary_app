import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/failure.dart';
import '../../../data/datasources/remote/social_remote_datasource.dart';
import '../../../data/repositories/social_repository_impl.dart';
import '../../../domain/entities/friendship.dart';
import '../../../domain/entities/leaderboard_entry.dart';
import '../../../domain/entities/app_user.dart';
import '../../../domain/repositories/social_repository.dart';
import '../auth/auth_provider.dart';

final socialRemoteDataSourceProvider = Provider<SocialRemoteDataSource>((ref) {
  return SocialRemoteDataSource(
    ref.watch(supabaseClientProvider),
    ref.watch(currentUserProvider)?.id ?? '',
  );
});

final socialRepositoryProvider = Provider<SocialRepository>((ref) {
  return SocialRepositoryImpl(ref.watch(socialRemoteDataSourceProvider));
});

// ─── Friends ──────────────────────────────────────────────────────────────────

final friendsProvider = StreamProvider<List<Friendship>>((ref) {
  return ref.watch(socialRepositoryProvider).watchFriends();
});

final pendingRequestsProvider = StreamProvider<List<FriendRequest>>((ref) {
  return ref.watch(socialRepositoryProvider).watchPendingRequests();
});

// ─── User search ──────────────────────────────────────────────────────────────

final userSearchProvider =
    FutureProvider.autoDispose.family<Result<List<AppUser>>, String>(
        (ref, query) {
  if (query.length < 2) return Future.value(const Success([]));
  return ref.watch(socialRepositoryProvider).searchUsers(query);
});

final userSummaryProvider =
    FutureProvider.autoDispose.family<AppUserSummary?, String>((ref, userId) async {
  final result =
      await ref.watch(socialRemoteDataSourceProvider).getUserSummary(userId);
  return result.valueOrNull;
});

// ─── Leaderboard ─────────────────────────────────────────────────────────────

final leaderboardPeriodProvider =
    StateProvider<LeaderboardPeriod>((_) => LeaderboardPeriod.weekly);

final leaderboardProvider =
    FutureProvider.autoDispose.family<Result<List<LeaderboardEntry>>, LeaderboardPeriod>(
        (ref, period) {
  return ref
      .watch(socialRepositoryProvider)
      .getLeaderboard(period: period, limit: 100);
});

// ─── Social actions ───────────────────────────────────────────────────────────

class SocialActionsNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  SocialRepository get _repo => ref.read(socialRepositoryProvider);

  Future<bool> sendRequest(String toUserId) async {
    state = const AsyncLoading();
    final result = await _repo.sendFriendRequest(toUserId);
    state = const AsyncData(null);
    return result.isSuccess;
  }

  Future<void> acceptRequest(String requestId) async {
    state = const AsyncLoading();
    await _repo.acceptFriendRequest(requestId);
    state = const AsyncData(null);
    ref.invalidate(friendsProvider);
    ref.invalidate(pendingRequestsProvider);
  }

  Future<void> declineRequest(String requestId) async {
    state = const AsyncLoading();
    await _repo.declineFriendRequest(requestId);
    state = const AsyncData(null);
    ref.invalidate(pendingRequestsProvider);
  }

  Future<void> removeFriend(String friendshipId) async {
    state = const AsyncLoading();
    await _repo.removeFriend(friendshipId);
    state = const AsyncData(null);
    ref.invalidate(friendsProvider);
  }
}

final socialActionsProvider =
    NotifierProvider<SocialActionsNotifier, AsyncValue<void>>(
        SocialActionsNotifier.new);
