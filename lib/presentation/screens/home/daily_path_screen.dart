import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widget_keys.dart';
import '../../../domain/entities/vocabulary_list.dart';
import '../../../domain/usecases/quiz/get_due_cards_usecase.dart'
    show QuizSource;
import '../../providers/lists/vocabulary_provider.dart';
import '../../providers/quiz/quiz_provider.dart';
import '../../providers/settings/default_pair_provider.dart';

/// The focused daily route from the approved dark S18 mockup. It recommends
/// the next action but never blocks independent vocabulary practice.
class DailyPathScreen extends ConsumerWidget {
  const DailyPathScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pair = ref.watch(defaultPairProvider);
    final due = ref.watch(dueCountForPairProvider(pair));
    final lists =
        ref.watch(myListsProvider).valueOrNull ?? const <VocabularyList>[];
    final matching =
        lists.where((list) => list.langA == pair.$1 && list.langB == pair.$2);
    final prerequisite = matching.isEmpty
        ? (lists.isEmpty ? null : lists.first)
        : matching.first;

    return Scaffold(
      key: const ValueKey(WidgetKeys.screenDailyPath),
      backgroundColor: const Color(0xFF241F1B),
      body: SafeArea(
        child: due.when(
          loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.clayLight)),
          error: (_, __) =>
              _DailyBody(pair: pair, dueCount: 0, prerequisite: prerequisite),
          data: (count) => _DailyBody(
              pair: pair, dueCount: count, prerequisite: prerequisite),
        ),
      ),
    );
  }
}

class _DailyBody extends StatelessWidget {
  const _DailyBody({
    required this.pair,
    required this.dueCount,
    required this.prerequisite,
  });
  final (String, String) pair;
  final int dueCount;
  final VocabularyList? prerequisite;

  @override
  Widget build(BuildContext context) {
    final reviewDone = dueCount == 0;
    final completed = reviewDone ? 1 : 0;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 20, 22),
          child: Row(children: [
            IconButton(
              onPressed: () => context.pop(),
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Color(0xFFCFC6BA)),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text('daily_path.title'.tr(),
                  style: AppTextStyles.grotesk(28, FontWeight.w800)
                      .copyWith(color: const Color(0xFFF6F1EA))),
            ),
            Text('$completed/4',
                style: AppTextStyles.fig(18, FontWeight.w700)
                    .copyWith(color: const Color(0xFFCFC6BA))),
          ]),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
            children: [
              _DailyTask(
                key: const ValueKey(WidgetKeys.dailyPathReview),
                icon: Icons.check_rounded,
                title: 'daily_path.review_title'.tr(),
                subtitle: reviewDone
                    ? 'daily_path.review_clear'.tr()
                    : 'daily_path.review_due'
                        .tr(namedArgs: {'count': '$dueCount'}),
                stateLabel: reviewDone
                    ? 'course.done'.tr()
                    : 'daily_path.review_open'.tr(),
                done: reviewDone,
                active: !reviewDone,
                onTap: dueCount > 0
                    ? () => _showReviewModeSheet(context, pair)
                    : null,
              ),
              const SizedBox(height: 18),
              _DailyTask(
                key: const ValueKey(WidgetKeys.dailyPathPractice),
                icon: Icons.add_rounded,
                title: 'course.step_discover'.tr(),
                subtitle: prerequisite == null
                    ? 'course.no_list'.tr()
                    : prerequisite!.name,
                stateLabel:
                    reviewDone ? 'course.your_turn'.tr() : 'course.next'.tr(),
                active: reviewDone,
                onTap: reviewDone
                    ? () => prerequisite == null
                        ? context.go('/lists')
                        : context.push('/lists/${prerequisite!.id}')
                    : null,
              ),
              const SizedBox(height: 18),
              _DailyTask(
                key: const ValueKey(WidgetKeys.dailyPathLessons),
                icon: Icons.menu_book_outlined,
                title: 'daily_path.lessons_title'.tr(),
                subtitle: 'daily_path.lessons_subtitle'.tr(),
                stateLabel: 'course.next'.tr(),
                onTap: () => context.push('/grammar'),
              ),
              const SizedBox(height: 18),
              _DailyTask(
                icon: Icons.adjust_rounded,
                title: 'course.step_drill'.tr(),
                subtitle: 'course.drill_hint'.tr(),
                stateLabel: 'course.next'.tr(),
              ),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    color: const Color(0xFF2E2823),
                    borderRadius: BorderRadius.circular(24)),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.schedule_outlined,
                          color: Color(0xFFCFC6BA)),
                      const SizedBox(width: 14),
                      Expanded(
                          child: Text('course.path_frozen'.tr(),
                              style: AppTextStyles.body
                                  .copyWith(color: const Color(0xFFCFC6BA)))),
                    ]),
              ),
              const SizedBox(height: 12),
              Text(
                'daily_path.optional_hint'.tr(),
                textAlign: TextAlign.center,
                style: AppTextStyles.caption
                    .copyWith(color: const Color(0xFF9A9086)),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => context.pop(),
              style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFE8D6BF),
                  side: const BorderSide(color: Color(0xFF665C52))),
              child: Text('course.back_to_path'.tr()),
            ),
          ),
        ),
      ],
    );
  }

  void _showReviewModeSheet(BuildContext context, (String, String) pair) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final (mode, icon, labelKey) in [
            (QuizMode.voice, Icons.mic_rounded, 'quiz_setup.mode_voice_label'),
            (
              QuizMode.handsFree,
              Icons.headset_mic_rounded,
              'quiz_setup.mode_hands_free_label'
            ),
            (
              QuizMode.typing,
              Icons.keyboard_rounded,
              'quiz_setup.mode_typing_label'
            ),
            (
              QuizMode.flashcard,
              Icons.style_rounded,
              'quiz_setup.mode_flashcard_label'
            ),
          ])
            ListTile(
              key: ValueKey(WidgetKeys.homeReviewMode(mode.name)),
              leading: Icon(icon),
              title: Text(labelKey.tr()),
              onTap: () {
                Navigator.pop(sheetContext);
                context.push('/quiz',
                    extra: QuizArgs(
                      source: QuizSource.allDue,
                      mode: mode,
                      direction: QuizDirectionChoice.both,
                      cardLimit: const int.fromEnvironment('TEST_CARD_LIMIT',
                          defaultValue: 20),
                      langA: pair.$1,
                      langB: pair.$2,
                    ));
              },
            ),
        ]),
      ),
    );
  }
}

class _DailyTask extends StatelessWidget {
  const _DailyTask({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.stateLabel,
    this.done = false,
    this.active = false,
    this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final String stateLabel;
  final bool done;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = done
        ? AppColors.tealLight
        : active
            ? AppColors.clayLight
            : const Color(0xFF9A9086);
    return Material(
      color: const Color(0xFF2E2823),
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
                color: active ? AppColors.clayLight : const Color(0xFF423A33),
                width: active ? 2 : 1),
          ),
          child: Row(children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(18)),
              child: Icon(icon, color: accent, size: 30),
            ),
            const SizedBox(width: 18),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      style: AppTextStyles.fig(22, FontWeight.w800)
                          .copyWith(color: const Color(0xFFF6F1EA))),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: AppTextStyles.body
                          .copyWith(color: const Color(0xFFCFC6BA))),
                ])),
            const SizedBox(width: 8),
            SizedBox(
              width: 66,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(stateLabel,
                    style: AppTextStyles.fig(14, FontWeight.w800)
                        .copyWith(color: accent)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
