import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/failure.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/friendship.dart';
import '../../../domain/entities/leaderboard_entry.dart';
import '../../providers/auth/auth_provider.dart';
import '../../providers/social/social_provider.dart';

class SocialScreen extends ConsumerStatefulWidget {
  const SocialScreen({super.key});

  @override
  ConsumerState<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends ConsumerState<SocialScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() {
      if (_tab.indexIsChanging) return;
      setState(() => _currentTab = _tab.index);
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (_) => const _UserSearchDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Social'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [Tab(text: 'Friends'), Tab(text: 'Leaderboard')],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [_FriendsTab(), _LeaderboardTab()],
      ),
      floatingActionButton: _currentTab == 0
          ? FloatingActionButton.extended(
              onPressed: _showSearchDialog,
              icon: const Icon(Icons.person_add_outlined),
              label: const Text('Add Friend'),
            )
          : null,
    );
  }
}

// ─── Friends tab ──────────────────────────────────────────────────────────────

class _FriendsTab extends ConsumerWidget {
  const _FriendsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingRequestsProvider);
    final friendsAsync = ref.watch(friendsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(friendsProvider);
        ref.invalidate(pendingRequestsProvider);
      },
      child: CustomScrollView(
        slivers: [
          // Pending requests
          pendingAsync.when(
            loading: () =>
                const SliverToBoxAdapter(child: SizedBox.shrink()),
            error: (_, __) =>
                const SliverToBoxAdapter(child: SizedBox.shrink()),
            data: (requests) {
              if (requests.isEmpty) {
                return const SliverToBoxAdapter(child: SizedBox.shrink());
              }
              return SliverList(
                delegate: SliverChildListDelegate([
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Text('Pending Requests',
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                  ...requests.map((r) => _RequestTile(request: r)),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                ]),
              );
            },
          ),
          // Friends list
          friendsAsync.when(
            loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator())),
            error: (e, _) => SliverFillRemaining(
                child: Center(child: Text('Error loading friends'))),
            data: (friends) {
              if (friends.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.people_outline,
                            size: 64, color: AppColors.grey500),
                        const SizedBox(height: 16),
                        Text('No friends yet',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(color: AppColors.grey500)),
                        const SizedBox(height: 4),
                        Text('Tap + to find friends',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: AppColors.grey500)),
                      ],
                    ),
                  ),
                );
              }
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _FriendTile(friendship: friends[i]),
                  childCount: friends.length,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RequestTile extends ConsumerWidget {
  const _RequestTile({super.key, required this.request});
  final FriendRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final senderAsync = ref.watch(userSummaryProvider(request.fromUserId));
    final isLoading =
        ref.watch(socialActionsProvider) is AsyncLoading<void>;

    final name = senderAsync.valueOrNull?.displayName ??
        senderAsync.valueOrNull?.username ??
        '…';

    return ListTile(
      leading: _Avatar(
        name: name,
        url: senderAsync.valueOrNull?.avatarUrl,
      ),
      title: Text(name),
      subtitle: const Text('Sent you a friend request'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Accept',
            icon: const Icon(Icons.check_circle_outline,
                color: AppColors.success),
            onPressed: isLoading
                ? null
                : () => ref
                    .read(socialActionsProvider.notifier)
                    .acceptRequest(request.id),
          ),
          IconButton(
            tooltip: 'Decline',
            icon:
                const Icon(Icons.cancel_outlined, color: AppColors.secondary),
            onPressed: isLoading
                ? null
                : () => ref
                    .read(socialActionsProvider.notifier)
                    .declineRequest(request.id),
          ),
        ],
      ),
    );
  }
}

