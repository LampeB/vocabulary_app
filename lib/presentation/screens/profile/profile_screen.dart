import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth/auth_provider.dart';
import '../../providers/purchases/purchase_provider.dart';
import '../../../domain/entities/subscription_type.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../widgets/dotted_ground.dart';
import '../../widgets/frosted_box.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user      = ref.watch(currentUserProvider);
    final isPremium = ref.watch(isPremiumProvider);
    final name      = user?.displayName ?? user?.username ?? '';
    final username  = user?.username ?? '';
    final streak    = user?.currentStreak ?? 0;
    final mastered  = user?.totalWordsMastered ?? 0;
    final best      = user?.longestStreak ?? 0;

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined,
                color: AppColors.muted, size: 22),
            tooltip: 'Paramètres',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: Stack(
        children: [
          const DottedGround(),
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                // ── Avatar + name ────────────────────────────────────────────
                Center(
                  child: Column(
                    children: [
                      _LargeAvatar(
                        name: name,
                        avatarUrl: user?.avatarUrl,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        name,
                        style: AppTextStyles.grotesk(26, FontWeight.w700)
                            .copyWith(color: AppColors.ink),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '@$username',
                        key: const Key('profile_username'),
                        style: AppTextStyles.mono(13, FontWeight.w400)
                            .copyWith(color: AppColors.faint),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                // ── Streak block ─────────────────────────────────────────────
                FrostedBox(
                  borderRadius: BorderRadius.circular(20),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 20),
                  child: Row(
                    children: [
                      Icon(
                        Icons.local_fire_department_rounded,
                        color: streak > 0
                            ? AppColors.clay
                            : AppColors.faint,
                        size: 32,
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment:
                                CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                '$streak',
                                style: AppTextStyles.grotesk(
                                        36, FontWeight.w700)
                                    .copyWith(
                                  color: streak > 0
                                      ? AppColors.clay
                                      : AppColors.faint,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'jour${streak == 1 ? '' : 's'}',
                                style: AppTextStyles.fig(
                                        16, FontWeight.w600)
                                    .copyWith(color: AppColors.muted),
                              ),
                            ],
                          ),
                          Text(
                            streak > 0
                                ? 'de série en cours'
                                : 'Lance ta série aujourd\'hui',
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.faint),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // ── Stats ────────────────────────────────────────────────────
                Row(
                  children: [
                    _StatCard(
                      value: '$mastered',
                      label: 'Mots maîtrisés',
                      accent: AppColors.teal,
                    ),
                    const SizedBox(width: 10),
                    _StatCard(
                      value: '$best',
                      label: 'Meilleure série',
                      accent: AppColors.clay,
                      suffix: ' j',
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // ── Subscription ─────────────────────────────────────────────
                _Section(label: 'ABONNEMENT'),
                const SizedBox(height: 10),
                FrostedBox(
                  borderRadius: BorderRadius.circular(18),
                  padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: isPremium
                              ? AppColors.clay.withValues(alpha: 0.12)
                              : AppColors.line.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.workspace_premium_outlined,
                          color: isPremium
                              ? AppColors.clay
                              : AppColors.faint,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isPremium ? 'Premium' : 'Gratuit',
                              style:
                                  AppTextStyles.fig(15, FontWeight.w600)
                                      .copyWith(color: AppColors.ink),
                            ),
                            Text(
                              _subscriptionLabel(ref),
                              style: AppTextStyles.caption
                                  .copyWith(color: AppColors.muted),
                            ),
                          ],
                        ),
                      ),
                      if (!isPremium)
                        GestureDetector(
                          onTap: () => context.go('/paywall'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.clay,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text('Passer Premium',
                                style:
                                    AppTextStyles.fig(12, FontWeight.w700)
                                        .copyWith(color: Colors.white)),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // ── Actions ──────────────────────────────────────────────────
                _Section(label: 'COMPTE'),
                const SizedBox(height: 10),
                _ActionTile(
                  icon: Icons.settings_outlined,
                  label: 'Paramètres',
                  onTap: () => context.push('/settings'),
                ),
                const SizedBox(height: 8),
                _ActionTile(
                  icon: Icons.notifications_outlined,
                  label: 'Notifications',
                  onTap: () => context.push('/notifications'),
                ),
                const SizedBox(height: 8),
                _ActionTile(
                  icon: Icons.logout_rounded,
                  label: 'Se déconnecter',
                  destructive: true,
                  onTap: () => _confirmSignOut(context, ref),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Se déconnecter ?',
            style: AppTextStyles.grotesk(20, FontWeight.w700)
                .copyWith(color: AppColors.ink)),
        content: Text(
          'Tu seras redirigé vers l\'écran de connexion.',
          style: AppTextStyles.body.copyWith(color: AppColors.muted),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.rose),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Déconnecter',
                style: AppTextStyles.fig(14, FontWeight.w600)
                    .copyWith(color: AppColors.rose)),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await ref.read(authRepositoryProvider).signOut();
    }
  }
}

String _subscriptionLabel(WidgetRef ref) {
  final isPremium = ref.watch(isPremiumProvider);
  if (!isPremium) return 'Accès limité — sans pub, sans pression';
  final type = ref.watch(currentUserProvider)?.subscriptionType;
  return type == SubscriptionType.student
      ? 'Accès Étudiant'
      : 'Accès Premium complet';
}

// ── Large avatar ──────────────────────────────────────────────────────────────

class _LargeAvatar extends StatelessWidget {
  const _LargeAvatar({required this.name, this.avatarUrl});
  final String name;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.clay, width: 2.5),
        color: AppColors.clay.withValues(alpha: 0.12),
      ),
      child: avatarUrl != null && avatarUrl!.isNotEmpty
          ? ClipOval(
              child: Image.network(
                avatarUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Center(
                  child: _initial(initial),
                ),
              ),
            )
          : Center(child: _initial(initial)),
    );
  }

  Widget _initial(String letter) => Text(
        letter,
        style: AppTextStyles.grotesk(36, FontWeight.w700)
            .copyWith(color: AppColors.clayDeep),
      );
}

// ── Stat card ─────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
    required this.accent,
    this.suffix = '',
  });
  final String value;
  final String label;
  final Color accent;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: FrostedBox(
        borderRadius: BorderRadius.circular(18),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: AppTextStyles.grotesk(32, FontWeight.w700)
                      .copyWith(color: accent),
                ),
                if (suffix.isNotEmpty)
                  Text(suffix,
                      style: AppTextStyles.fig(14, FontWeight.w600)
                          .copyWith(color: accent)),
              ],
            ),
            const SizedBox(height: 2),
            Text(label,
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.muted)),
          ],
        ),
      ),
    );
  }
}

// ── Section eyebrow ───────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) =>
      Text(label,
          style: AppTextStyles.eyebrow.copyWith(color: AppColors.muted));
}

// ── Action tile ───────────────────────────────────────────────────────────────

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.rose : AppColors.ink;
    final iconBg = destructive
        ? AppColors.rose.withValues(alpha: 0.1)
        : AppColors.line.withValues(alpha: 0.6);

    return GestureDetector(
      onTap: onTap,
      child: FrostedBox(
        borderRadius: BorderRadius.circular(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: AppTextStyles.fig(15, FontWeight.w500)
                      .copyWith(color: color)),
            ),
            if (!destructive)
              Icon(Icons.chevron_right_rounded,
                  color: AppColors.faint, size: 20),
          ],
        ),
      ),
    );
  }
}
