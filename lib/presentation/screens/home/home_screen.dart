import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth/auth_provider.dart';
import '../../providers/lists/vocabulary_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../widgets/streak_counter.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final listsAsync = ref.watch(myListsProvider);
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Bonjour, ${user?.displayName ?? user?.username ?? ''}!'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(myListsProvider),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            StreakCounter(streak: user?.currentStreak ?? 0),
            const SizedBox(height: 16),
            _DueCard(onStart: () => context.go('/lists')),
            const SizedBox(height: 24),
            Text('Your Lists', style: tt.titleLarge),
            const SizedBox(height: 12),
            listsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error: $e'),
              data: (lists) => lists.isEmpty
                  ? _EmptyListsHint(onTap: () => context.go('/lists'))
                  : Column(
                      children: lists
                          .take(3)
                          .map((l) => _ListSummaryCard(
                                name: l.name,
                                wordCount: l.wordCount,
                                onTap: () => context.go('/lists/${l.id}'),
                              ))
                          .toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DueCard extends StatelessWidget {
  const _DueCard({required this.onStart});
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.primary,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const Icon(Icons.flash_on, color: Colors.white, size: 40),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Review due',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: Colors.white70)),
                  Text('Start studying',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(color: Colors.white)),
                ],
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
              ),
              onPressed: onStart,
              child: const Text('Go'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListSummaryCard extends StatelessWidget {
  const _ListSummaryCard({
    required this.name,
    required this.wordCount,
    required this.onTap,
  });
  final String name;
  final int wordCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        title: Text(name),
        subtitle: Text('$wordCount words'),
        trailing: const Icon(Icons.chevron_right),
        leading: const CircleAvatar(
          backgroundColor: AppColors.surfaceVariant,
          child: Icon(Icons.menu_book, color: AppColors.primary),
        ),
      ),
    );
  }
}

class _EmptyListsHint extends StatelessWidget {
  const _EmptyListsHint({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          border: Border.all(
              color: AppColors.grey300, style: BorderStyle.solid),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            const Icon(Icons.add_circle_outline,
                size: 48, color: AppColors.grey500),
            const SizedBox(height: 8),
            Text('Create your first list',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: AppColors.grey700)),
          ],
        ),
      ),
    );
  }
}
