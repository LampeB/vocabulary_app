import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/failure.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../domain/entities/friendship.dart';
import '../../../domain/entities/leaderboard_entry.dart';
import '../../providers/auth/auth_provider.dart';
import '../../providers/social/social_provider.dart';
import '../../widgets/dotted_ground.dart';
import '../../widgets/frosted_box.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: Stack(
        children: [
          const DottedGround(),
          SafeArea(
            child: Column(
              children: [
                // ── Header ─────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('Amis',
                            style: AppTextStyles.grotesk(
                                    26, FontWeight.w700)
                                .copyWith(color: AppColors.ink)),
                      ),
                      if (_currentTab == 0)
                        GestureDetector(
                          onTap: _showSearchDialog,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 9),
                            decoration: BoxDecoration(
                              color: AppColors.clay,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.person_add_outlined,
                                    color: Colors.white, size: 16),
                                const SizedBox(width: 6),
                                Text('Ajouter',
                                    style: AppTextStyles.fig(
                                            13, FontWeight.w700)
                                        .copyWith(color: Colors.white)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // ── Custom tab pills ───────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      _TabPill(
                        label: 'Amis',
                        selected: _currentTab == 0,
                        onTap: () {
                          _tab.animateTo(0);
                          setState(() => _currentTab = 0);
                        },
                      ),
                      const SizedBox(width: 8),
                      _TabPill(
                        label: 'Classement',
                        selected: _currentTab == 1,
                        onTap: () {
                          _tab.animateTo(1);
                          setState(() => _currentTab = 1);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // ── Tab content ────────────────────────────────────────────
                Expanded(
                  child: TabBarView(
                    controller: _tab,
                    children: const [_FriendsTab(), _LeaderboardTab()],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (_) => const _UserSearchDialog(),
    );
  }
}

// ── Tab pill ──────────────────────────────────────────────────────────────────

class _TabPill extends StatelessWidget {
  const _TabPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : AppColors.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.ink : AppColors.line,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.fig(
                  14,
                  selected ? FontWeight.w700 : FontWeight.w500)
              .copyWith(
            color: selected ? AppColors.onDark : AppColors.muted,
          ),
        ),
      ),
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
      color: AppColors.clay,
      backgroundColor: AppColors.card,
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
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Text('DEMANDES EN ATTENTE',
                        style: AppTextStyles.eyebrow
                            .copyWith(color: AppColors.muted)),
                  ),
                  ...requests.map((r) => Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                        child: _RequestCard(request: r),
                      )),
                  const SizedBox(height: 8),
                ]),
              );
            },
          ),
          // Friends list
          friendsAsync.when(
            loading: () => const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(
                    color: AppColors.clay, strokeWidth: 2),
              ),
            ),
            error: (e, _) => SliverFillRemaining(
              child: Center(
                child: Text('Erreur',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.rose)),
              ),
            ),
            data: (friends) {
              if (friends.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.people_outline,
                              size: 56, color: AppColors.faint),
                          const SizedBox(height: 16),
                          Text('Pas encore d\'amis',
                              style: AppTextStyles.grotesk(
                                      20, FontWeight.w700)
                                  .copyWith(color: AppColors.ink)),
                          const SizedBox(height: 8),
                          Text(
                            'Ajoute des amis pour voir leur progression.',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.body
                                .copyWith(color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _FriendCard(friendship: friends[i]),
                    ),
                    childCount: friends.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RequestCard extends ConsumerWidget {
  const _RequestCard({required this.request});
  final FriendRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final senderAsync = ref.watch(userSummaryProvider(request.fromUserId));
    final isLoading =
        ref.watch(socialActionsProvider) is AsyncLoading<void>;
    final name = senderAsync.valueOrNull?.displayName ??
        senderAsync.valueOrNull?.username ??
        '…';

    return FrostedBox(
      borderRadius: BorderRadius.circular(16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          _MiniAvatar(name: name, url: senderAsync.valueOrNull?.avatarUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: AppTextStyles.fig(14, FontWeight.w600)
                        .copyWith(color: AppColors.ink)),
                Text('T\'a envoyé une demande',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.muted)),
              ],
            ),
          ),
          // Accept
          GestureDetector(
            onTap: isLoading
                ? null
                : () => ref
                    .read(socialActionsProvider.notifier)
                    .acceptRequest(request.id),
            child: Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.only(left: 6),
              decoration: BoxDecoration(
                color: AppColors.teal.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.check_rounded,
                  color: AppColors.teal, size: 18),
            ),
          ),
          // Decline
          GestureDetector(
            onTap: isLoading
                ? null
                : () => ref
                    .read(socialActionsProvider.notifier)
                    .declineRequest(request.id),
            child: Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.only(left: 6),
              decoration: BoxDecoration(
                color: AppColors.rose.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.close_rounded,
                  color: AppColors.rose, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

class _FriendCard extends ConsumerWidget {
  const _FriendCard({required this.friendship});
  final Friendship friendship;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friend = friendship.friend;
    final displayName = friend.displayName ?? friend.username;

    return FrostedBox(
      borderRadius: BorderRadius.circular(16),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      child: Row(
        children: [
          _MiniAvatar(name: displayName, url: friend.avatarUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(displayName,
                    style: AppTextStyles.fig(14, FontWeight.w600)
                        .copyWith(color: AppColors.ink)),
                Text('@${friend.username}',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.faint)),
              ],
            ),
          ),
          if (friend.currentStreak > 0) ...[
            Icon(Icons.local_fire_department_rounded,
                size: 14, color: AppColors.clay),
            const SizedBox(width: 3),
            Text('${friend.currentStreak}',
                style: AppTextStyles.mono(12, FontWeight.w700)
                    .copyWith(color: AppColors.clay)),
            const SizedBox(width: 4),
          ],
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert,
                color: AppColors.faint, size: 18),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'remove',
                child: Row(children: [
                  const Icon(Icons.person_remove_outlined,
                      size: 16, color: AppColors.rose),
                  const SizedBox(width: 8),
                  Text('Supprimer',
                      style: AppTextStyles.fig(13, FontWeight.w500)
                          .copyWith(color: AppColors.rose)),
                ]),
              ),
            ],
            onSelected: (v) {
              if (v == 'remove') _confirmRemove(context, ref);
            },
          ),
        ],
      ),
    );
  }

  void _confirmRemove(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Retirer cet ami ?',
            style: AppTextStyles.grotesk(20, FontWeight.w700)
                .copyWith(color: AppColors.ink)),
        content: Text(
          '${friendship.friend.displayName ?? friendship.friend.username} sera retiré de tes amis.',
          style: AppTextStyles.body.copyWith(color: AppColors.muted),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.rose),
            onPressed: () {
              Navigator.pop(ctx);
              ref
                  .read(socialActionsProvider.notifier)
                  .removeFriend(friendship.id);
            },
            child: Text('Retirer',
                style: AppTextStyles.fig(14, FontWeight.w600)
                    .copyWith(color: AppColors.rose)),
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
        // Period pills
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          child: Row(
            children: [
              _PeriodPill(
                label: 'Semaine',
                selected: period == LeaderboardPeriod.weekly,
                onTap: () => ref
                    .read(leaderboardPeriodProvider.notifier)
                    .state = LeaderboardPeriod.weekly,
              ),
              const SizedBox(width: 8),
              _PeriodPill(
                label: 'Mois',
                selected: period == LeaderboardPeriod.monthly,
                onTap: () => ref
                    .read(leaderboardPeriodProvider.notifier)
                    .state = LeaderboardPeriod.monthly,
              ),
              const SizedBox(width: 8),
              _PeriodPill(
                label: 'Total',
                selected: period == LeaderboardPeriod.allTime,
                onTap: () => ref
                    .read(leaderboardPeriodProvider.notifier)
                    .state = LeaderboardPeriod.allTime,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: leaderboardAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(
                  color: AppColors.clay, strokeWidth: 2),
            ),
            error: (_, __) => Center(
              child: Text('Classement indisponible',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.muted)),
            ),
            data: (result) {
              final entries = result.valueOrNull ?? [];
              if (entries.isEmpty) {
                return Center(
                  child: Text(
                    'Aucun score — termine un quiz pour apparaître !',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body
                        .copyWith(color: AppColors.muted),
                  ),
                );
              }
              return RefreshIndicator(
                color: AppColors.clay,
                backgroundColor: AppColors.card,
                onRefresh: () async =>
                    ref.invalidate(leaderboardProvider(period)),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  itemCount: entries.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 8),
                  itemBuilder: (ctx, i) => _LeaderboardCard(
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

class _PeriodPill extends StatelessWidget {
  const _PeriodPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.teal : AppColors.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.teal : AppColors.line,
          ),
        ),
        child: Text(label,
            style: AppTextStyles.fig(
                    13,
                    selected ? FontWeight.w700 : FontWeight.w500)
                .copyWith(
              color: selected ? Colors.white : AppColors.muted,
            )),
      ),
    );
  }
}