class _FriendTile extends ConsumerWidget {
  const _FriendTile({super.key, required this.friendship});
  final Friendship friendship;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friend = friendship.friend;
    return ListTile(
      leading: _Avatar(name: friend.displayName ?? friend.username, url: friend.avatarUrl),
      title: Text(friend.displayName ?? friend.username),
      subtitle: Text('@${friend.username}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (friend.currentStreak > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.local_fire_department,
                      size: 16, color: AppColors.streakActive),
                  Text('${friend.currentStreak}',
                      style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'remove') {
                _confirmRemove(context, ref);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'remove',
                child: Row(children: [
                  Icon(Icons.person_remove_outlined, color: AppColors.secondary),
                  SizedBox(width: 8),
                  Text('Remove friend'),
                ]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmRemove(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove friend?'),
        content: Text(
            'Remove ${friendship.friend.displayName ?? friendship.friend.username} from your friends?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: AppColors.secondary),
            onPressed: () {
              Navigator.pop(ctx);
              ref
                  .read(socialActionsProvider.notifier)
                  .removeFriend(friendship.id);
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}

// ─── Leaderboard tab ──────────────────────────────────────────────────────────

class _LeaderboardTab extends ConsumerWidget {
  const _LeaderboardTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(leaderboardPeriodProvider);
    final leaderboardAsync = ref.watch(leaderboardProvider(period));
    final currentUserId = ref.watch(currentUserProvider)?.id;

    return Column(
      children: [
        // Period toggle
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: SegmentedButton<LeaderboardPeriod>(
            segments: const [
              ButtonSegment(
                  value: LeaderboardPeriod.weekly, label: Text('Weekly')),
              ButtonSegment(
                  value: LeaderboardPeriod.monthly, label: Text('Monthly')),
              ButtonSegment(
                  value: LeaderboardPeriod.allTime, label: Text('All Time')),
            ],
            selected: {period},
            onSelectionChanged: (s) => ref
                .read(leaderboardPeriodProvider.notifier)
                .state = s.first,
          ),
        ),
        const SizedBox(height: 8),
        // List
        Expanded(
          child: leaderboardAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (_, __) =>
                const Center(child: Text('Failed to load leaderboard')),
            data: (result) {
              final entries = result.valueOrNull ?? [];
              if (entries.isEmpty) {
                return const Center(
                    child: Text('No scores yet — complete a quiz!',
                        style: TextStyle(color: AppColors.grey500)));
              }
              return RefreshIndicator(
                onRefresh: () async =>
                    ref.invalidate(leaderboardProvider(period)),
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: entries.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, indent: 56),
                  itemBuilder: (ctx, i) => _LeaderboardTile(
                    entry: entries[i],
                    isMe: entries[i].userId == currentUserId,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _LeaderboardTile extends StatelessWidget {
  const _LeaderboardTile({required this.entry, required this.isMe});
  final LeaderboardEntry entry;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final rank = entry.rank ?? 0;
    final rankColor = rank == 1
        ? const Color(0xFFFFD700)
        : rank == 2
            ? const Color(0xFFC0C0C0)
            : rank == 3
                ? const Color(0xFFCD7F32)
                : AppColors.grey500;

    return ColoredBox(
      color: isMe ? AppColors.primary.withAlpha(15) : Colors.transparent,
      child: ListTile(
        leading: SizedBox(
          width: 40,
          child: Center(
            child: Text(
              rank > 0 ? '#$rank' : '—',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: rankColor,
                  fontSize: rank <= 3 ? 16 : 14),
            ),
          ),
        ),
        title: Row(
          children: [
            _Avatar(name: entry.username, url: entry.avatarUrl, radius: 14),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                entry.username,
                style: isMe
                    ? const TextStyle(fontWeight: FontWeight.bold)
                    : null,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${entry.score}',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text('words',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.grey500)),
          ],
        ),
      ),
    );
  }
}

// ─── User search dialog ───────────────────────────────────────────────────────

class _UserSearchDialog extends ConsumerStatefulWidget {
  const _UserSearchDialog();

  @override
  ConsumerState<_UserSearchDialog> createState() => _UserSearchDialogState();
}

class _UserSearchDialogState extends ConsumerState<_UserSearchDialog> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  String _query = '';
  final _sent = <String>{};

  @override
  void dispose() {
    _ctrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      setState(() => _query = value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Find Friends'),
      contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      content: SizedBox(
        width: double.maxFinite,
        height: 320,
        child: Column(
          children: [
            TextField(
              controller: _ctrl,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Search by username…',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: _onChanged,
            ),
            const SizedBox(height: 8),
            Expanded(child: _query.length >= 2 ? _buildResults() : _buildHint()),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close')),
      ],
    );
  }

  Widget _buildHint() => const Center(
        child: Text('Type at least 2 characters',
            style: TextStyle(color: AppColors.grey500)),
      );

  Widget _buildResults() {
    final async = ref.watch(userSearchProvider(_query));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Search failed')),
      data: (result) {
        final users = result.valueOrNull ?? [];
        if (users.isEmpty) {
          return const Center(
              child:
                  Text('No users found', style: TextStyle(color: AppColors.grey500)));
        }
        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (ctx, i) {
            final user = users[i];
            final pending = _sent.contains(user.id);
            return ListTile(
              leading: _Avatar(
                  name: user.displayName ?? user.username,
                  url: user.avatarUrl),
              title: Text(user.displayName ?? user.username),
              subtitle: Text('@${user.username}'),
              trailing: pending
                  ? const Chip(
                      label: Text('Sent'),
                      backgroundColor: AppColors.grey300,
                    )
                  : FilledButton.tonal(
                      onPressed: () async {
                        final ok = await ref
                            .read(socialActionsProvider.notifier)
                            .sendRequest(user.id);
                        if (ok && mounted) setState(() => _sent.add(user.id));
                      },
                      child: const Text('Add'),
                    ),
            );
          },
        );
      },
    );
  }
}

// ─── Shared avatar widget ─────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, this.url, this.radius = 20});
  final String name;
  final String? url;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final initial =
        name.isNotEmpty ? name[0].toUpperCase() : '?';
    if (url != null && url!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(url!),
        onBackgroundImageError: (_, __) {},
        child: null,
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primary.withAlpha(40),
      child: Text(initial,
          style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
              fontSize: radius * 0.9)),
    );
  }
}
