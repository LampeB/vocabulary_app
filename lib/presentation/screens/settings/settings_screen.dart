import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth/auth_provider.dart';
import '../../providers/purchases/purchase_provider.dart';
import '../../providers/settings/settings_provider.dart';
import '../../../domain/entities/subscription_type.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../widgets/dotted_ground.dart';
import '../../widgets/frosted_box.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user      = ref.watch(currentUserProvider);
    final themeMode = ref.watch(themeModeProvider);
    final isPremium = ref.watch(isPremiumProvider);

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: Text('Paramètres',
            style: AppTextStyles.grotesk(22, FontWeight.w700)
                .copyWith(color: AppColors.ink)),
      ),
      body: Stack(
        children: [
          const DottedGround(),
          ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              // ── Compte ──────────────────────────────────────────────────────
              _EyebrowSection('COMPTE'),
              FrostedBox(
                borderRadius: BorderRadius.circular(18),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    _SmallAvatar(
                      name: user?.displayName ?? user?.username ?? '?',
                      url: user?.avatarUrl,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.displayName ?? user?.username ?? '—',
                            style: AppTextStyles.fig(15, FontWeight.w600)
                                .copyWith(color: AppColors.ink),
                          ),
                          Text('@${user?.username ?? ''}',
                              style: AppTextStyles.caption
                                  .copyWith(color: AppColors.faint)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // ── Apparence ───────────────────────────────────────────────────
              _EyebrowSection('APPARENCE'),
              FrostedBox(
                borderRadius: BorderRadius.circular(18),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.line.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.brightness_6_outlined,
                          color: AppColors.muted, size: 18),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text('Thème',
                          style: AppTextStyles.fig(15, FontWeight.w500)
                              .copyWith(color: AppColors.ink)),
                    ),
                    // Theme pill buttons
                    Row(
                      children: [
                        _ThemePill(
                          icon: Icons.light_mode_outlined,
                          selected: themeMode == ThemeMode.light,
                          onTap: () => ref
                              .read(themeModeProvider.notifier)
                              .set(ThemeMode.light),
                        ),
                        const SizedBox(width: 6),
                        _ThemePill(
                          icon: Icons.brightness_auto_outlined,
                          selected: themeMode == ThemeMode.system,
                          onTap: () => ref
                              .read(themeModeProvider.notifier)
                              .set(ThemeMode.system),
                        ),
                        const SizedBox(width: 6),
                        _ThemePill(
                          icon: Icons.dark_mode_outlined,
                          selected: themeMode == ThemeMode.dark,
                          onTap: () => ref
                              .read(themeModeProvider.notifier)
                              .set(ThemeMode.dark),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // ── Notifications ────────────────────────────────────────────────
              _EyebrowSection('NOTIFICATIONS'),
              _NavTile(
                icon: Icons.notifications_outlined,
                label: 'Rappels d\'étude',
                onTap: () => context.push('/notifications'),
              ),
              const SizedBox(height: 24),
              // ── Abonnement ───────────────────────────────────────────────────
              _EyebrowSection('ABONNEMENT'),
              FrostedBox(
                borderRadius: BorderRadius.circular(18),
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isPremium
                            ? AppColors.clay.withValues(alpha: 0.12)
                            : AppColors.line.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.workspace_premium_outlined,
                        color:
                            isPremium ? AppColors.clay : AppColors.faint,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(isPremium ? 'Premium' : 'Gratuit',
                              style:
                                  AppTextStyles.fig(15, FontWeight.w500)
                                      .copyWith(color: AppColors.ink)),
                          Text(_subscriptionLabel(ref),
                              style: AppTextStyles.caption
                                  .copyWith(color: AppColors.muted)),
                        ],
                      ),
                    ),
                    if (!isPremium)
                      GestureDetector(
                        onTap: () => context.push('/paywall'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: AppColors.clay,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text('Upgrade',
                              style:
                                  AppTextStyles.fig(12, FontWeight.w700)
                                      .copyWith(color: Colors.white)),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // ── Compte — actions ─────────────────────────────────────────────
              _EyebrowSection('ACTIONS'),
              _NavTile(
                icon: Icons.logout_rounded,
                label: 'Se déconnecter',
                destructive: true,
                onTap: () => _confirmSignOut(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSignOut(
      BuildContext context, WidgetRef ref) async {
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
    if (confirmed == true) {
      await ref.read(authStateProvider.notifier).signOut();
      if (context.mounted) context.go('/welcome');
    }
  }
}

String _subscriptionLabel(WidgetRef ref) {
  final isPremium = ref.watch(isPremiumProvider);
  if (!isPremium) return 'Accès limité';
  final type = ref.watch(currentUserProvider)?.subscriptionType;
  return type == SubscriptionType.student ? 'Accès Étudiant' : 'Premium ✓';
}

// ── Section eyebrow ───────────────────────────────────────────────────────────

class _EyebrowSection extends StatelessWidget {
  const _EyebrowSection(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(label,
          style: AppTextStyles.eyebrow.copyWith(color: AppColors.muted)),
    );
  }
}

// ── Nav tile ──────────────────────────────────────────────────────────────────

class _NavTile extends StatelessWidget {
  const _NavTile({
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
    final bg = destructive
        ? AppColors.rose.withValues(alpha: 0.08)
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
                color: bg,
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
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.faint, size: 20),
          ],
        ),
      ),
    );
  }
}

// ── Theme pill button ─────────────────────────────────────────────────────────

class _ThemePill extends StatelessWidget {
  const _ThemePill({
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: selected ? AppColors.teal : AppColors.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.teal : AppColors.line,
          ),
        ),
        child: Icon(icon,
            size: 16,
            color: selected ? Colors.white : AppColors.faint),
      ),
    );
  }
}

// ── Small avatar ──────────────────────────────────────────────────────────────

class _SmallAvatar extends StatelessWidget {
  const _SmallAvatar({required this.name, this.url});
  final String name;
  final String? url;

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: 20,
      backgroundColor: AppColors.clay.withValues(alpha: 0.15),
      backgroundImage:
          url != null && url!.isNotEmpty ? NetworkImage(url!) : null,
      child: url == null || url!.isEmpty
          ? Text(initial,
              style: AppTextStyles.fig(16, FontWeight.w700)
                  .copyWith(color: AppColors.clayDeep))
          : null,
    );
  }
}
