import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/core/errors/failure.dart';
import 'package:vocab_kr/core/widget_keys.dart';
import 'package:vocab_kr/domain/entities/app_user.dart';
import 'package:vocab_kr/domain/entities/friendship.dart';
import 'package:vocab_kr/domain/entities/leaderboard_entry.dart';
import 'package:vocab_kr/domain/entities/subscription_type.dart';
import 'package:vocab_kr/domain/repositories/social_repository.dart';
import 'package:vocab_kr/data/datasources/remote/social_remote_datasource.dart';
import 'package:vocab_kr/presentation/providers/auth/auth_provider.dart';
import 'package:vocab_kr/presentation/providers/social/social_provider.dart';
import 'package:vocab_kr/presentation/screens/social/social_screen.dart';
import '../../helpers/pump_screen.dart';

/// Social screen against a fake SocialRepository: friends list, pending
/// request accept flow, and the leaderboard tab with rank display.

final _now = DateTime(2026, 7, 3);

AppUserSummary _summary(String id, String name) => AppUserSummary(
      id: id,
      username: name,
      displayName: name,
      currentStreak: 3,
      totalWordsMastered: 10,
    );

class _FakeSocialRepo implements SocialRepository {
  final accepted = <String>[];
  final declined = <String>[];
  final removed = <String>[];
  final sentTo = <String>[];
  List<Friendship> friends = [];
  List<FriendRequest> pending = [];

  @override
  Stream<List<Friendship>> watchFriends() => Stream.value(friends);
  @override
  Stream<List<FriendRequest>> watchPendingRequests() => Stream.value(pending);

  @override
  Future<Result<void>> acceptFriendRequest(String requestId) async {
    accepted.add(requestId);
    return const Success(null);
  }

  @override
  Future<Result<void>> declineFriendRequest(String requestId) async {
    declined.add(requestId);
    return const Success(null);
  }

  @override
  Future<Result<void>> removeFriend(String friendshipId) async {
    removed.add(friendshipId);
    return const Success(null);
  }

  @override
  Future<Result<void>> sendFriendRequest(String toUserId) async {
    sentTo.add(toUserId);
    return const Success(null);
  }

  @override
  Future<Result<List<AppUser>>> searchUsers(String query) async => Success([
        AppUser(
          id: 'found-user',
          email: '',
          username: 'claire',
          subscriptionType: SubscriptionType.free,
          createdAt: _now,
        ),
      ]);

  @override
  Future<Result<List<LeaderboardEntry>>> getLeaderboard({
    required LeaderboardPeriod period,
    int limit = 100,
    bool friendsOnly = false,
  }) async =>
      Success([
        LeaderboardEntry(
            userId: 'a',
            username: 'ann',
            period: period.name,
            score: 90,
            wordsMastered: 90,
            rank: 1),
        LeaderboardEntry(
            userId: 'me',
            username: 'thomas',
            period: period.name,
            score: 42,
            wordsMastered: 42,
            rank: 2),
      ]);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSocialRemote implements SocialRemoteDataSource {
  @override
  Future<Result<AppUserSummary?>> getUserSummary(String userId) async =>
      Success(_summary(userId, 'bob'));
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(initTestLocalization);

  late _FakeSocialRepo repo;

  Future<void> pump(WidgetTester tester) {
    return pumpScreen(
      tester,
      screen: const SocialScreen(),
      overrides: [
        socialRepositoryProvider.overrideWithValue(repo),
        socialRemoteDataSourceProvider.overrideWithValue(_FakeSocialRemote()),
        currentUserProvider.overrideWithValue(AppUser(
          id: 'me',
          email: 't@t.fr',
          username: 'thomas',
          subscriptionType: SubscriptionType.free,
          createdAt: _now,
        )),
      ],
    );
  }

  setUp(() => repo = _FakeSocialRepo());

  testWidgets('renders the friends tab with friend entries', (tester) async {
    repo.friends = [
      Friendship(
        id: 'f1',
        userAId: 'me',
        userBId: 'b',
        friend: _summary('b', 'bob'),
        createdAt: _now,
      ),
    ];
    await pump(tester);

    expect(find.byKey(const ValueKey(WidgetKeys.screenSocial)), findsOneWidget);
    expect(find.text('bob'), findsWidgets);
  });

  testWidgets('accepting a pending request calls the repository',
      (tester) async {
    repo.pending = [
      FriendRequest(
        id: 'r1',
        fromUserId: 'b',
        toUserId: 'me',
        createdAt: _now,
      ),
    ];
    await pump(tester);

    // The accept affordance is the check icon on the request card.
    final accept = find.byIcon(Icons.check_rounded);
    expect(accept, findsWidgets);
    await tester.tap(accept.first);
    await tester.pumpAndSettle();

    expect(repo.accepted, ['r1']);
  });

  testWidgets('declining a pending request calls the repository',
      (tester) async {
    repo.pending = [
      FriendRequest(
          id: 'r2', fromUserId: 'b', toUserId: 'me', createdAt: _now),
    ];
    await pump(tester);

    await tester.tap(find.byIcon(Icons.close_rounded).first);
    await tester.pumpAndSettle();

    expect(repo.declined, ['r2']);
  });

  testWidgets('removing a friend confirms first, then calls the repository',
      (tester) async {
    repo.friends = [
      Friendship(
          id: 'f1',
          userAId: 'me',
          userBId: 'b',
          friend: _summary('b', 'bob'),
          createdAt: _now),
    ];
    await pump(tester);

    // Open the friend card's menu and choose remove.
    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('social.remove_friend_menu'.tr()));
    await tester.pumpAndSettle();
    // Confirm.
    await tester.tap(find.text('social.remove_confirm'.tr()));
    await tester.pumpAndSettle();

    expect(repo.removed, ['f1']);
  });

  testWidgets('searching a user and tapping add sends a friend request',
      (tester) async {
    await pump(tester);

    await tester.tap(find.text('social.add_friend_button'.tr()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'cla');
    await tester.pumpAndSettle(const Duration(milliseconds: 400)); // debounce
    expect(find.text('claire'), findsOneWidget);

    // Both the header opener and the result tile render the same label; the
    // tile's is the last one in the tree.
    await tester.tap(find.text('social.search_add_button'.tr()).last);
    await tester.pumpAndSettle();

    expect(repo.sentTo, ['found-user']);
  });

  testWidgets('leaderboard tab shows entries with ranks and my score',
      (tester) async {
    await pump(tester);

    // Switch to the leaderboard tab (custom pill, found by its label).
    await tester.tap(find.text('social.tab_leaderboard'.tr()));
    await tester.pumpAndSettle();

    expect(find.text('ann'), findsWidgets);
    expect(find.text('thomas'), findsWidgets);
  });
}
