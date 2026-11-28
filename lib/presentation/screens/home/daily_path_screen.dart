import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/v3_colors.dart';
import '../../../core/widget_keys.dart';
import '../../../domain/entities/vocabulary_list.dart';
import '../../../domain/usecases/quiz/get_due_cards_usecase.dart'
    show QuizSource;
import '../../providers/lists/vocabulary_provider.dart';
import '../../providers/quiz/quiz_provider.dart';
import '../../providers/settings/default_pair_provider.dart';
import '../../widgets/v3_pond.dart';
import '../../widgets/scroll_affordance.dart';

/// A short ordered V3 trail. It recommends today's next card without
/// removing independent practice from the rest of the app.
class DailyPathScreen extends ConsumerWidget {
  const DailyPathScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pair = ref.watch(defaultPairProvider);
    final dueProvider = dueCountForPairProvider(pair);
    final due = ref.watch(dueProvider);
    final lists =
        ref.watch(myListsProvider).valueOrNull ?? const <VocabularyList>[];
    final matching = lists.where(
      (list) => list.langA == pair.$1 && list.langB == pair.$2,
    );
    // The daily path must stay within the learner's selected language pair.
    // Falling back to an unrelated list sent, for example, an EN→KO learner
    // into a FR→KO prerequisite and violated the pair shown by the screen.
    final prerequisite = matching.isEmpty ? null : matching.first;

