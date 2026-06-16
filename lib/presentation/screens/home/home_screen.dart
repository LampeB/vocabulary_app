import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth/auth_provider.dart';
import '../../providers/lists/vocabulary_provider.dart';
import '../../providers/notifications/notification_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../domain/entities/vocabulary_list.dart';
import '../../widgets/dotted_ground.dart';
import '../../widgets/frosted_box.dart';
import '../../widgets/vk_waveform.dart';

// ── French date helpers (no intl dependency) ──────────────────────────────────

const _kFrDays = [
  'LUNDI', 'MARDI', 'MERCREDI', 'JEUDI', 'VENDREDI', 'SAMEDI', 'DIMANCHE'
];
const _kFrMonths = [
  'JAN', 'FÉV', 'MAR', 'AVR', 'MAI', 'JUIN',
  'JUIL', 'AOÛT', 'SEP', 'OCT', 'NOV', 'DÉC',
];

String _frDate(DateTime d) =>
    '${_kFrDays[d.weekday - 1]} ${d.day} ${_kFrMonths[d.month - 1]}';

// ── Screen ────────────────────────────────────────────────────────────────────

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(syncOnLoginProvider); // pulls remote data on login

    final user      = ref.watch(currentUserProvider);
    final listsAsync = ref.watch(myListsProvider);
    final dueCount  = ref.watch(dueCountProvider).valueOrNull ?? 0;
    final streak    = user?.currentStreak ?? 0;

    // Schedule streak warning once user data is available.
    if (streak > 0) {
      ref
          .read(notificationSettingsProvider.notifier)
          .maybeScheduleStreakWarning(streak);
    }

    final name = user?.displayName ?? user?.username ?? '';

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: RefreshIndicator(
        color: AppColors.clay,
        backgroundColor: AppColors.card,
        onRefresh: () async {
          ref.invalidate(myListsProvider);
          ref.invalidate(syncOnLoginProvider);
        },
        child: Stack(
          children: [
            const DottedGround(),
            ListView(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 16,
                left: 20,
                right: 20,
                bottom: 24,
              ),
              children: [
                // ── Header ─────────────────────────────────────────────────
                _Header(name: name, avatarUrl: user?.avatarUrl),
                const SizedBox(height: 24),
                // ── Streak block ────────────────────────────────────────────
                _StreakCard(streak: streak),
                const SizedBox(height: 12),
                // ── À réviser ───────────────────────────────────────────────
                if (dueCount > 0) ...[
                  _ReviewCard(
                    dueCount: dueCount,
                    onStart: () => context.go('/lists'),
                  ),
                  const SizedBox(height: 24),
                ],
                // ── Tes listes ──────────────────────────────────────────────
                Text(
                  'TES LISTES',
                  style: AppTextStyles.eyebrow
                      .copyWith(color: AppColors.muted),
                ),
                const SizedBox(height: 12),
                listsAsync.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: CircularProgressIndicator(
                          color: AppColors.clay, strokeWidth: 2),
                    ),
                  ),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text('Erreur: $e',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.rose)),
                  ),
                  data: (lists) => lists.isEmpty
                      ? _EmptyLists(onTap: () => context.go('/lists'))
                      : Column(
                          children: [
                            for (int i = 0;
                                i < lists.length && i < 5;
                                i++) ...[
                              _ListCard(
                                list: lists[i],
                                accentColor: AppColors.listPalette[
                                    i % AppColors.listPalette.length],
                                onTap: () =>
                                    context.go('/lists/${lists[i].id}'),
                              ),
                              if (i < lists.length - 1 && i < 4)
                                const SizedBox(height: 8),
                            ],
                            if (lists.length > 5) ...[
                              const SizedBox(height: 8),
                              _SeeAllButton(
                                  onTap: () => context.go('/lists')),
                            ],
                          ],
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.name, this.avatarUrl});
  final String name;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final firstName = name.split(' ').first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date eyebrow + notification bell
        Row(
          children: [
            Text(
              _frDate(today),
              style: AppTextStyles.eyebrow
                  .copyWith(color: AppColors.faint),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.notifications_outlined,
                  color: AppColors.muted, size: 22),
              tooltip: 'Notifications',
              onPressed: () => context.push('/notifications'),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // Greeting + avatar
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                'Bonjour${ firstName.isNotEmpty ? ', $firstName' : '' } !',
                style: AppTextStyles.grotesk(28, FontWeight.w700)
                    .copyWith(color: AppColors.ink),
              ),
            ),
            const SizedBox(width: 12),
            _Avatar(avatarUrl: avatarUrl, name: name),
          ],
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({this.avatarUrl, required this.name});
  final String? avatarUrl;
  final String name;

  @override
  Widget build(BuildContext context) {
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.clay.withValues(alpha: 0.15),
        shape: BoxShape.circle,
        border: Border.all(
            color: AppColors.clay.withValues(alpha: 0.3), width: 1.5),
      ),
      child: avatarUrl != null && avatarUrl!.isNotEmpty
          ? ClipOval(
              child: Image.network(avatarUrl!, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Center(child: _initial(initials))),
            )
          : Center(child: _initial(initials)),
    );
  }

  Widget _initial(String letter) => Text(
        letter,
        style: AppTextStyles.grotesk(18, FontWeight.w700)
            .copyWith(color: AppColors.clayDeep),
      );
}

