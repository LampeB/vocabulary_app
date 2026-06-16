import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../../providers/lists/vocabulary_provider.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/errors/failure.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../domain/entities/vocabulary_list.dart';
import '../../widgets/dotted_ground.dart';
import '../../widgets/frosted_box.dart';

class ListsScreen extends ConsumerWidget {
  const ListsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listsAsync = ref.watch(myListsProvider);

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: Text('Mes listes',
            style: AppTextStyles.grotesk(22, FontWeight.w700)
                .copyWith(color: AppColors.ink)),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.muted),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'import',
                child: Row(children: [
                  const Icon(Icons.file_download_outlined,
                      size: 18, color: AppColors.muted),
                  const SizedBox(width: 10),
                  Text('Importer',
                      style: AppTextStyles.fig(14, FontWeight.w500)
                          .copyWith(color: AppColors.ink)),
                ]),
              ),
            ],
            onSelected: (v) async {
              if (v == 'import') await _importList(context, ref);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          const DottedGround(),
          listsAsync.when(
            loading: () => const _ListsShimmer(),
            error: (e, _) => Center(
              child: Text('Erreur : $e',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.rose)),
            ),
            data: (lists) => lists.isEmpty
                ? _EmptyState(
                    onCreateTap: () => _showCreateDialog(context, ref))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    itemCount: lists.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 10),
                    itemBuilder: (ctx, i) => _ListCard(
                      list: lists[i],
                      accentColor: AppColors.listPalette[
                          i % AppColors.listPalette.length],
                      onTap: () =>
                          context.go('/lists/${lists[i].id}'),
                      onRename: () => _showRenameDialog(
                          ctx, ref, lists[i].id, lists[i].name),
                      onExport: () => _exportList(
                          ctx, ref, lists[i].id, lists[i].name),
                      onShare: () => _generateAndShareLink(
                          ctx, ref, lists[i].id, lists[i].name),
                      onDelete: () =>
                          _confirmDelete(ctx, ref, lists[i].id, lists[i].name),
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context, ref),
        backgroundColor: AppColors.clay,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999)),
        icon: const Icon(Icons.add, size: 20),
        label: Text('Nouvelle liste',
            style: AppTextStyles.fig(14, FontWeight.w700)),
      ),
    );
  }

  // ── Actions ──────────────────────────────────────────────────────────────────

  Future<void> _importList(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await ref.read(listActionsProvider.notifier).importList();
    if (result == null) return;
    if (result.isFailure) {
      messenger.showSnackBar(SnackBar(
        content: Text(result.exceptionOrNull?.message ?? 'Import échoué'),
      ));
    } else {
      final list = result.valueOrNull!;
      messenger.showSnackBar(SnackBar(
        content:
            Text('"${list.name}" importée — ${list.wordCount} mots ajoutés'),
      ));
    }
  }

  Future<void> _exportList(
      BuildContext context, WidgetRef ref, String listId,
      String listName) async {
    final messenger = ScaffoldMessenger.of(context);
    final error = await ref
        .read(listActionsProvider.notifier)
        .exportList(listId, listName);
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _generateAndShareLink(BuildContext context, WidgetRef ref,
      String listId, String listName) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await ref
        .read(listActionsProvider.notifier)
        .generateAndShareLink(listId, listName);
    if (result.isFailure) {
      messenger.showSnackBar(SnackBar(
        content: Text(
            result.exceptionOrNull?.message ?? 'Lien non créé'),
      ));
    }
  }

  Future<void> _showCreateDialog(BuildContext context, WidgetRef ref) async {
    final nameCtrl = TextEditingController();
    var quotaExceeded = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => _ListNameDialog(
        title: 'Nouvelle liste',
        controller: nameCtrl,
        confirmLabel: 'Créer',
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
                content: Text(result.exceptionOrNull?.message ??
                    'Erreur lors de la création'),
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

  Future<void> _showRenameDialog(BuildContext context, WidgetRef ref,
      String listId, String current) async {
    final nameCtrl = TextEditingController(text: current);
    await showDialog<void>(
      context: context,
      builder: (ctx) => _ListNameDialog(
        title: 'Renommer la liste',
        controller: nameCtrl,
        confirmLabel: 'Renommer',
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

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref,
      String listId, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Supprimer la liste ?',
            style: AppTextStyles.grotesk(20, FontWeight.w700)
                .copyWith(color: AppColors.ink)),
        content: Text(
          '« $name » et tous ses mots seront supprimés définitivement.',
          style: AppTextStyles.body.copyWith(color: AppColors.muted),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.rose),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Supprimer',
                style: AppTextStyles.fig(14, FontWeight.w600)
                    .copyWith(color: AppColors.rose)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(listActionsProvider.notifier).deleteList(listId);
    }
  }
}

// ── List card ─────────────────────────────────────────────────────────────────

class _ListCard extends StatelessWidget {
  const _ListCard({
    required this.list,
    required this.accentColor,
    required this.onTap,
    required this.onRename,
    required this.onExport,
    required this.onShare,
    required this.onDelete,
  });

  final VocabularyList list;
  final Color accentColor;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onExport;
  final VoidCallback onShare;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: FrostedBox(
        borderRadius: BorderRadius.circular(20),
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Row(
          children: [
            // Palette accent dot
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
                  const SizedBox(height: 2),
                  Text(
                    '${list.wordCount} mot${list.wordCount == 1 ? '' : 's'}',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.muted),
                  ),
                ],
              ),
            ),
            // Kebab menu
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert,
                  color: AppColors.faint, size: 20),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              itemBuilder: (_) => [
                _menuItem('rename', Icons.edit_outlined, 'Renommer'),
                _menuItem('export', Icons.ios_share_outlined, 'Exporter'),
                _menuItem('share', Icons.link_outlined, 'Lien de partage'),
                _menuItem('delete', Icons.delete_outline, 'Supprimer',
                    isDestructive: true),
              ],
              onSelected: (v) {
                if (v == 'rename') onRename();
                if (v == 'export') onExport();
                if (v == 'share') onShare();
                if (v == 'delete') onDelete();
              },
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _menuItem(
      String value, IconData icon, String label,
      {bool isDestructive = false}) {
    final color = isDestructive ? AppColors.rose : AppColors.ink;
    return PopupMenuItem(
      value: value,
      child: Row(children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Text(label,
            style: AppTextStyles.fig(14, FontWeight.w500)
                .copyWith(color: color)),
      ]),
    );
  }
}

