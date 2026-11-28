import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/languages.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../domain/entities/vocabulary_list.dart';
import '../providers/lists/vocabulary_provider.dart';
import 'scroll_affordance.dart';

Future<void> showListPreviewSheet(BuildContext context, VocabularyList list) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ListPreviewSheet(list: list),
    );

// ── List preview sheet ────────────────────────────────────────────────────────

/// Read-only peek at a list's word pairs, opened from the peek icon on a list
/// tile so the user can see "what's in it" before choosing it.
class _ListPreviewSheet extends ConsumerWidget {
  const _ListPreviewSheet({required this.list});
  final VocabularyList list;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conceptsAsync = ref.watch(listDetailProvider(list.id));
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .7,
        ),
        child: ScrollAffordance.slivers(
          hint: 'v3.scroll_hint'.tr(),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          list.name,
                          style: AppTextStyles.grotesk(20, FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${Languages.flagFor(list.langA)} → ${Languages.flagFor(list.langB)}',
                      style: AppTextStyles.body,
                    ),
                  ],
                ),
              ),
            ),
            conceptsAsync.when(
              loading: () => const SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(
                      color: AppColors.clay,
                      strokeWidth: 2,
                    ),
                  ),
                ),
              ),
              error: (_, _) =>
                  SliverToBoxAdapter(child: Text('common.error'.tr())),
              data: (concepts) {
                final visible = concepts
                    .where((concept) => !concept.isDeleted)
                    .toList();
                if (visible.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'list_detail.empty_subtitle'.tr(),
                        style: AppTextStyles.body,
                      ),
                    ),
                  );
                }
                return SliverList.separated(
                  itemCount: visible.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  itemBuilder: (_, i) => _PreviewRow(
                    conceptId: visible[i].id,
                    langA: list.langA,
                    langB: list.langB,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewRow extends ConsumerWidget {
  const _PreviewRow({
    required this.conceptId,
    required this.langA,
    required this.langB,
  });
  final String conceptId;
  final String langA;
  final String langB;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final words = ref.watch(variantsProvider(conceptId)).valueOrNull ?? [];
    String wordFor(String lang) {
      for (final v in words) {
        if (v.langCode == lang && !v.isDeleted) return v.word;
      }
      return '—';
    }

    TextStyle styleFor(String lang, {Color? color}) =>
        Languages.usesHangul(lang)
        ? AppTextStyles.koreanBody.copyWith(color: color)
        : AppTextStyles.fig(15, FontWeight.w600).copyWith(color: color);

    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(wordFor(langA), style: styleFor(langA))),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              wordFor(langB),
              textAlign: TextAlign.end,
              style: styleFor(langB, color: muted),
            ),
          ),
        ],
      ),
    );
  }
}
