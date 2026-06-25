import 'package:easy_localization/easy_localization.dart';
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
      // Background from AppTheme.scaffoldBackgroundColor.
      appBar: AppBar(
        // AppBarTheme provides title style and icon colors.
        title: Text('lists.title'.tr()),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'import',
                child: Row(children: [
                  const Icon(Icons.file_download_outlined, size: 18),
                  const SizedBox(width: 10),
                  Text('lists.menu_import'.tr()),
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
              child: Text(
                  'lists.error_loading'.tr(namedArgs: {'error': e.toString()}),
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
                          context.push('/lists/${lists[i].id}'),
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
        label: Text('lists.fab_new'.tr(),
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
        content: Text(result.exceptionOrNull?.message ??
            'lists.import_snackbar_error_fallback'.tr()),
      ));
    } else {
      final list = result.valueOrNull!;
      messenger.showSnackBar(SnackBar(
        content: Text(
            '"${list.name}" ${'lists.import_snackbar_success'.tr(namedArgs: {'wordCount': list.wordCount.toString()})}'),
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
            result.exceptionOrNull?.message ??
                'lists.share_link_error_fallback'.tr()),
      ));
    }
  }

  Future<void> _showCreateDialog(BuildContext context, WidgetRef ref) async {
    final nameCtrl = TextEditingController();
    var quotaExceeded = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => _ListNameDialog(
        title: 'lists.create_dialog_title'.tr(),
        controller: nameCtrl,
        confirmLabel: 'lists.create_dialog_confirm'.tr(),
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
                    'lists.create_error_fallback'.tr()),
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
        title: 'lists.rename_dialog_title'.tr(),
        controller: nameCtrl,
        confirmLabel: 'lists.rename_dialog_confirm'.tr(),
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
        // dialogTheme provides title/content colors automatically.
        title: Text('lists.delete_dialog_title'.tr()),
        content: Text('lists.delete_dialog_body'.tr(namedArgs: {'name': name})),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('common.cancel'.tr())),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.rose),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('lists.delete_confirm'.tr(),
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
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final muted = isDark ? AppColors.onDarkMuted : AppColors.muted;
    final faint = isDark ? AppColors.onDarkFaint : AppColors.faint;

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
                        .copyWith(color: cs.onSurface),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${list.wordCount} ${list.wordCount == 1 ? 'lists.list_word_count_one'.tr() : 'lists.list_word_count_other'.tr()}',
                    style: AppTextStyles.caption.copyWith(color: muted),
                  ),
                ],
              ),
            ),
            // Kebab menu
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: faint, size: 20),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              itemBuilder: (ctx) => [
                _menuItem(ctx, 'rename', Icons.edit_outlined,
                    'lists.menu_rename'.tr()),
                _menuItem(ctx, 'export', Icons.ios_share_outlined,
                    'lists.menu_export'.tr()),
                _menuItem(ctx, 'share', Icons.link_outlined,
                    'lists.menu_share_link'.tr()),
                _menuItem(ctx, 'delete', Icons.delete_outline,
                    'lists.menu_delete'.tr(),
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
      BuildContext context, String value, IconData icon, String label,
      {bool isDestructive = false}) {
    final color = isDestructive
        ? AppColors.rose
        : Theme.of(context).colorScheme.onSurface;
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
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final muted = isDark ? AppColors.onDarkMuted : AppColors.muted;
    final faint = isDark ? AppColors.onDarkFaint : AppColors.faint;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bookmark_border, size: 56, color: faint),
            const SizedBox(height: 16),
            Text('lists.empty_title'.tr(),
                style: AppTextStyles.grotesk(20, FontWeight.w700)
                    .copyWith(color: cs.onSurface)),
            const SizedBox(height: 8),
            Text(
              'lists.empty_subtitle'.tr(),
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(color: muted),
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
                child: Text('lists.empty_button'.tr(),
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
    this.confirmLabel = '',
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
        decoration: InputDecoration(labelText: 'lists.name_field_label'.tr()),
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => onConfirm(),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('common.cancel'.tr())),
        FilledButton(
            onPressed: onConfirm, child: Text(confirmLabel)),
      ],
    );
  }
}
