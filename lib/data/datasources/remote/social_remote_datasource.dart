import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/errors/failure.dart';
import '../../../domain/entities/friendship.dart';
import '../../../domain/entities/leaderboard_entry.dart';
import '../../../domain/entities/app_user.dart';
import '../../../domain/entities/subscription_type.dart';

class SocialRemoteDataSource {
  SocialRemoteDataSource(this._client, this._userId);

  final SupabaseClient _client;
  final String _userId;

  // ─── Search ──────────────────────────────────────────────────────────────────

  Future<Result<List<AppUser>>> searchUsers(String query) async {
    try {
      final rows = await _client
          .from('profiles')
          .select()
          .or('username.ilike.%$query%,display_name.ilike.%$query%')
          .neq('id', _userId)
          .limit(20);
      return Success(
          List<Map<String, dynamic>>.from(rows as List).map(_rowToAppUser).toList());
    } catch (e) {
      return Failure(NetworkException(e.toString()));
    }
  }

  Future<Result<AppUserSummary?>> getUserSummary(String userId) async {
    try {
      final rows = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .limit(1);
      final list = List<Map<String, dynamic>>.from(rows as List);
      return Success(list.isEmpty ? null : _rowToSummary(list.first));
    } catch (e) {
      return Failure(NetworkException(e.toString()));
    }
  }

  // ─── Friends ─────────────────────────────────────────────────────────────────

  Future<List<Friendship>> getFriends() async {
    final asA = List<Map<String, dynamic>>.from(
        (await _client
                .from('friendships')
                .select('id, user_b_id, created_at')
                .eq('user_a_id', _userId)) as List);
    final asB = List<Map<String, dynamic>>.from(
        (await _client
                .from('friendships')
                .select('id, user_a_id, created_at')
                .eq('user_b_id', _userId)) as List);

    final entries = [
      ...asA.map((r) => ({
            'id': r['id'],
            'userAId': _userId,
            'userBId': r['user_b_id'],
            'friendId': r['user_b_id'],
            'createdAt': r['created_at'],
          })),
      ...asB.map((r) => ({
            'id': r['id'],
            'userAId': r['user_a_id'],
            'userBId': _userId,
            'friendId': r['user_a_id'],
            'createdAt': r['created_at'],
          })),
    ];

    if (entries.isEmpty) return [];

    final friendIds = entries.map((e) => e['friendId'] as String).toList();
    final profileRows = List<Map<String, dynamic>>.from(
        (await _client.from('profiles').select().inFilter('id', friendIds)) as List);
    final profileMap = {for (final p in profileRows) p['id'] as String: p};

    return entries
        .where((e) => profileMap.containsKey(e['friendId'] as String))
        .map((e) => Friendship(
              id: e['id'] as String,
              userAId: e['userAId'] as String,
              userBId: e['userBId'] as String,
              createdAt: DateTime.parse(e['createdAt'] as String),
              friend: _rowToSummary(profileMap[e['friendId'] as String]!),
            ))
        .toList();
  }

  Future<List<FriendRequest>> getPendingRequests() async {
    final rows = List<Map<String, dynamic>>.from(
        (await _client
                .from('friend_requests')
                .select()
                .eq('to_user_id', _userId)
                .eq('status', 'pending')
                .order('created_at', ascending: false)) as List);
    return rows.map(_rowToFriendRequest).toList();
  }

  Future<Result<void>> sendFriendRequest(String toUserId) async {
    try {
      await _client.from('friend_requests').insert({
        'from_user_id': _userId,
        'to_user_id': toUserId,
        'status': 'pending',
      });
      return const Success(null);
    } catch (e) {
      return Failure(NetworkException(e.toString()));
    }
  }

  Future<Result<void>> acceptFriendRequest(String requestId) async {
    try {
      final req = await _client
          .from('friend_requests')
          .select()
          .eq('id', requestId)
          .single() as Map<String, dynamic>;
      final fromUserId = req['from_user_id'] as String;

      await _client
          .from('friend_requests')
          .update({'status': 'accepted'}).eq('id', requestId);

      // Enforce user_a < user_b to prevent duplicate rows
      final sorted = [_userId, fromUserId]..sort();
      await _client.from('friendships').upsert({
        'user_a_id': sorted[0],
        'user_b_id': sorted[1],
      });
      return const Success(null);
    } catch (e) {
      return Failure(NetworkException(e.toString()));
    }
  }

  Future<Result<void>> declineFriendRequest(String requestId) async {
    try {
      await _client
          .from('friend_requests')
          .update({'status': 'declined'}).eq('id', requestId);
      return const Success(null);
    } catch (e) {
      return Failure(NetworkException(e.toString()));
    }
  }

  Future<Result<void>> removeFriend(String friendshipId) async {
    try {
      await _client.from('friendships').delete().eq('id', friendshipId);
      return const Success(null);
    } catch (e) {
      return Failure(NetworkException(e.toString()));
    }
  }

  // ─── Leaderboard (live from profiles table) ───────────────────────────────

