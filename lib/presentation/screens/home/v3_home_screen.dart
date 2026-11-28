import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/languages.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/v3_colors.dart';
import '../../../core/widget_keys.dart';
import '../../../domain/entities/vocabulary_list.dart';
import '../../providers/auth/auth_provider.dart';
import '../../providers/grammar/grammar_provider.dart';
import '../../providers/lists/vocabulary_provider.dart';
import '../../providers/settings/default_pair_provider.dart';
import '../../widgets/v3_pond.dart';
import '../../widgets/scroll_affordance.dart';
import '../../widgets/free_practice_sheet.dart';

/// V3's signed-in landing surface: a dark-water plateau of independent
/// choices. The visual stack is a daily-work object; the curriculum itself is
/// reached through the separate "Mon parcours" entry.
class V3HomeScreen extends ConsumerWidget {
  const V3HomeScreen({super.key});

  static const _pairs = <(String, String)>[
    ('fr', 'ko'),
    ('en', 'ko'),
    ('ko', 'fr'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pair = ref.watch(defaultPairProvider);
    final user = ref.watch(currentUserProvider);
    final lists = ref.watch(myListsProvider);
    final dueProvider = dueCountForPairProvider(pair);
    final due = ref.watch(dueProvider);
    final rules =
        ref.watch(ruleStatusesProvider(pair.$2)).valueOrNull ?? const [];

    return Scaffold(
      key: const ValueKey(WidgetKeys.screenHome),
      backgroundColor: V3Colors.app,
      body: Stack(
        children: [
          const Positioned.fill(child: V3Pond()),
          SafeArea(
            child: lists.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: V3Colors.amber),
              ),
              error: (_, _) => _V3HomeBody(
                pair: pair,
                userInitial: _initial(user?.displayName ?? user?.username),
                streak: user?.currentStreak ?? 0,
                due: due,
                onRetryDue: () => ref.invalidate(dueProvider),
                lists: const [],
                rules: rules,
                onPairTap: () => _showPairPicker(context, ref, pair),
              ),
              data: (items) => _V3HomeBody(
                pair: pair,
                userInitial: _initial(user?.displayName ?? user?.username),
                streak: user?.currentStreak ?? 0,
                due: due,
                onRetryDue: () => ref.invalidate(dueProvider),
                lists: items,
                rules: rules,
                onPairTap: () => _showPairPicker(context, ref, pair),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _initial(String? name) {
    final trimmed = name?.trim() ?? '';
    return trimmed.isEmpty ? '?' : trimmed.substring(0, 1).toUpperCase();
  }

  static void _showPairPicker(
    BuildContext context,
    WidgetRef ref,
    (String, String) active,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
      builder: (sheetContext) => _V3Sheet(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SheetHandle(),
            Text(
              'v3.current_pair'.tr(),
              style: AppTextStyles.serif(
                29,
                FontWeight.w400,
                color: V3Colors.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'v3.pair_path'.tr(),
              style: AppTextStyles.fig(
                15,
                FontWeight.w400,
                color: V3Colors.ink60,
              ),
            ),
            const SizedBox(height: 16),
            for (final pair in _pairs) ...[
              _PairOption(
                pair: pair,
                selected: pair == active,
                onTap: () {
                  ref.read(defaultPairProvider.notifier).set(pair.$1, pair.$2);
                  Navigator.pop(sheetContext);
                },
              ),
              const SizedBox(height: 7),
            ],
          ],
        ),
      ),
    );
  }
}

class _V3HomeBody extends StatelessWidget {
  const _V3HomeBody({
    required this.pair,
    required this.userInitial,
    required this.streak,
    required this.due,
    required this.onRetryDue,
    required this.lists,
    required this.rules,
    required this.onPairTap,
  });

  final (String, String) pair;
  final String userInitial;
  final int streak;
  final AsyncValue<int> due;
  final VoidCallback onRetryDue;
  final List<VocabularyList> lists;
  final List<RuleStatus> rules;
  final VoidCallback onPairTap;

  @override
  Widget build(BuildContext context) {
    final pairLists = lists
        .where((list) => list.langA == pair.$1 && list.langB == pair.$2)
        .toList();
    final firstList = pairLists.isEmpty ? null : pairLists.first;
    final totalWords = pairLists.fold<int>(
      0,
      (sum, list) => sum + list.wordCount,
    );
    final lessonsRead = rules
        .where((status) => status.availability == RuleAvailability.mastered)
        .length;
    final lessonsRemaining = math.max(0, rules.length - lessonsRead);
    final dueCount = due.isLoading ? null : due.asData?.value;
    final hasDue = dueCount != null && dueCount > 0;
    final nextTitle = switch (dueCount) {
      null =>
        (due.isLoading ? 'v3.review_due_loading' : 'v3.review_due_error').tr(),
      0 => switch (firstList) {
        null => 'v3.prepare_list'.tr(),
        VocabularyList(wordCount: 0) => 'v3.add_words'.tr(),
        VocabularyList(:final name) => name,
      },
      _ => 'v3.words_due'.tr(namedArgs: {'count': '$dueCount'}),
    };
    final nextSubtitle = switch (dueCount) {
      null => null,
      0 =>
        firstList == null
            ? 'v3.few_words'.tr()
            : 'v3.list_duration'.tr(namedArgs: {'name': firstList.name}),
      _ => 'v3.resume_known'.tr(),
    };

    return ScrollAffordance(
      hint: 'v3.scroll_hint'.tr(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TopBar(
            pair: pair,
            streak: streak,
            initial: userInitial,
            onPairTap: onPairTap,
          ),
          const SizedBox(height: 16),
          _DailyEntry(
            countLabel: switch (dueCount) {
              null => null,
              0 => 'v3.one_activity'.tr(),
              _ => 'v3.words_due'.tr(namedArgs: {'count': '$dueCount'}),
            },
            title: nextTitle,
            subtitle: nextSubtitle,
            cta: (dueCount == null ? 'home.daily_path_open' : 'v3.start').tr(),
            onTap: () => context.push('/daily-path'),
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
          const SizedBox(height: 14),
          _PathEntry(
            remainingLessons: lessonsRemaining,
            firstList: firstList,
            rules: rules,
          ),
          const SizedBox(height: 10),
          _MetricGrid(
            due: dueCount,
            readLessons: lessonsRead,
            remainingLessons: lessonsRemaining,
            totalWords: totalWords,
            listCount: pairLists.length,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _SmallEntry(
                  title: 'v3.my_lists'.tr(),
                  meta: 'v3.see_words'.tr(),
                  accent: true,
                  onTap: () => context.go('/lists'),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _SmallEntry(
                  title: 'v3.choose_activity'.tr(),
                  meta: 'v3.outside_path'.tr(),
                  onTap: () => _showActivitySheet(context),
                ),
              ),
            ],
          ),
          if (dueCount != null) ...[
            const SizedBox(height: 18),
            Text(
              (hasDue ? 'v3.resume_anytime' : 'v3.nothing_due').tr(),
              textAlign: TextAlign.center,
              style: AppTextStyles.mono(
                11,
                FontWeight.w400,
                letterSpacing: 1.1,
                color: V3Colors.light60,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showActivitySheet(BuildContext context) =>
      showFreePracticeSheet(context, pair: pair);
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.pair,
    required this.streak,
    required this.initial,
    required this.onPairTap,
  });
  final (String, String) pair;
  final int streak;
  final String initial;
  final VoidCallback onPairTap;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.spaceBetween,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 12,
    runSpacing: 8,
    children: [
      TextButton(
        key: const ValueKey(WidgetKeys.homePairPicker),
        onPressed: onPairTap,
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          foregroundColor: V3Colors.light60,
        ),
        child: Text(
          '${pair.$1.toUpperCase()} → ${pair.$2.toUpperCase()}',
          style: AppTextStyles.mono(12, FontWeight.w400, letterSpacing: 1.2),
        ),
      ),
      Text(
        'v3.streak_days'.tr(namedArgs: {'count': '$streak'}),
        style: AppTextStyles.mono(
          12,
          FontWeight.w400,
          letterSpacing: .7,
          color: V3Colors.amber,
        ),
      ),
      Semantics(
        button: true,
        label: 'v3.profile'.tr(),
        child: InkWell(
          onTap: () => context.go('/profile'),
          borderRadius: BorderRadius.circular(99),
          child: Ink(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: V3Colors.chip,
            ),
            child: Center(
              child: Text(
                initial,
                style: AppTextStyles.fig(
                  12,
                  FontWeight.w700,
                  color: V3Colors.light,
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

class _DailyEntry extends StatelessWidget {
  const _DailyEntry({
    required this.countLabel,
    required this.title,
    required this.subtitle,
    required this.cta,
    required this.onTap,
  });
  final String? countLabel;
  final String title;
  final String? subtitle;
  final String cta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: V3Colors.paper2,
    borderRadius: BorderRadius.circular(15),
    child: InkWell(
      key: const ValueKey(WidgetKeys.homeDailyPath),
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(17, 15, 17, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'v3.today_label'.tr(),
                  style: AppTextStyles.mono(
                    12,
                    FontWeight.w700,
                    letterSpacing: 1.1,
                    color: V3Colors.terraInk,
                  ),
                ),
                if (countLabel case final label?)
                  Text(
                    label,
                    style: AppTextStyles.mono(
                      11,
                      FontWeight.w400,
                      color: V3Colors.ink60,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: AppTextStyles.serif(
                30,
                FontWeight.w400,
                color: V3Colors.ink,
              ),
            ),
            if (subtitle case final detail?) ...[
              const SizedBox(height: 4),
              Text(
                detail,
                style: AppTextStyles.fig(
                  14.5,
                  FontWeight.w400,
                  color: V3Colors.ink60,
                ),
              ),
            ],
            const SizedBox(height: 13),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: V3Colors.terra,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Text(
                cta,
                textAlign: TextAlign.center,
                style: AppTextStyles.fig(
                  15.5,
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

class _PathEntry extends StatelessWidget {
  const _PathEntry({
    required this.remainingLessons,
    required this.firstList,
    required this.rules,
  });
  final int remainingLessons;
  final VocabularyList? firstList;
  final List<RuleStatus> rules;

  @override
  Widget build(BuildContext context) => Material(
    color: V3Colors.block,
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      key: const ValueKey(WidgetKeys.homeGrammar),
      onTap: () => _showPath(context),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'v3.path_label'.tr(),
                    style: AppTextStyles.mono(
                      12,
                      FontWeight.w400,
                      letterSpacing: 1.1,
                      color: V3Colors.light60,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'v3.lessons_remaining'.tr(
                      namedArgs: {'count': '$remainingLessons'},
                    ),
                    textAlign: TextAlign.end,
                    style: AppTextStyles.mono(
                      11,
                      FontWeight.w400,
                      color: V3Colors.light60,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'course.level_one'.tr(),
                        style: AppTextStyles.serif(
                          21,
                          FontWeight.w400,
                          color: V3Colors.light,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        firstList == null
                            ? 'v3.prepare_words'.tr()
                            : 'v3.current_list'.tr(
                                namedArgs: {'name': firstList!.name},
                              ),
                        style: AppTextStyles.fig(
                          13,
                          FontWeight.w400,
                          color: V3Colors.light70,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  'v3.see'.tr(),
                  style: AppTextStyles.fig(
                    15,
                    FontWeight.w700,
                    color: V3Colors.amber,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  void _showPath(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
      builder: (sheetContext) => _V3Sheet(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SheetHandle(),
            Text(
              'v3.path_title'.tr(),
              style: AppTextStyles.serif(
                29,
                FontWeight.w400,
                color: V3Colors.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'v3.path_body'.tr(),
              style: AppTextStyles.fig(
                15,
                FontWeight.w400,
                color: V3Colors.ink60,
              ),
            ),
            const SizedBox(height: 17),
            _SheetChoice(
              label: firstList == null
                  ? 'v3.create_list'.tr()
                  : 'v3.resume_list'.tr(namedArgs: {'name': firstList!.name}),
              onTap: () {
                Navigator.pop(sheetContext);
                firstList == null
                    ? context.go('/lists')
                    : context.push('/lists/${firstList!.id}');
              },
            ),
            const SizedBox(height: 7),
            _SheetChoice(
              label: rules.isEmpty
                  ? 'v3.see_lessons'.tr()
                  : 'v3.see_lessons_count'.tr(
                      namedArgs: {'count': '${rules.length}'},
                    ),
              onTap: () {
                Navigator.pop(sheetContext);
                context.push('/grammar');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({
    required this.due,
    required this.readLessons,
    required this.remainingLessons,
    required this.totalWords,
    required this.listCount,
  });
  final int? due;
  final int readLessons;
  final int remainingLessons;
  final int totalWords;
  final int listCount;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final largeText = MediaQuery.textScalerOf(context).scale(14) > 20;
      final width = largeText
          ? constraints.maxWidth
          : (constraints.maxWidth - 9) / 2;
      final count = due;
      final metrics = [
        _Metric(
          value: count?.toString() ?? '—',
          title: 'v3.words_due_title'.tr(),
          meta: switch (count) {
            null => null,
            0 => 'v3.nothing_due_label'.tr(),
            _ => 'v3.resume_label'.tr(),
          },
          amber: count != null && count > 0,
        ),
        _Metric(
          value: '$readLessons',
          title: 'v3.lessons_read'.tr(),
          meta: 'v3.to_discover'.tr(namedArgs: {'count': '$remainingLessons'}),
        ),
        _Metric(
          value: '$totalWords',
          title: 'v3.words_in_lists'.tr(),
          meta: 'v3.at_your_pace'.tr(),
        ),
        _Metric(
          value: '$listCount',
          title: 'v3.available_lists'.tr(),
          meta: 'v3.building'.tr(),
        ),
      ];
      return Wrap(
        spacing: 9,
        runSpacing: 9,
        children: [
          for (final metric in metrics) SizedBox(width: width, child: metric),
        ],
      );
    },
  );
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.value,
    required this.title,
    required this.meta,
    this.amber = false,
  });
  final String value;
  final String title;
  final String? meta;
  final bool amber;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: V3Colors.block2,
      borderRadius: BorderRadius.circular(13),
    ),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: AppTextStyles.serif(
              25,
              FontWeight.w400,
              color: V3Colors.light,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            title,
            style: AppTextStyles.fig(
              13.5,
              FontWeight.w600,
              color: V3Colors.light,
            ),
          ),
          if (meta case final detail?) ...[
            const SizedBox(height: 2),
            Text(
              detail,
              style: AppTextStyles.mono(
                10.5,
                FontWeight.w400,
                letterSpacing: .5,
                color: amber ? V3Colors.amber : V3Colors.light60,
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class _SmallEntry extends StatelessWidget {
  const _SmallEntry({
    required this.title,
    required this.meta,
    required this.onTap,
    this.accent = false,
  });
  final String title;
  final String meta;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) => Material(
    color: accent ? V3Colors.chip2 : V3Colors.block2,
    borderRadius: BorderRadius.circular(13),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.fig(
                      13.5,
                      FontWeight.w600,
                      color: V3Colors.light,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    meta,
                    style: AppTextStyles.mono(
                      9.5,
                      FontWeight.w400,
                      letterSpacing: .35,
                      color: accent ? V3Colors.amber : V3Colors.light60,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '›',
              style: TextStyle(
                fontSize: 19,
                color: accent ? V3Colors.amber : V3Colors.light60,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _V3Sheet extends StatelessWidget {
  const _V3Sheet({required this.child});
  final Widget child;

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
          child: child,
        ),
      ),
    ),
  );
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();
  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 42,
      height: 4,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFD3CBB6),
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );
}

class _PairOption extends StatelessWidget {
  const _PairOption({
    required this.pair,
    required this.selected,
    required this.onTap,
  });
  final (String, String) pair;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => _SheetChoice(
    key: ValueKey(WidgetKeys.homePair(pair.$1, pair.$2)),
    label:
        '${Languages.flagFor(pair.$1)}  ${Languages.autonym(pair.$1)} → ${Languages.autonym(pair.$2)}',
    selected: selected,
    onTap: onTap,
  );
}

class _SheetChoice extends StatelessWidget {
  const _SheetChoice({
    super.key,
    required this.label,
    required this.onTap,
    this.selected = false,
  });
  final String label;
  final VoidCallback onTap;
  final bool selected;
  @override
  Widget build(BuildContext context) => Material(
    color: selected ? V3Colors.terra : V3Colors.paper3,
    borderRadius: BorderRadius.circular(11),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.fig(
                  14.5,
                  FontWeight.w600,
                  color: selected ? V3Colors.paper : V3Colors.ink,
                ),
              ),
            ),
            if (selected)
              const Icon(Icons.check_rounded, color: V3Colors.paper, size: 18),
          ],
        ),
      ),
    ),
  );
}