// ── Streak card ───────────────────────────────────────────────────────────────

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.streak});
  final int streak;

  @override
  Widget build(BuildContext context) {
    final isActive = streak > 0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        height: 120,
        color: AppColors.inkDark,
        child: Stack(
          children: [
            // Waveform watermark
            Positioned(
              right: -8,
              top: 0,
              bottom: 0,
              child: Center(
                child: VkWaveform(
                  height: 96,
                  barWidth: 9,
                  gap: 5,
                  opacity: 0.35,
                  isAnimating: isActive,
                ),
              ),
            ),
            // Streak content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '$streak',
                        style: AppTextStyles.heroNumber.copyWith(
                          color: isActive
                              ? AppColors.clayDark
                              : AppColors.onDarkFaint,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'jour${streak == 1 ? '' : 's'}',
                        style: AppTextStyles.grotesk(22, FontWeight.w600)
                            .copyWith(color: AppColors.onDarkMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isActive ? 'de série — continue !' : 'Lance ta série aujourd\'hui',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.onDarkFaint),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Review card ───────────────────────────────────────────────────────────────

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.dueCount, required this.onStart});
  final int dueCount;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        color: AppColors.ink,
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'À RÉVISER',
                    style: AppTextStyles.eyebrow
                        .copyWith(color: AppColors.onDarkFaint),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$dueCount mot${dueCount == 1 ? '' : 's'}',
                    style: AppTextStyles.grotesk(32, FontWeight.w700)
                        .copyWith(color: AppColors.onDark),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: onStart,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.clay,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Commencer',
                  style: AppTextStyles.fig(14, FontWeight.w700)
                      .copyWith(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── List cards ────────────────────────────────────────────────────────────────

class _ListCard extends StatelessWidget {
  const _ListCard({
    required this.list,
    required this.accentColor,
    required this.onTap,
  });
  final VocabularyList list;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: FrostedBox(
        borderRadius: BorderRadius.circular(18),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Accent dot
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: accentColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 14),
            // Name + count
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    list.name,
                    style: AppTextStyles.fig(15, FontWeight.w600)
                        .copyWith(color: AppColors.ink),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${list.wordCount} mot${list.wordCount == 1 ? '' : 's'}',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.muted),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: AppColors.faint, size: 20),
          ],
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyLists extends StatelessWidget {
  const _EmptyLists({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: FrostedBox(
        borderRadius: BorderRadius.circular(18),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          children: [
            Icon(Icons.add_circle_outline,
                size: 44, color: AppColors.faint),
            const SizedBox(height: 12),
            Text(
              'Crée ta première liste',
              style: AppTextStyles.fig(15, FontWeight.w600)
                  .copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: 4),
            Text(
              'Ajoute des mots à apprendre',
              style: AppTextStyles.caption.copyWith(color: AppColors.faint),
            ),
          ],
        ),
      ),
    );
  }
}

// ── See all button ────────────────────────────────────────────────────────────

class _SeeAllButton extends StatelessWidget {
  const _SeeAllButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Center(
        child: Text(
          'VOIR TOUT',
          style: AppTextStyles.eyebrow.copyWith(color: AppColors.teal),
        ),
      ),
    );
  }
}