class _LeaderboardCard extends StatelessWidget {
  const _LeaderboardCard({required this.entry, required this.isMe});
  final LeaderboardEntry entry;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final rank = entry.rank ?? 0;
    final Color rankColor;
    if (rank == 1) {
      rankColor = const Color(0xFFFFD700);
    } else if (rank == 2) {
      rankColor = const Color(0xFFC0C0C0);
    } else if (rank == 3) {
      rankColor = const Color(0xFFCD7F32);
    } else {
      rankColor = AppColors.faint;
    }

    return FrostedBox(
      borderRadius: BorderRadius.circular(16),
      borderOpacity: isMe ? 0.0 : 0.18,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Stack(
        children: [
          if (isMe)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.teal, width: 1.5),
                ),
              ),
            ),
          Row(
            children: [
              // Rank badge
              SizedBox(
                width: 32,
                child: Center(
                  child: Text(
                    rank > 0 ? '#$rank' : '—',
                    style: AppTextStyles.mono(
                            rank <= 3 ? 14 : 12, FontWeight.w700)
                        .copyWith(color: rankColor),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _MiniAvatar(
                  name: entry.username, url: entry.avatarUrl),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  entry.username,
                  style: AppTextStyles.fig(
                          14,
                          isMe
                              ? FontWeight.w700
                              : FontWeight.w500)
                      .copyWith(color: AppColors.ink),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${entry.score}',
                    style: AppTextStyles.grotesk(16, FontWeight.w700)
                        .copyWith(
                      color: isMe ? AppColors.teal : AppColors.ink,
                    ),
                  ),
                  Text('mots',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.faint)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── User search dialog ───────────────────────────────────────────────────────

class _UserSearchDialog extends ConsumerStatefulWidget {
  const _UserSearchDialog();

  @override
  ConsumerState<_UserSearchDialog> createState() =>
      _UserSearchDialogState();
}

class _UserSearchDialogState
    extends ConsumerState<_UserSearchDialog> {
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
      title: Text('Trouver des amis',
          style: AppTextStyles.grotesk(20, FontWeight.w700)
              .copyWith(color: AppColors.ink)),
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
                hintText: 'Rechercher par pseudo…',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: _onChanged,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _query.length >= 2
                  ? _buildResults()
                  : Center(
                      child: Text('Tape au moins 2 caractères',
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.faint)),
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer')),
      ],
    );
  }

  Widget _buildResults() {
    final async = ref.watch(userSearchProvider(_query));
    return async.when(
      loading: () => const Center(
        child: CircularProgressIndicator(
            color: AppColors.clay, strokeWidth: 2),
      ),
      error: (_, __) => Center(
        child: Text('Recherche échouée',
            style: AppTextStyles.caption
                .copyWith(color: AppColors.rose)),
      ),
      data: (result) {
        final users = result.valueOrNull ?? [];
        if (users.isEmpty) {
          return Center(
            child: Text('Aucun utilisateur trouvé',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.faint)),
          );
        }
        return ListView.separated(
          itemCount: users.length,
          separatorBuilder: (_, __) => const SizedBox(height: 6),
          itemBuilder: (ctx, i) {
            final user = users[i];
            final name = user.displayName ?? user.username;
            final pending = _sent.contains(user.id);
            return Row(
              children: [
                _MiniAvatar(name: name, url: user.avatarUrl),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style:
                              AppTextStyles.fig(14, FontWeight.w600)
                                  .copyWith(color: AppColors.ink)),
                      Text('@${user.username}',
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.faint)),
                    ],
                  ),
                ),
                if (pending)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.line,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text('Envoyée',
                        style: AppTextStyles.fig(11, FontWeight.w600)
                            .copyWith(color: AppColors.muted)),
                  )
                else
                  GestureDetector(
                    onTap: () async {
                      final ok = await ref
                          .read(socialActionsProvider.notifier)
                          .sendRequest(user.id);
                      if (ok && mounted) {
                        setState(() => _sent.add(user.id));
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.clay,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text('Ajouter',
                          style:
                              AppTextStyles.fig(12, FontWeight.w700)
                                  .copyWith(color: Colors.white)),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

// ─── Shared mini avatar ───────────────────────────────────────────────────────

class _MiniAvatar extends StatelessWidget {
  const _MiniAvatar({required this.name, this.url});
  final String name;
  final String? url;

  static const double _r = 18;

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    if (url != null && url!.isNotEmpty) {
      return CircleAvatar(
        radius: _r,
        backgroundImage: NetworkImage(url!),
        onBackgroundImageError: (_, __) {},
      );
    }
    return CircleAvatar(
      radius: _r,
      backgroundColor: AppColors.clay.withValues(alpha: 0.15),
      child: Text(
        initial,
        style: AppTextStyles.fig(_r * 0.75, FontWeight.w700)
            .copyWith(color: AppColors.clayDeep),
      ),
    );
  }
}