  Future<Result<List<LeaderboardEntry>>> getLeaderboard({
    required LeaderboardPeriod period,
    int limit = 100,
  }) async {
    try {
      final rows = List<Map<String, dynamic>>.from(
          (await _client
                  .from('profiles')
                  .select('id, username, avatar_url, total_words_mastered')
                  .order('total_words_mastered', ascending: false)
                  .limit(limit)) as List);
      return Success(rows
          .asMap()
          .entries
          .map((e) => LeaderboardEntry(
                userId: e.value['id'] as String,
                username: e.value['username'] as String? ?? '',
                avatarUrl: e.value['avatar_url'] as String?,
                period: period.name,
                score: e.value['total_words_mastered'] as int? ?? 0,
                wordsMastered: e.value['total_words_mastered'] as int? ?? 0,
                rank: e.key + 1,
              ))
          .toList());
    } catch (e) {
      return Failure(NetworkException(e.toString()));
    }
  }

  Future<Result<LeaderboardEntry?>> getMyRank(LeaderboardPeriod period) async {
    try {
      final rows = List<Map<String, dynamic>>.from(
          (await _client
                  .from('profiles')
                  .select('id, username, avatar_url, total_words_mastered')
                  .eq('id', _userId)
                  .limit(1)) as List);
      if (rows.isEmpty) return const Success(null);
      final r = rows.first;
      return Success(LeaderboardEntry(
        userId: r['id'] as String,
        username: r['username'] as String? ?? '',
        avatarUrl: r['avatar_url'] as String?,
        period: period.name,
        score: r['total_words_mastered'] as int? ?? 0,
        wordsMastered: r['total_words_mastered'] as int? ?? 0,
      ));
    } catch (e) {
      return Failure(NetworkException(e.toString()));
    }
  }

  // ─── Streak update ────────────────────────────────────────────────────────

  Future<Result<void>> updateStreak() async {
    try {
      final rows = List<Map<String, dynamic>>.from(
          (await _client
                  .from('profiles')
                  .select('current_streak, longest_streak, last_study_date')
                  .eq('id', _userId)
                  .limit(1)) as List);
      if (rows.isEmpty) return const Success(null);
      final profile = rows.first;

      final today = DateTime.now().toLocal();
      final todayDate =
          DateTime(today.year, today.month, today.day);
      final lastRaw = profile['last_study_date'] as String?;

      if (lastRaw != null) {
        final last = DateTime.parse(lastRaw);
        final lastDay =
            DateTime(last.year, last.month, last.day);
        if (lastDay == todayDate) return const Success(null); // already counted
      }

      final current = profile['current_streak'] as int? ?? 0;
      final longest = profile['longest_streak'] as int? ?? 0;
      final yesterday = todayDate.subtract(const Duration(days: 1));

      int newStreak;
      if (lastRaw != null) {
        final last = DateTime.parse(lastRaw);
        final lastDay = DateTime(last.year, last.month, last.day);
        newStreak = lastDay == yesterday ? current + 1 : 1;
      } else {
        newStreak = 1;
      }

      final pad2 = (int n) => n.toString().padLeft(2, '0');
      final dateStr =
          '${todayDate.year}-${pad2(todayDate.month)}-${pad2(todayDate.day)}';

      await _client.from('profiles').update({
        'current_streak': newStreak,
        'longest_streak': newStreak > longest ? newStreak : longest,
        'last_study_date': dateStr,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', _userId);

      return const Success(null);
    } catch (e) {
      return Failure(NetworkException(e.toString()));
    }
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  AppUserSummary _rowToSummary(Map<String, dynamic> p) => AppUserSummary(
        id: p['id'] as String,
        username: p['username'] as String? ?? '',
        displayName: p['display_name'] as String?,
        avatarUrl: p['avatar_url'] as String?,
        currentStreak: p['current_streak'] as int? ?? 0,
        totalWordsMastered: p['total_words_mastered'] as int? ?? 0,
      );

  AppUser _rowToAppUser(Map<String, dynamic> p) => AppUser(
        id: p['id'] as String,
        email: '',
        username: p['username'] as String? ?? '',
        displayName: p['display_name'] as String?,
        avatarUrl: p['avatar_url'] as String?,
        bio: p['bio'] as String?,
        currentStreak: p['current_streak'] as int? ?? 0,
        longestStreak: p['longest_streak'] as int? ?? 0,
        totalWordsMastered: p['total_words_mastered'] as int? ?? 0,
        subscriptionType: SubscriptionType.fromString(
            p['subscription_type'] as String?),
        createdAt: DateTime.tryParse(p['created_at'] as String? ?? '') ??
            DateTime.now(),
      );

  FriendRequest _rowToFriendRequest(Map<String, dynamic> r) => FriendRequest(
        id: r['id'] as String,
        fromUserId: r['from_user_id'] as String,
        toUserId: r['to_user_id'] as String,
        status: FriendRequestStatus.values.firstWhere(
          (s) => s.name == (r['status'] as String? ?? 'pending'),
          orElse: () => FriendRequestStatus.pending,
        ),
        createdAt: DateTime.parse(r['created_at'] as String),
      );
}
