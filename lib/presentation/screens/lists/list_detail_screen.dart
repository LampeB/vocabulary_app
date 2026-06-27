import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/lists/vocabulary_provider.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/errors/failure.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../widgets/dotted_ground.dart';
import '../../widgets/frosted_box.dart';

class ListDetailScreen extends ConsumerStatefulWidget {
  const ListDetailScreen({super.key, required this.listId});
  final String listId;

  @override
  ConsumerState<ListDetailScreen> createState() => _ListDetailScreenState();
}

class _ListDetailScreenState extends ConsumerState<ListDetailScreen> {
  bool _editMode = false;

  @override
  Widget build(BuildContext context) {
    final listAsync    = ref.watch(listInfoProvider(widget.listId));
    final conceptsAsync = ref.watch(listDetailProvider(widget.listId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: listAsync.when(
          data: (l) => Text(l?.name ?? 'list_detail.appbar_fallback'.tr()),
          loading: () => const SizedBox.shrink(),
          error: (_, __) => Text('list_detail.appbar_fallback'.tr()),
        ),
        actions: _editMode
            ? [
                TextButton(
                  onPressed: () => setState(() => _editMode = false),
                  child: Text(
                    'list_detail.action_done'.tr(),
                    style: AppTextStyles.fig(14, FontWeight.w600)
                        .copyWith(color: AppColors.clay),
                  ),
                ),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.ios_share_outlined, size: 22),
                  tooltip: 'list_detail.tooltip_export'.tr(),
                  onPressed: () => _exportList(
                      context, listAsync.valueOrNull?.name ?? ''),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    if (value == 'edit') setState(() => _editMode = true);
                    if (value == 'export') {
                      _exportList(
                          context, listAsync.valueOrNull?.name ?? '');
                    }
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          const Icon(Icons.edit_outlined, size: 18),
                          const SizedBox(width: 12),
                          Text('list_detail.menu_edit'.tr()),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'export',
                      child: Row(
                        children: [
                          const Icon(Icons.ios_share_outlined, size: 18),
                          const SizedBox(width: 12),
                          Text('list_detail.menu_export'.tr()),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
      ),
      body: Stack(
        children: [
          const DottedGround(),
          conceptsAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(
                  color: AppColors.clay, strokeWidth: 2),
            ),
            error: (e, _) => Center(
              child: Text('$e',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.rose)),
            ),
            data: (concepts) => concepts.isEmpty
                ? _EmptyState(
                    onAddTap: () => _showAddWordDialog(context))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    itemCount: concepts.length,
                    itemBuilder: (ctx, i) => _ConceptTile(
                      key: Key(concepts[i].id),
                      concept: concepts[i],
                      listId: widget.listId,
                      editMode: _editMode,
                    ),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          // Studying is launched from the central nav button (Start-a-session);
          // the list screen is for management only.
          child: _addWordBar(context),
        ),
      ),
    );
  }

  // ── Bottom bar variants ───────────────────────────────────────────────────

  Widget _addWordBar(BuildContext context) {
    return GestureDetector(
      onTap: () => _showAddWordDialog(context),
      child: FrostedBox(
        borderRadius: BorderRadius.circular(999),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Builder(builder: (ctx) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final muted =
              isDark ? AppColors.onDarkMuted : AppColors.muted;
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add, color: muted, size: 18),
              const SizedBox(width: 8),
              Text('list_detail.add_word_bar'.tr(),
                  style: AppTextStyles.fig(15, FontWeight.w600)
                      .copyWith(color: muted)),
            ],
          );
        }),
      ),
    );
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _exportList(
      BuildContext context, String listName) async {
    final messenger = ScaffoldMessenger.of(context);
    final error = await ref
        .read(listActionsProvider.notifier)
        .exportList(widget.listId,
            listName.isEmpty ? widget.listId : listName);
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _showAddWordDialog(BuildContext context) async {
    final frCtrl = TextEditingController();
    final koCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var quotaExceeded = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text('list_detail.add_dialog_title'.tr()),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: frCtrl,
                autofocus: true,
                decoration: InputDecoration(
                    labelText: 'list_detail.field_french'.tr(), prefixText: '🇫🇷  '),
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    (v?.trim().isEmpty ?? true) ? 'Requis' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: koCtrl,
                decoration: InputDecoration(
                    labelText: 'list_detail.field_korean'.tr(), prefixText: '🇰🇷  '),
                validator: (v) =>
                    (v?.trim().isEmpty ?? true) ? 'Requis' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('common.cancel'.tr())),
          FilledButton(
            onPressed: () async {
              if (!(formKey.currentState?.validate() ?? false)) return;
              final result = await ref
                  .read(listActionsProvider.notifier)
                  .addConcept(
                    listId: widget.listId,
                    frWord: frCtrl.text.trim(),
                    koWord: koCtrl.text.trim(),
                  );
              if (!ctx.mounted) return;
              if (result.isFailure &&
                  result.exceptionOrNull is QuotaExceededException) {
                quotaExceeded = true;
                Navigator.pop(ctx);
              } else if (result.isSuccess) {
                Navigator.pop(ctx);
              }
            },
            child: Text('list_detail.add_confirm'.tr()),
          ),
        ],
      ),
    );

    if (quotaExceeded && context.mounted) context.push('/paywall');
  }
}