// ── Shimmer placeholder ────────────────────────────────────────────────────────

class _ListsShimmer extends StatelessWidget {
  const _ListsShimmer();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE8E0D4),
      highlightColor: const Color(0xFFF4EFE8),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        itemCount: 5,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, __) => Container(
          height: 64,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreateTap});
  final VoidCallback onCreateTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bookmark_border,
                size: 56, color: AppColors.faint),
            const SizedBox(height: 16),
            Text('Pas encore de listes',
                style: AppTextStyles.grotesk(20, FontWeight.w700)
                    .copyWith(color: AppColors.ink)),
            const SizedBox(height: 8),
            Text(
              'Crée ta première liste de vocabulaire pour commencer.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: onCreateTap,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.clay,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('Créer une liste',
                    style: AppTextStyles.fig(15, FontWeight.w700)
                        .copyWith(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── List name dialog ──────────────────────────────────────────────────────────

class _ListNameDialog extends StatelessWidget {
  const _ListNameDialog({
    required this.title,
    required this.controller,
    required this.onConfirm,
    this.confirmLabel = 'Créer',
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
        decoration: const InputDecoration(labelText: 'Nom de la liste'),
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => onConfirm(),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler')),
        FilledButton(
            onPressed: onConfirm, child: Text(confirmLabel)),
      ],
    );
  }
}
