import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class SocialScreen extends StatelessWidget {
  const SocialScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Social'),
          bottom: const TabBar(tabs: [
            Tab(text: 'Friends'),
            Tab(text: 'Leaderboard'),
          ]),
        ),
        body: const TabBarView(children: [
          _FriendsTab(),
          _LeaderboardTab(),
        ]),
      ),
    );
  }
}

class _FriendsTab extends StatelessWidget {
  const _FriendsTab();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.people_outline, size: 64, color: AppColors.grey500),
          const SizedBox(height: 16),
          Text('No friends yet',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: AppColors.grey500)),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.person_add_outlined),
            label: const Text('Find Friends'),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardTab extends StatelessWidget {
  const _LeaderboardTab();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Leaderboard coming soon',
          style: TextStyle(color: AppColors.grey500)),
    );
  }
}
