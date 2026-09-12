import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/languages.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widget_keys.dart';
import '../../../domain/entities/vocabulary_list.dart';
import '../../providers/auth/auth_provider.dart';
import '../../providers/grammar/grammar_provider.dart';
import '../../providers/lists/vocabulary_provider.dart';
import '../../providers/settings/default_pair_provider.dart';
import '../../widgets/dotted_ground.dart';

/// V0's signed-in landing screen.
///
/// This is deliberately a route, not a dashboard of unrelated cards: it is
/// the first vertical slice of the production mockup. It points a new learner
/// to today's next action, then to the exact prerequisite vocabulary that
/// opens the first lesson. Free practice remains an explicit side entrance.
class ParcoursScreen extends ConsumerWidget {
  const ParcoursScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pair = ref.watch(defaultPairProvider);
    final user = ref.watch(currentUserProvider);
    final lists = ref.watch(myListsProvider);
    final due = ref.watch(dueCountForPairProvider(pair)).valueOrNull ?? 0;
    final rules = ref.watch(ruleStatusesProvider(pair.$2));

    return Scaffold(
      key: const ValueKey(WidgetKeys.screenHome),
      body: Stack(
        children: [
          const DottedGround(),
          SafeArea(
            child: lists.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.clay),
              ),
              error: (_, __) => _PathBody(
                pair: pair,
                userInitial:
                    _initial(user?.displayName ?? user?.username ?? ''),
                dueCount: due,
                lists: const [],
                statuses: rules.valueOrNull ?? const [],
              ),
              data: (items) => _PathBody(
                pair: pair,
                userInitial:
                    _initial(user?.displayName ?? user?.username ?? ''),
                dueCount: due,
                lists: items,
                statuses: rules.valueOrNull ?? const [],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _initial(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? '?' : trimmed.substring(0, 1).toUpperCase();
  }
}

class _PathBody extends StatelessWidget {
  const _PathBody({
    required this.pair,
    required this.userInitial,
    required this.dueCount,
    required this.lists,
    required this.statuses,
  });

  final (String, String) pair;
  final String userInitial;
  final int dueCount;
  final List<VocabularyList> lists;
  final List<RuleStatus> statuses;

  @override
  Widget build(BuildContext context) {
    final matching =
        lists.where((list) => list.langA == pair.$1 && list.langB == pair.$2);
    final firstList = matching.isEmpty
        ? (lists.isEmpty ? null : lists.first)
        : matching.first;
    final unlocked = statuses
        .where((status) => status.availability != RuleAvailability.locked)
        .length;
    final firstRule = statuses.isEmpty ? null : statuses.first;
    final lessonsDone = statuses
        .where((status) => status.availability == RuleAvailability.mastered)
        .length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        _TopLine(pair: pair, initial: userInitial),
        const SizedBox(height: 28),
        _DailyHero(
          dueCount: dueCount,
          hasPrerequisite: firstList != null,
          onOpen: () => context.push('/daily-path'),
        ),
        const SizedBox(height: 24),
        _ProgressLine(
          lessonsDone: lessonsDone,
          lessonsTotal: statuses.length,
          nodesDone: unlocked > 0 ? 1 : 0,
        ),
        const SizedBox(height: 28),
        Text('course.route'.tr(), style: AppTextStyles.eyebrow),
        const SizedBox(height: 12),
        _RoutePanel(
          prerequisite: firstList,
          firstRule: firstRule,
          lessonsDone: lessonsDone,
          lessonsTotal: statuses.length,
          onOpenList: firstList == null
              ? () => context.go('/lists')
              : () => context.push('/lists/${firstList.id}'),
          onOpenLessons: () => context.go('/grammar'),
        ),
        const SizedBox(height: 22),
        OutlinedButton.icon(
          onPressed: () => context.go('/start-session'),
          icon: const Icon(Icons.casino_outlined, size: 20),
          label: Text('course.free_practice'.tr()),
        ),
      ],
    );
  }
}

class _TopLine extends StatelessWidget {
  const _TopLine({required this.pair, required this.initial});
  final (String, String) pair;
  final String initial;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: AppColors.line),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 11),
              child: Text(
                '${Languages.flagFor(pair.$1)} ${pair.$1.toUpperCase()} ↔ ${pair.$2.toUpperCase()}',
                style: AppTextStyles.fig(15, FontWeight.w700),
              ),
            ),
          ),
          const Spacer(),
          const Icon(Icons.local_fire_department_rounded,
              color: AppColors.clay),
          const SizedBox(width: 4),
          Text('0', style: AppTextStyles.fig(18, FontWeight.w800)),
          const SizedBox(width: 14),
          CircleAvatar(
            radius: 23,
            backgroundColor: AppColors.teal,
            child: Text(initial,
                style: AppTextStyles.fig(18, FontWeight.w800)
                    .copyWith(color: Colors.white)),
          ),
        ],
      );
}