// ── Concept tile ──────────────────────────────────────────────────────────────

class _ConceptTile extends ConsumerWidget {
  const _ConceptTile({
    super.key,
    required this.concept,
    required this.listId,
    required this.editMode,
  });
  final dynamic concept;
  final String listId;
  final bool editMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final variantsAsync = ref.watch(variantsProvider(concept.id));

    return variantsAsync.when(
      loading: () => Container(
        margin: const EdgeInsets.only(bottom: 8),
        height: 64,
        decoration: BoxDecoration(
          color: cs.outline.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (variants) {
        final fr =
            variants.where((v) => v.langCode == 'fr' && !v.isDeleted).toList();
        final ko =
            variants.where((v) => v.langCode == 'ko' && !v.isDeleted).toList();
        final frWord = fr.isNotEmpty ? fr.first.word : '—';
        final koWord = ko.isNotEmpty ? ko.first.word : '—';

        Future<void> showEditDialog() async {
          if (fr.isEmpty || ko.isEmpty) return;
          final frCtrl = TextEditingController(text: frWord);
          final koCtrl = TextEditingController(text: koWord);
          final formKey = GlobalKey<FormState>();
          await showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text('list_detail.edit_dialog_title'.tr()),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: frCtrl,
                      autofocus: true,
                      decoration: InputDecoration(
                          labelText: 'list_detail.field_french'.tr(), prefixText: '🇫🇷  '),
                      textInputAction: TextInputAction.next,
                      validator: (v) =>
                          (v?.trim().isEmpty ?? true) ? 'Requis' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: koCtrl,
                      decoration: InputDecoration(
                          labelText: 'list_detail.field_korean'.tr(), prefixText: '🇰🇷  '),
                      validator: (v) =>
                          (v?.trim().isEmpty ?? true) ? 'Requis' : null,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('common.cancel'.tr()),
                ),
                FilledButton(
                  onPressed: () async {
                    if (!(formKey.currentState?.validate() ?? false)) return;
                    await ref
                        .read(listActionsProvider.notifier)
                        .updateVariants(
                          frVariant: fr.first,
                          newFrWord: frCtrl.text.trim(),
                          koVariant: ko.first,
                          newKoWord: koCtrl.text.trim(),
                        );
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: Text('list_detail.edit_confirm'.tr()),
                ),
              ],
            ),
          );
        }

        Future<void> confirmDelete() async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text('list_detail.delete_dialog_title'.tr()),
              content: Text(
                  'list_detail.delete_dialog_body'.tr(namedArgs: {'frWord': frWord, 'koWord': koWord})),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text('common.cancel'.tr()),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                      foregroundColor: AppColors.rose),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text('common.delete'.tr(),
                      style: AppTextStyles.fig(14, FontWeight.w600)
                          .copyWith(color: AppColors.rose)),
                ),
              ],
            ),
          );
          if (confirmed == true) {
            ref.read(listActionsProvider.notifier).deleteConcept(concept.id);
          }
        }

        final tile = FrostedBox(
          borderRadius: BorderRadius.circular(16),
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Builder(builder: (ctx) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            final ink = isDark ? AppColors.onDark : AppColors.ink;
            return Row(
              children: [
                // French side
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('list_detail.lang_fr'.tr(),
                          style: AppTextStyles.eyebrowSm
                              .copyWith(color: AppColors.teal)),
                      const SizedBox(height: 2),
                      Text(frWord,
                          style: AppTextStyles.fig(15, FontWeight.w600)
                              .copyWith(color: ink),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                // Divider
                Container(
                  width: 1,
                  height: 36,
                  color: cs.outline,
                  margin: const EdgeInsets.symmetric(horizontal: 14),
                ),
                // Korean side
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('list_detail.lang_kr'.tr(),
                          style: AppTextStyles.eyebrowSm
                              .copyWith(color: AppColors.clay)),
                      const SizedBox(height: 2),
                      Text(koWord,
                          style: AppTextStyles.kr(16, FontWeight.w500)
                              .copyWith(color: ink),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                // Edit-mode action buttons
                if (editMode) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: showEditDialog,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.edit_outlined,
                          color: AppColors.teal.withValues(alpha: 0.7),
                          size: 20),
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: confirmDelete,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.delete_outline,
                          color: AppColors.rose.withValues(alpha: 0.6),
                          size: 20),
                    ),
                  ),
                ],
              ],
            );
          }),
        );

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: editMode
              ? GestureDetector(onTap: showEditDialog, child: tile)
              : tile,
        );
      },
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAddTap});
  final VoidCallback onAddTap;

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
            Icon(Icons.auto_stories_outlined, size: 56, color: faint),
            const SizedBox(height: 16),
            Text('list_detail.empty_title'.tr(),
                style: AppTextStyles.grotesk(20, FontWeight.w700)
                    .copyWith(color: cs.onSurface)),
            const SizedBox(height: 8),
            Text(
              'list_detail.empty_subtitle'.tr(),
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(color: muted),
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: onAddTap,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.clay,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('list_detail.empty_button'.tr(),
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
