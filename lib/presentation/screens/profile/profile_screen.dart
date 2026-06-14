import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../widgets/streak_counter.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: AppColors.surfaceVariant,
                  backgroundImage: user?.avatarUrl != null
                      ? NetworkImage(user!.avatarUrl!)
                      : null,
                  child: user?.avatarUrl == null
                      ? Text(
                          (user?.username ?? '?')[0].toUpperCase(),
                          style: tt.headlineLarge,
                        )
                      : null,
                ),
                const SizedBox(height: 12),
                Text(user?.displayName ?? user?.username ?? '',
                    style: tt.headlineMedium),
                Text('@${user?.username ?? ''}',
                    style:
                        tt.bodyMedium?.copyWith(color: AppColors.grey500)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          StreakCounter(streak: user?.currentStreak ?? 0),
          const SizedBox(height: 24),
          _StatGrid(
            stats: [
              ('Total mastered', '${user?.totalWordsMastered ?? 0}'),
              ('Best streak', '${user?.longestStreak ?? 0} days'),
            ],
          ),
          const SizedBox(height: 32),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.workspace_premium_outlined),
            title: const Text('Subscription'),
            subtitle:
                Text(user?.isPremium == true ? 'Premium' : 'Free plan'),
            trailing: user?.isPremium != true
                ? FilledButton(
                    onPressed: () => context.go('/paywall'),
                    child: const Text('Upgrade'),
                  )
                : null,
          ),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Settings'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            leading:
                const Icon(Icons.logout, color: AppColors.secondary),
            title: const Text('Sign Out',
                style: TextStyle(color: AppColors.secondary)),
            onTap: () async {
              await ref.read(authStateProvider.notifier).signOut();
              if (context.mounted) context.go('/welcome');
            },
          ),
        ],
      ),
    );
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.stats});
  final List<(String, String)> stats;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: stats.map((s) {
        final (label, value) = s;
        return Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(value,
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 4),
                  Text(label,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.grey500),
                      textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