    return Scaffold(
      key: const ValueKey(WidgetKeys.screenDailyPath),
      backgroundColor: V3Colors.app,
      body: Stack(
        children: [
          const Positioned.fill(child: V3Pond(animate: false)),
          SafeArea(
            child: _DailyTrail(
              pair: pair,
              due: due,
              prerequisite: prerequisite,
              onRetryDue: () => ref.invalidate(dueProvider),
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyTrail extends StatelessWidget {
  const _DailyTrail({
    required this.pair,
    required this.due,
    required this.prerequisite,
    required this.onRetryDue,
  });

  final (String, String) pair;
  final AsyncValue<int> due;
  final VocabularyList? prerequisite;
  final VoidCallback onRetryDue;

  @override
  Widget build(BuildContext context) {
    final dueCount = due.isLoading ? null : due.asData?.value;
    final noReviewsDue = dueCount == 0;
    final hasReviewsDue = dueCount != null && dueCount > 0;
    final list = prerequisite;

    return ScrollAffordance(
      hint: 'v3.scroll_hint'.tr(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _BackButton(onTap: () => context.pop()),
              const SizedBox(width: 13),
              Expanded(
                child: Text(
                  'v3.daily_title'.tr(),
                  style: AppTextStyles.mono(
                    12,
                    FontWeight.w400,
                    letterSpacing: 1.1,
                    color: V3Colors.light60,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _TrailCard(
            key: const ValueKey(WidgetKeys.dailyPathReview),
            label: switch (dueCount) {
              null => 'v3.words_due_title'.tr(),
              0 => 'v3.nothing_due_label'.tr(),
              _ => 'v3.your_review'.tr(),
            },
            title: switch (dueCount) {
              null =>
                (due.isLoading
                        ? 'v3.review_due_loading'
                        : 'v3.review_due_error')
                    .tr(),
              0 => 'v3.no_reviews_due'.tr(),
              _ => 'v3.words_due'.tr(namedArgs: {'count': '$dueCount'}),
            },
            active: hasReviewsDue,
            onTap: hasReviewsDue ? () => _showModes(context) : null,
          ),
          if (!due.isLoading && due.hasError)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                key: const ValueKey(WidgetKeys.reviewDueRetry),
                style: TextButton.styleFrom(foregroundColor: V3Colors.amber),
                onPressed: onRetryDue,
                child: Text('common.retry'.tr()),
              ),
            ),
          if (dueCount != null) ...[
            const SizedBox(height: 20),
            _ActiveCard(
              label: noReviewsDue
                  ? 'v3.your_discovery'.tr()
                  : 'v3.your_review'.tr(),
              title: noReviewsDue
                  ? switch (list) {
                      null => 'v3.prepare_list'.tr(),
                      VocabularyList(wordCount: 0) => 'v3.add_words'.tr(),
                      VocabularyList(:final name) => name,
                    }
                  : 'v3.words_due'.tr(namedArgs: {'count': '$dueCount'}),
              subtitle: noReviewsDue
                  ? list == null
                        ? 'v3.few_words'.tr()
                        : 'v3.list_duration'.tr(namedArgs: {'name': list.name})
                  : 'v3.resume_waiting'.tr(),
              cta: noReviewsDue ? 'v3.take_card'.tr() : 'v3.choose_mode'.tr(),
              onTap: noReviewsDue
                  ? () => _openList(context)
                  : () => _showModes(context),
            ),
          ],
          const SizedBox(height: 20),
          _TrailCard(
            key: const ValueKey(WidgetKeys.dailyPathPractice),
            label: switch (dueCount) {
              null => 'v3.see_words'.tr(),
              0 => 'v3.your_discovery'.tr(),
              _ => 'v3.next_discovery'.tr(),
            },
            title: dueCount == null
                ? 'v3.my_lists'.tr()
                : list?.name ?? 'v3.first_list'.tr(),
            active: noReviewsDue,
            onTap: dueCount == null
                ? () => context.push('/lists')
                : noReviewsDue
                ? () => _openList(context)
                : null,
          ),
          const SizedBox(height: 20),
          _TrailCard(
            key: const ValueKey(WidgetKeys.dailyPathLessons),
            label: (dueCount == null ? 'v3.outside_path' : 'v3.next_read').tr(),
            title: (dueCount == null ? 'v3.see_lessons' : 'v3.lesson_discover')
                .tr(),
            onTap: () => context.push('/grammar'),
          ),
          const SizedBox(height: 24),
          const _TrailProgress(),
        ],
      ),
    );
  }

  void _openList(BuildContext context) {
    final list = prerequisite;
    context.push(list == null ? '/lists' : '/lists/${list.id}');
  }

  void _showModes(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
      builder: (sheetContext) => _ModeSheet(
        onSelected: (mode) {
          Navigator.pop(sheetContext);
          context.push(
            '/quiz',
            extra: QuizArgs(
              source: QuizSource.allDue,
              mode: mode,
              direction: QuizDirectionChoice.both,
              cardLimit: const int.fromEnvironment(
                'TEST_CARD_LIMIT',
                defaultValue: 20,
              ),
              langA: pair.$1,
              langB: pair.$2,
            ),
          );
        },
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => IconButton(
    onPressed: onTap,
    tooltip: 'common.back'.tr(),
    style: IconButton.styleFrom(backgroundColor: V3Colors.chip),
    icon: const Icon(Icons.arrow_back_rounded, size: 18, color: V3Colors.light),
  );
}

class _ActiveCard extends StatelessWidget {
  const _ActiveCard({
    required this.label,
    required this.title,
    required this.subtitle,
    required this.cta,
    required this.onTap,
  });
  final String label, title, subtitle, cta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: V3Colors.paper2,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(17, 15, 17, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const DecoratedBox(
                  decoration: BoxDecoration(
                    color: V3Colors.terra,
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox(width: 8, height: 8),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: AppTextStyles.mono(
                      11.5,
                      FontWeight.w700,
                      letterSpacing: 1,
                      color: V3Colors.terraInk,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              title,
              style: AppTextStyles.serif(
                29,
                FontWeight.w400,
                color: V3Colors.ink,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: AppTextStyles.fig(
                14,
                FontWeight.w400,
                color: V3Colors.ink60,
              ),
            ),
            const SizedBox(height: 13),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: V3Colors.terra,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Text(
                cta,
                textAlign: TextAlign.center,
                style: AppTextStyles.fig(
                  15,
                  FontWeight.w700,
                  color: V3Colors.paper,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _TrailCard extends StatelessWidget {
  const _TrailCard({
    super.key,
    required this.label,
    required this.title,
    this.active = false,
    this.onTap,
  });
  final String label, title;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: .035,
    child: Material(
      color: active ? V3Colors.chip2 : Colors.transparent,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: active ? V3Colors.amber : V3Colors.light60,
              width: active ? 1.3 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: AppTextStyles.mono(
                  10.5,
                  FontWeight.w400,
                  letterSpacing: .7,
                  color: V3Colors.light70,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                title,
                style: AppTextStyles.serif(
                  18,
                  FontWeight.w400,
                  color: V3Colors.light,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _TrailProgress extends StatelessWidget {
  const _TrailProgress();
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: V3Colors.block,
      borderRadius: BorderRadius.circular(13),
    ),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'v3.daily_recommendation'.tr(),
            style: AppTextStyles.fig(
              13.5,
              FontWeight.w400,
              color: V3Colors.light70,
            ),
          ),
        ],
      ),
    ),
  );
}

class _ModeSheet extends StatelessWidget {
  const _ModeSheet({required this.onSelected});
  final ValueChanged<QuizMode> onSelected;
  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Align(
      alignment: Alignment.bottomCenter,
      child: ScrollAffordance(
        hint: 'v3.scroll_hint'.tr(),
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.fromLTRB(20, 13, 20, 22),
          decoration: BoxDecoration(
            color: V3Colors.paper2,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x9914170D),
                blurRadius: 44,
                offset: Offset(0, -12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFD3CBB6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'home.review_mode_title'.tr(),
                  style: AppTextStyles.serif(
                    28,
                    FontWeight.w400,
                    color: V3Colors.ink,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              for (final (mode, icon, label) in [
                (QuizMode.voice, Icons.mic_rounded, 'v3.mode_voice'.tr()),
                (
                  QuizMode.handsFree,
                  Icons.headset_mic_rounded,
                  'v3.mode_hands_free'.tr(),
                ),
                (
                  QuizMode.typing,
                  Icons.keyboard_rounded,
                  'v3.mode_typing'.tr(),
                ),
                (
                  QuizMode.flashcard,
                  Icons.style_rounded,
                  'v3.mode_flashcard'.tr(),
                ),
              ]) ...[
                _ModeChoice(
                  mode: mode,
                  icon: icon,
                  label: label,
                  onTap: () => onSelected(mode),
                ),
                const SizedBox(height: 7),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

class _ModeChoice extends StatelessWidget {
  const _ModeChoice({
    required this.mode,
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final QuizMode mode;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: V3Colors.paper3,
    borderRadius: BorderRadius.circular(11),
    child: InkWell(
      key: ValueKey(WidgetKeys.homeReviewMode(mode.name)),
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 19, color: V3Colors.terra),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.fig(
                  14.5,
                  FontWeight.w600,
                  color: V3Colors.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