class _DailyHero extends StatelessWidget {
  const _DailyHero({
    required this.dueCount,
    required this.hasPrerequisite,
    required this.onOpen,
  });
  final int dueCount;
  final bool hasPrerequisite;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final next = dueCount > 0
        ? 'course.step_review'.tr()
        : hasPrerequisite
            ? 'course.step_discover'.tr()
            : 'course.step_setup'.tr();
    return Material(
      color: const Color(0xFF2E2823),
      borderRadius: BorderRadius.circular(34),
      child: InkWell(
        key: const ValueKey(WidgetKeys.homeDailyPath),
        borderRadius: BorderRadius.circular(34),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('course.daily_path'.tr(),
                  style: AppTextStyles.eyebrow
                      .copyWith(color: const Color(0xFFE8D6BF))),
              const SizedBox(height: 22),
              Row(children: [
                Expanded(
                  child: _HeroStep(
                      Icons.refresh_rounded, 'course.step_review'.tr(),
                      done: dueCount == 0),
                ),
                Expanded(
                  child: _HeroStep(
                      Icons.add_rounded, 'course.step_discover'.tr(),
                      active: dueCount == 0),
                ),
                Expanded(
                  child: _HeroStep(
                      Icons.menu_book_outlined, 'course.step_lesson'.tr()),
                ),
                Expanded(
                  child:
                      _HeroStep(Icons.adjust_rounded, 'course.step_drill'.tr()),
                ),
              ]),
              const Divider(height: 30, color: Color(0xFF51483F)),
              Row(
                children: [
                  Expanded(
                    child: Text(next,
                        style: AppTextStyles.fig(17, FontWeight.w700)
                            .copyWith(color: const Color(0xFFF6F1EA))),
                  ),
                  Text('course.continue'.tr(),
                      style: AppTextStyles.fig(16, FontWeight.w800)
                          .copyWith(color: AppColors.clayLight)),
                  const Icon(Icons.chevron_right_rounded,
                      color: AppColors.clayLight),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroStep extends StatelessWidget {
  const _HeroStep(this.icon, this.label,
      {this.done = false, this.active = false});
  final IconData icon;
  final String label;
  final bool done;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = done
        ? AppColors.tealLight
        : active
            ? AppColors.clayLight
            : const Color(0xFF8E8478);
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 3)),
          child: Icon(done ? Icons.check_rounded : icon, color: color),
        ),
        const SizedBox(height: 7),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(label,
              style: AppTextStyles.caption
                  .copyWith(color: const Color(0xFFE8D6BF))),
        ),
      ],
    );
  }
}

class _ProgressLine extends StatelessWidget {
  const _ProgressLine(
      {required this.lessonsDone,
      required this.lessonsTotal,
      required this.nodesDone});
  final int lessonsDone;
  final int lessonsTotal;
  final int nodesDone;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 18,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('course.level_one'.tr(),
              style: AppTextStyles.fig(20, FontWeight.w800)),
          Text(
              'course.lessons_count'.tr(namedArgs: {
                'done': '$lessonsDone',
                'total': '$lessonsTotal'
              }),
              style: AppTextStyles.fig(15, FontWeight.w700)
                  .copyWith(color: AppColors.muted)),
          Text(
              'course.nodes_count'
                  .tr(namedArgs: {'done': '$nodesDone', 'total': '1'}),
              style: AppTextStyles.fig(15, FontWeight.w700)
                  .copyWith(color: AppColors.muted)),
        ],
      );
}

class _RoutePanel extends StatelessWidget {
  const _RoutePanel({
    required this.prerequisite,
    required this.firstRule,
    required this.lessonsDone,
    required this.lessonsTotal,
    required this.onOpenList,
    required this.onOpenLessons,
  });
  final VocabularyList? prerequisite;
  final RuleStatus? firstRule;
  final int lessonsDone;
  final int lessonsTotal;
  final VoidCallback onOpenList;
  final VoidCallback onOpenLessons;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.line),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              _RouteNode(
                icon: Icons.menu_book_outlined,
                color: AppColors.clay,
                title: 'course.prerequisite'.tr(),
                subtitle: prerequisite == null
                    ? 'course.no_list'.tr()
                    : prerequisite!.name,
                active: true,
                onTap: onOpenList,
              ),
              _Connector(active: prerequisite != null),
              _RouteNode(
                icon: firstRule?.availability == RuleAvailability.locked
                    ? Icons.lock_outline_rounded
                    : Icons.menu_book_rounded,
                color: firstRule?.availability == RuleAvailability.locked
                    ? AppColors.faint
                    : AppColors.teal,
                title: 'course.lessons'.tr(),
                subtitle: firstRule == null
                    ? 'grammar.no_curriculum'.tr()
                    : firstRule!.availability == RuleAvailability.locked
                        ? 'course.lessons_hint'.tr()
                        : firstRule!.rule.title(
                            Localizations.localeOf(context).languageCode),
                onTap: onOpenLessons,
              ),
              _Connector(active: false),
              _RouteNode(
                icon: Icons.casino_outlined,
                color: AppColors.faint,
                title: 'course.step_drill'.tr(),
                subtitle: 'course.drill_hint'.tr(),
              ),
            ],
          ),
        ),
      );
}

class _Connector extends StatelessWidget {
  const _Connector({required this.active});
  final bool active;
  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(left: 47),
          width: 5,
          height: 20,
          color: active ? AppColors.clayLight : AppColors.line,
        ),
      );
}

class _RouteNode extends StatelessWidget {
  const _RouteNode({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.active = false,
    this.onTap,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active
                      ? color.withValues(alpha: 0.10)
                      : Colors.transparent,
                  border: Border.all(color: color, width: 3),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: AppTextStyles.fig(18, FontWeight.w800)),
                      const SizedBox(height: 3),
                      Text(subtitle,
                          style: AppTextStyles.body
                              .copyWith(color: AppColors.muted)),
                    ]),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right_rounded, color: color),
            ],
          ),
        ),
      );
}
