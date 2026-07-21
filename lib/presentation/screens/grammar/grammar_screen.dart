import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/list_mastery.dart' show kListKnownThreshold;
import '../../../core/widget_keys.dart';
import '../../providers/grammar/grammar_provider.dart';
import '../../widgets/dotted_ground.dart';
import '../../widgets/frosted_box.dart';

/// Dedicated grammar hub (user decision 2026-07-21): every lesson with its
/// unlock/mastery progress. Locked rules show HOW to unlock them — an overall
/// bar plus per-prerequisite-list mastery bars; unlocked rules show their
/// mastery progress and start the existing grammar session setup.
class GrammarScreen extends ConsumerWidget {
  const GrammarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusesAsync = ref.watch(ruleStatusesProvider);
    return Scaffold(
      key: const ValueKey(WidgetKeys.screenGrammar),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text('grammar.screen_title'.tr()),
      ),
      body: Stack(
        children: [
          const DottedGround(),
          statusesAsync.when(
            loading: () => const Center(
              child:
                  CircularProgressIndicator(color: AppColors.clay, strokeWidth: 2),
            ),
            error: (_, __) => Center(child: Text('common.error'.tr())),
            data: (statuses) => ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                for (final s in statuses) ...[
                  _RuleCard(status: s),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RuleCard extends StatelessWidget {
  const _RuleCard({required this.status});
  final RuleStatus status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final muted = cs.onSurfaceVariant;
    final locked = status.availability == RuleAvailability.locked;
    final mastered = status.availability == RuleAvailability.mastered;

    return FrostedBox(
      key: ValueKey(WidgetKeys.grammarRuleCard(status.rule.id)),
      borderRadius: BorderRadius.circular(18),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                mastered
                    ? Icons.verified_rounded
                    : locked
                        ? Icons.lock_outline_rounded
                        : Icons.lock_open_rounded,
                size: 18,
                color: mastered
                    ? AppColors.teal
                    : locked
                        ? muted
                        : AppColors.clay,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(status.rule.titleFr,
                    style: AppTextStyles.fig(16, FontWeight.w700)),
              ),
              Text(
                (mastered
                        ? 'grammar.status_mastered'
                        : locked
                            ? 'grammar.status_locked'
                            : 'grammar.status_unlocked')
                    .tr(),
                style: AppTextStyles.caption.copyWith(color: muted),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (locked) ...[
            // Overall unlock progress, then how each prerequisite list is
            // doing — the "what do I need to do" answer at a glance.
            _Bar(
              label: 'grammar.unlock_progress'.tr(),
              fraction: status.unlockFraction,
              color: muted,
            ),
            const SizedBox(height: 10),
            for (final name in status.rule.prerequisiteLists) ...[
              _Bar(
                label: name,
                fraction: ((status.prereqProgress[name] ?? 0) /
                        kListKnownThreshold)
                    .clamp(0.0, 1.0),
                color: AppColors.clay,
                dense: true,
              ),
              const SizedBox(height: 6),
            ],
          ] else ...[
            _Bar(
              label: 'grammar.mastery_progress'.tr(namedArgs: {
                'correct': status.correct.toString(),
                'target': ruleMasteryTarget.toString(),
              }),
              fraction:
                  (status.correct / ruleMasteryTarget).clamp(0.0, 1.0),
              color: mastered ? AppColors.teal : AppColors.clay,
            ),
            if (!mastered) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  key: ValueKey(WidgetKeys.grammarRuleStart(status.rule.id)),
                  onPressed: () => context.push('/start-session-grammar'),
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: Text('grammar.start_cta'.tr()),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.label,
    required this.fraction,
    required this.color,
    this.dense = false,
  });
  final String label;
  final double fraction;
  final Color color;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pct = (fraction * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label,
                  overflow: TextOverflow.ellipsis,
                  style: dense
                      ? AppTextStyles.caption
                          .copyWith(color: cs.onSurfaceVariant)
                      : AppTextStyles.fig(13, FontWeight.w600)),
            ),
            Text('$pct%',
                style:
                    AppTextStyles.caption.copyWith(color: cs.onSurfaceVariant)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: dense ? 4 : 6,
            backgroundColor: cs.outline.withValues(alpha: 0.25),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}
