import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../../providers/lists/vocabulary_provider.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/errors/failure.dart';
import '../../../core/theme/app_colors.dart';
import '../../widgets/mastery_bar.dart';

class ListsScreen extends ConsumerWidget {
  const ListsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listsAsync = ref.watch(myListsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Lists'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'import',
                child: Row(children: [
                  Icon(Icons.file_download_outlined, size: 18),
                  SizedBox(width: 8),
                  Text('Import List'),
                ]),
              ),
            ],
            onSelected: (v) async {
              if (v == 'import') await _importList(context, ref);
            },
          ),
        ],
      ),
      body: listsAsync.when(
        loading: () => const _ListsShimmer(),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (lists) => lists.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.library_books_outlined,
                        size: 64, color: AppColors.grey300),
                    const SizedBox(height: 16),
                    Text('No lists yet',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(color: AppColors.grey500)),
                    const SizedBox(height: 8),
                    const Text('Tap + to create your first list',
                        style: TextStyle(color: AppColors.grey500)),
                  ],
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                itemCount: lists.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) {
                  final list = lists[i];
                  return Card(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => context.go('/lists/${list.id}'),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(list.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium),
                                ),
                                PopupMenuButton<String>(
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                        value: 'rename',
                                        child: Row(children: [
                                          Icon(Icons.edit_outlined, size: 18),
                                          SizedBox(width: 8),
                                          Text('Rename'),
                                        ])),
                                    PopupMenuItem(
                                        value: 'export',
                                        child: Row(children: [
                                          Icon(Icons.ios_share_outlined,
                                              size: 18),
                                          SizedBox(width: 8),
                                          Text('Export'),
                                        ])),
                                    PopupMenuItem(
                                        value: 'share',
                                        child: Row(children: [
                                          Icon(Icons.link_outlined, size: 18),
                                          SizedBox(width: 8),
                                          Text('Share Link'),
                                        ])),
                                    PopupMenuItem(
                                        value: 'delete',
                                        child: Row(children: [
                                          Icon(Icons.delete_outline,
                                              size: 18,
                                              color: AppColors.secondary),
                                          SizedBox(width: 8),
                                          Text('Delete',
                                              style: TextStyle(
                                                  color: AppColors.secondary)),
                                        ])),
                                  ],
                                  onSelected: (v) async {
                                    if (v == 'rename') {
                                      await _showRenameDialog(
                                          ctx, ref, list.id, list.name);
                                    } else if (v == 'export') {
                                      await _exportList(
                                          ctx, ref, list.id, list.name);
                                    } else if (v == 'share') {
                                      await _generateAndShareLink(
                                          ctx, ref, list.id, list.name);
                                    } else if (v == 'delete') {
                                      await _confirmDelete(ctx, ref, list.id,
                                          list.name);
                                    }
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text('${list.wordCount} words',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: AppColors.grey500)),
                            const SizedBox(height: 12),
                            const MasteryBar(fraction: 0),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New List'),
      ),
    );
  }

  Future<void> _importList(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await ref.read(listActionsProvider.notifier).importList();
    if (result == null) return; // user cancelled
    if (result.isFailure) {
      messenger.showSnackBar(SnackBar(
        content: Text(result.exceptionOrNull?.message ?? 'Import failed'),
        backgroundColor: AppColors.secondary,
      ));
    } else {
      final list = result.valueOrNull!;
      messenger.showSnackBar(SnackBar(
        content:
            Text('"${list.name}" imported — ${list.wordCount} words added'),
      ));
    }
  }

  Future<void> _exportList(
      BuildContext context, WidgetRef ref, String listId, String listName) async {
    final messenger = ScaffoldMessenger.of(context);
    final error = await ref
        .read(listActionsProvider.notifier)
        .exportList(listId, listName);
    if (error != null) {
      messenger.showSnackBar(SnackBar(
        content: Text(error),
        backgroundColor: AppColors.secondary,
      ));
    }
  }

  Future<void> _generateAndShareLink(
      BuildContext context, WidgetRef ref, String listId, String listName) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await ref
        .read(listActionsProvider.notifier)
        .generateAndShareLink(listId, listName);
    if (result.isFailure) {
      messenger.showSnackBar(SnackBar(
        content: Text(result.exceptionOrNull?.message ?? 'Failed to generate link'),
        backgroundColor: AppColors.secondary,
      ));
    }
  }

  Future<void> _showCreateDialog(BuildContext context, WidgetRef ref) async {
    final nameCtrl = TextEditingController();
    var quotaExceeded = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => _ListNameDialog(
        title: 'New List',
        controller: nameCtrl,
        onConfirm: () async {
          if (nameCtrl.text.trim().isEmpty) return;
          final result = await ref
              .read(listActionsProvider.notifier)
              .createList(nameCtrl.text.trim(), null);
          if (!ctx.mounted) return;
          if (result.isFailure) {
            if (result.exceptionOrNull is QuotaExceededException) {
              quotaExceeded = true;
              Navigator.pop(ctx);
            } else {
              ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                content: Text(
                    result.exceptionOrNull?.message ?? 'Failed to create list'),
                backgroundColor: AppColors.secondary,
              ));
            }
          } else {
            Navigator.pop(ctx);
          }
        },
      ),
    );

    if (quotaExceeded && context.mounted) context.push('/paywall');
  }

  Future<void> _showRenameDialog(
      BuildContext context, WidgetRef ref, String listId, String current) async {
    final nameCtrl = TextEditingController(text: current);
    await showDialog<void>(
      context: context,
      builder: (ctx) => _ListNameDialog(
        title: 'Rename List',
        controller: nameCtrl,
        confirmLabel: 'Rename',
        onConfirm: () async {
          final newName = nameCtrl.text.trim();
          if (newName.isEmpty || newName == current) return;
          await ref
              .read(listActionsProvider.notifier)
              .renameList(listId, newName);
          if (ctx.mounted) Navigator.pop(ctx);
        },
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, String listId, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete list?'),
        content: Text('"$name" and all its words will be permanently deleted.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: AppColors.secondary),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(listActionsProvider.notifier).deleteList(listId);
    }
  }
}

class _ListsShimmer extends StatelessWidget {
  const _ListsShimmer();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
      highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
        itemCount: 4,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, __) => Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 16, width: 160, color: Colors.white),
                const SizedBox(height: 10),
                Container(height: 12, width: 80, color: Colors.white),
                const SizedBox(height: 14),
                Container(height: 6, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(3))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ListNameDialog extends StatelessWidget {
  const _ListNameDialog({
    required this.title,
    required this.controller,
    required this.onConfirm,
    this.confirmLabel = 'Create',
  });
  final String title;
  final TextEditingController controller;
  final String confirmLabel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'List name'),
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => onConfirm(),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(onPressed: onConfirm, child: Text(confirmLabel)),
      ],
    );
  }
}
