import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth/auth_provider.dart';
import '../../providers/purchases/purchase_provider.dart';
import '../../providers/settings/settings_provider.dart';
import '../../../domain/entities/subscription_type.dart';
import '../../../core/theme/app_colors.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // ─── Account ──────────────────────────────────────────────────────
          _SectionHeader('Account'),
          ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.surfaceVariant,
              backgroundImage: user?.avatarUrl != null
                  ? NetworkImage(user!.avatarUrl!)
                  : null,
              child: user?.avatarUrl == null
                  ? Text((user?.username ?? '?')[0].toUpperCase())
                  : null,
            ),
            title: Text(user?.displayName ?? user?.username ?? '—'),
            subtitle: Text('@${user?.username ?? ''}',
                style: const TextStyle(color: AppColors.grey500)),
          ),
          const Divider(height: 1),

          // ─── Appearance ───────────────────────────────────────────────────
          _SectionHeader('Appearance'),
          ListTile(
            leading: const Icon(Icons.brightness_6_outlined),
            title: const Text('Theme'),
            trailing: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: Icon(Icons.light_mode_outlined, size: 18),
                  tooltip: 'Light',
                ),
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: Icon(Icons.brightness_auto_outlined, size: 18),
                  tooltip: 'System',
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode_outlined, size: 18),
                  tooltip: 'Dark',
                ),
              ],
              selected: {themeMode},
              onSelectionChanged: (s) =>
                  ref.read(themeModeProvider.notifier).set(s.first),
              showSelectedIcon: false,
            ),
          ),
          const Divider(height: 1),

          // ─── Notifications ────────────────────────────────────────────────
          _SectionHeader('Notifications'),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Study reminders'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/notifications'),
          ),
          const Divider(height: 1),

          // ─── Subscription ─────────────────────────────────────────────────
          _SectionHeader('Subscription'),
          ListTile(
            leading: const Icon(Icons.workspace_premium_outlined),
            title: const Text('Plan'),
            subtitle: Text(_subscriptionLabel(ref)),
            trailing: ref.watch(isPremiumProvider)
                ? null
                : FilledButton(
                    onPressed: () => context.push('/paywall'),
                    child: const Text('Upgrade'),
                  ),
          ),
          const Divider(height: 1),

          // ─── Danger zone ──────────────────────────────────────────────────
          _SectionHeader('Account actions'),
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.secondary),
            title: const Text('Sign out',
                style: TextStyle(color: AppColors.secondary)),
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Sign out?'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel')),
                    FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: AppColors.secondary),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Sign out'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                await ref.read(authStateProvider.notifier).signOut();
                if (context.mounted) context.go('/welcome');
              }
            },
          ),
        ],
      ),
    );
  }
}

String _subscriptionLabel(WidgetRef ref) {
  final isPremium = ref.watch(isPremiumProvider);
  if (!isPremium) return 'Free plan';
  final type = ref.watch(currentUserProvider)?.subscriptionType;
  return type == SubscriptionType.student ? 'Student Access' : 'Premium ✓';
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.grey500,
              letterSpacing: 1.1,
            ),
      ),
    );
  }
}
