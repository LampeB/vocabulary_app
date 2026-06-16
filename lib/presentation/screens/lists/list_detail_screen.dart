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

class ListDetailScreen extends ConsumerWidget {
  const ListDetailScreen({super.key, required this.listId});
  final String listId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync    = ref.watch(listInfoProvider(listId));
    final conceptsAsync = ref.watch(listDetailProvider(listId));

    final listName = listAsync.valueOrNull?.name ?? '';

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.ink, size: 20),
          onPressed: () => context.pop(),
        ),
        title: listAsync.when(
          data: (l) => Text(
            l?.name ?? 'Liste',
            style: AppTextStyles.grotesk(22, FontWeight.w700)
                .copyWith(color: AppColors.ink),
          ),
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const Text('Liste'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share_outlined,
                color: AppColors.muted, size: 22),
            tooltip: 'Exporter',
            onPressed: () => _exportList(context, ref, listName),
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
                    onAddTap: () => _showAddWordDialog(context, ref))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    itemCount: concepts.length,
                    itemBuilder: (ctx, i) => _ConceptTile(
                      key: Key(concepts[i].id),
                      concept: concepts[i],
                      listId: listId,
                    ),
                  ),
          ),
        ],
      ),
      // Bottom action bar: start session + add word
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Row(
            children: [
              // Add word pill
              GestureDetector(
                onTap: () => _showAddWordDialog(context, ref),
                child: FrostedBox(
                  borderRadius: BorderRadius.circular(999),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add, color: AppColors.muted, size: 18),
                      const SizedBox(width: 6),
                      Text('Ajouter',
                          style: AppTextStyles.fig(14, FontWeight.w600)
                              .copyWith(color: AppColors.muted)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Start session (primary CTA)
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.play_arrow_rounded,
                      color: Colors.white, size: 20),
                  label: Text('Démarrer',
                      style: AppTextStyles.fig(15, FontWeight.w700)
                          .copyWith(color: Colors.white)),
                  onPressed: () =>
                      context.go('/lists/$listId/quiz-setup'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.clay,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportList(
      BuildContext context, WidgetRef ref, String listName) async {
    final messenger = ScaffoldMessenger.of(context);
    final error = await ref
        .read(listActionsProvider.notifier)
        .exportList(listId, listName.isEmpty ? listId : listName);
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _showAddWordDialog(BuildContext context, WidgetRef ref) async {
    final frCtrl = TextEditingController();
    final koCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var quotaExceeded = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text('Ajouter un mot',
            style: AppTextStyles.grotesk(20, FontWeight.w700)
                .copyWith(color: AppColors.ink)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: frCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                    labelText: 'Français', prefixText: '🇫🇷  '),
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    (v?.trim().isEmpty ?? true) ? 'Requis' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: koCtrl,
                decoration: const InputDecoration(
                    labelText: 'Coréen', prefixText: '🇰🇷  '),
                validator: (v) =>
                    (v?.trim().isEmpty ?? true) ? 'Requis' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler')),
          FilledButton(
            onPressed: () async {
              if (!(formKey.currentState?.validate() ?? false)) return;
              final result =
                  await ref.read(listActionsProvider.notifier).addConcept(
                        listId: listId,
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
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );

    if (quotaExceeded && context.mounted) context.push('/paywall');
  }
}

// ── Concept tile ──────────────────────────────────────────────────────────────

class _ConceptTile extends ConsumerWidget {
  const _ConceptTile(
      {super.key, required this.concept, required this.listId});
  final dynamic concept;
  final String listId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final variantsAsync = ref.watch(variantsProvider(concept.id));

    return variantsAsync.when(
      loading: () => Container(
        margin: const EdgeInsets.only(bottom: 8),
        height: 64,
        decoration: BoxDecoration(
          color: AppColors.line.withValues(alpha: 0.5),
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

        return Dismissible(
          key: Key(concept.id),
          direction: DismissDirection.endToStart,
          background: Container(
            margin: const EdgeInsets.only(bottom: 8),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(
              color: AppColors.rose.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.delete_outline,
                color: AppColors.rose),
          ),
          confirmDismiss: (_) => showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text('Supprimer le mot ?',
                  style: AppTextStyles.grotesk(20, FontWeight.w700)
                      .copyWith(color: AppColors.ink)),
              content: Text(
                '« $frWord / $koWord » sera supprimé de cette liste.',
                style:
                    AppTextStyles.body.copyWith(color: AppColors.muted),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Annuler')),
                TextButton(
                  style: TextButton.styleFrom(
                      foregroundColor: AppColors.rose),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text('Supprimer',
                      style: AppTextStyles.fig(14, FontWeight.w600)
                          .copyWith(color: AppColors.rose)),
                ),
              ],
            ),
          ),
          onDismissed: (_) {
            ref
                .read(listActionsProvider.notifier)
                .deleteConcept(concept.id);
          },
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: FrostedBox(
              borderRadius: BorderRadius.circular(16),
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  // French side
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('FR',
                            style: AppTextStyles.eyebrowSm
                                .copyWith(color: AppColors.teal)),
                        const SizedBox(height: 2),
                        Text(frWord,
                            style: AppTextStyles.fig(
                                    15, FontWeight.w600)
                                .copyWith(color: AppColors.ink),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  // Divider
                  Container(
                    width: 1,
                    height: 36,
                    color: AppColors.line,
                    margin: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  // Korean side
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('KR',
                            style: AppTextStyles.eyebrowSm
                                .copyWith(color: AppColors.clay)),
                        const SizedBox(height: 2),
                        Text(koWord,
                            style: AppTextStyles.kr(
                                    16, FontWeight.w500)
                                .copyWith(color: AppColors.ink),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_stories_outlined,
                size: 56, color: AppColors.faint),
            const SizedBox(height: 16),
            Text('Aucun mot pour l\'instant',
                style: AppTextStyles.grotesk(20, FontWeight.w700)
                    .copyWith(color: AppColors.ink)),
            const SizedBox(height: 8),
            Text(
              'Ajoute des paires de mots pour commencer à étudier.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(color: AppColors.muted),
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
                child: Text('Ajouter un mot',
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
