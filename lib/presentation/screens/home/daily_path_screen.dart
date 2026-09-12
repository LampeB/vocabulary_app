import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/languages.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widget_keys.dart';
import '../../../domain/usecases/quiz/get_due_cards_usecase.dart'
    show QuizSource;
import '../../providers/lists/vocabulary_provider.dart';
import '../../providers/quiz/quiz_provider.dart';
import '../../providers/settings/default_pair_provider.dart';
import '../../widgets/dotted_ground.dart';
import '../../widgets/frosted_box.dart';

/// The optional daily-plan entry point (S18).
///
/// It deliberately assembles only already-working capabilities. It is not a
/// second gate around vocabulary: Lists and their direct quiz actions remain
/// available whether or not a learner opens this screen.
class DailyPathScreen extends ConsumerWidget {
  const DailyPathScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pair = ref.watch(defaultPairProvider);
    final dueAsync = ref.watch(dueCountForPairProvider(pair));

    return Scaffold(
      key: const ValueKey(WidgetKeys.screenDailyPath),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text('daily_path.title'.tr()),
      ),
      body: Stack(
        children: [
          const DottedGround(),
          dueAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(
                  color: AppColors.clay, strokeWidth: 2),
            ),
            error: (_, __) => _PathBody(pair: pair, dueCount: 0),
            data: (dueCount) => _PathBody(pair: pair, dueCount: dueCount),
          ),
        ],
      ),
    );
  }
}

class _PathBody extends StatelessWidget {
  const _PathBody({required this.pair, required this.dueCount});

  final (String, String) pair;
  final int dueCount;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pairName = '${Languages.displayName(pair.$1)} → '
        '${Languages.displayName(pair.$2)}';

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        Text(
          '${Languages.flagFor(pair.$1)}  $pairName',
          style: AppTextStyles.eyebrow.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        Text(
          'daily_path.headline'.tr(),
          style: AppTextStyles.grotesk(30, FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          'daily_path.optional_hint'.tr(),
          style: AppTextStyles.body.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        _PathStepCard(
          key: const ValueKey(WidgetKeys.dailyPathReview),
          index: 1,
          icon: Icons.refresh_rounded,
          title: 'daily_path.review_title'.tr(),
          subtitle: dueCount > 0
              ? 'daily_path.review_due'.tr(namedArgs: {
                  'count': '$dueCount',
                })
              : 'daily_path.review_clear'.tr(),
          buttonLabel: dueCount > 0 ? 'daily_path.review_open'.tr() : null,
          onPressed:
              dueCount > 0 ? () => _showReviewModeSheet(context, pair) : null,
        ),
        const SizedBox(height: 12),
        _PathStepCard(
          key: const ValueKey(WidgetKeys.dailyPathLessons),
          index: 2,
          icon: Icons.menu_book_rounded,
          title: 'daily_path.lessons_title'.tr(),
          subtitle: 'daily_path.lessons_subtitle'.tr(),
          buttonLabel: 'daily_path.lessons_open'.tr(),
          onPressed: () => context.push('/grammar'),
        ),
        const SizedBox(height: 12),
        _PathStepCard(
          key: const ValueKey(WidgetKeys.dailyPathPractice),
          index: 3,
          icon: Icons.style_rounded,
          title: 'daily_path.practice_title'.tr(),
          subtitle: 'daily_path.practice_subtitle'.tr(),
          buttonLabel: 'daily_path.practice_open'.tr(),
          onPressed: () => context.go('/lists'),
        ),
      ],
    );
  }

  void _showReviewModeSheet(BuildContext context, (String, String) pair) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'home.review_mode_title'.tr(),
                  style: AppTextStyles.grotesk(18, FontWeight.w700),
                ),
              ),
            ),
            for (final (mode, icon, labelKey) in [
              (
                QuizMode.voice,
                Icons.mic_rounded,
                'quiz_setup.mode_voice_label'
              ),
              (
                QuizMode.handsFree,
                Icons.headset_mic_rounded,
                'quiz_setup.mode_hands_free_label',
              ),
              (
                QuizMode.typing,
                Icons.keyboard_rounded,
                'quiz_setup.mode_typing_label',
              ),
              (
                QuizMode.flashcard,
                Icons.style_rounded,
                'quiz_setup.mode_flashcard_label',
              ),
            ])
              ListTile(
                key: ValueKey(WidgetKeys.homeReviewMode(mode.name)),
                leading: Icon(icon, size: 22),
                title: Text(labelKey.tr()),
                onTap: () {
                  Navigator.pop(sheetContext);
                  context.push(
                    '/quiz',
                    extra: QuizArgs(
                      source: QuizSource.allDue,
                      mode: mode,
                      direction: QuizDirectionChoice.both,
                      cardLimit: const int.fromEnvironment('TEST_CARD_LIMIT',
                          defaultValue: 20),
                      langA: pair.$1,
                      langB: pair.$2,
                    ),
                  );
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _PathStepCard extends StatelessWidget {
  const _PathStepCard({
    required super.key,
    required this.index,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onPressed,
  });

  final int index;
  final IconData icon;
  final String title;
  final String subtitle;
  final String? buttonLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FrostedBox(
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.clay.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child:
                Text('$index', style: AppTextStyles.fig(15, FontWeight.w700)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 19, color: AppColors.clay),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(title,
                          style: AppTextStyles.fig(16, FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(subtitle,
                    style: AppTextStyles.body
                        .copyWith(color: cs.onSurfaceVariant)),
                if (buttonLabel != null) ...[
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: onPressed,
                    child: Text(buttonLabel!),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
