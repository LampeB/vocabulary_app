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
    final due = ref.watch(dueCountForPairProvider(pair)).valueOrNull ?? 0;
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
              error: (_, __) => _V3HomeBody(
                pair: pair,
                userInitial: _initial(user?.displayName ?? user?.username),
                streak: user?.currentStreak ?? 0,
                dueCount: due,
                lists: const [],
                rules: rules,
                onPairTap: () => _showPairPicker(context, ref, pair),
              ),
              data: (items) => _V3HomeBody(
                pair: pair,
                userInitial: _initial(user?.displayName ?? user?.username),
                streak: user?.currentStreak ?? 0,
                dueCount: due,
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
            Text('v3.current_pair'.tr(),
                style: AppTextStyles.serif(29, FontWeight.w400)),
            const SizedBox(height: 6),
            Text('v3.pair_path'.tr(),
                style: AppTextStyles.fig(15, FontWeight.w400,
                    color: V3Colors.ink60)),
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
    required this.dueCount,
    required this.lists,
    required this.rules,
    required this.onPairTap,
  });

  final (String, String) pair;
  final String userInitial;
  final int streak;
  final int dueCount;
  final List<VocabularyList> lists;
  final List<RuleStatus> rules;
  final VoidCallback onPairTap;

  @override
  Widget build(BuildContext context) {
    final pairLists = lists
        .where((list) => list.langA == pair.$1 && list.langB == pair.$2)
        .toList();
    final firstList = pairLists.isEmpty ? null : pairLists.first;
    final totalWords =
        pairLists.fold<int>(0, (sum, list) => sum + list.wordCount);
    final lessonsRead = rules
        .where((status) => status.availability == RuleAvailability.mastered)
        .length;
    final lessonsRemaining = math.max(0, rules.length - lessonsRead);
    final nextTitle = dueCount > 0
        ? 'v3.words_due'.tr(namedArgs: {'count': '$dueCount'})
        : firstList == null
            ? 'v3.prepare_list'.tr()
            : firstList.wordCount == 0
                ? 'v3.add_words'.tr()
                : firstList.name;
    final nextSubtitle = dueCount > 0
        ? 'v3.resume_known'.tr()
        : firstList == null
            ? 'v3.few_words'.tr()
            : 'v3.list_duration'.tr(namedArgs: {'name': firstList.name});

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
              onPairTap: onPairTap),
          const SizedBox(height: 16),
          _DailyEntry(
            countLabel: dueCount > 0
                ? 'v3.words_due'.tr(namedArgs: {'count': '$dueCount'})
                : 'v3.one_activity'.tr(),
            title: nextTitle,
            subtitle: nextSubtitle,
            onTap: () => context.push('/daily-path'),
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
          const SizedBox(height: 18),
          Text(
            dueCount > 0 ? 'v3.resume_anytime'.tr() : 'v3.nothing_due'.tr(),
            textAlign: TextAlign.center,
            style: AppTextStyles.mono(11, FontWeight.w400,
                letterSpacing: 1.1, color: V3Colors.light60),
          ),
        ],
      ),
    );
  }

  void _showActivitySheet(BuildContext context) {
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
            Text('v3.activity_title'.tr(),
                style: AppTextStyles.serif(29, FontWeight.w400)),
            const SizedBox(height: 6),
            Text('v3.activity_body'.tr(),
                style: AppTextStyles.fig(15, FontWeight.w400,
                    color: V3Colors.ink60)),
            const SizedBox(height: 17),
            Text('v3.activity_label'.tr(),
                style: AppTextStyles.mono(12, FontWeight.w700,
                    letterSpacing: 1.2, color: V3Colors.ink60)),
            const SizedBox(height: 9),
            _SheetChoice(
                label: 'v3.a_list'.tr(),
                onTap: () {
                  Navigator.pop(sheetContext);
                  context.go('/lists');
                }),
            const SizedBox(height: 7),
            _SheetChoice(
                label: 'v3.a_lesson'.tr(),
                onTap: () {
                  Navigator.pop(sheetContext);
                  context.go('/grammar');
                }),
            const SizedBox(height: 7),
            _SheetChoice(
                label: 'v3.choose_quiz'.tr(),
                onTap: () {
                  Navigator.pop(sheetContext);
                  context.go('/start-session');
                }),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar(
      {required this.pair,
      required this.streak,
      required this.initial,
      required this.onPairTap});
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
                  padding: EdgeInsets.zero, foregroundColor: V3Colors.light60),
              child: Text('${pair.$1.toUpperCase()} → ${pair.$2.toUpperCase()}',
                  style: AppTextStyles.mono(12, FontWeight.w400,
                      letterSpacing: 1.2)),
            ),
            Text('v3.streak_days'.tr(namedArgs: {'count': '$streak'}),
                style: AppTextStyles.mono(12, FontWeight.w400,
                    letterSpacing: .7, color: V3Colors.amber)),
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
                        shape: BoxShape.circle, color: V3Colors.chip),
                    child: Center(
                        child: Text(initial,
                            style: AppTextStyles.fig(12, FontWeight.w700,
                                color: V3Colors.light))),
                  ),
                )),
          ]);
}

class _DailyEntry extends StatelessWidget {
  const _DailyEntry(
      {required this.countLabel,
      required this.title,
      required this.subtitle,
      required this.onTap});
  final String countLabel;
  final String title;
  final String subtitle;
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
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('v3.today_label'.tr(),
                    style: AppTextStyles.mono(12, FontWeight.w700,
                        letterSpacing: 1.1, color: V3Colors.terraInk)),
                Text(countLabel,
                    style: AppTextStyles.mono(11, FontWeight.w400,
                        color: V3Colors.ink60)),
              ]),
              const SizedBox(height: 8),
              Text(title,
                  style: AppTextStyles.serif(30, FontWeight.w400,
                      color: V3Colors.ink)),
              const SizedBox(height: 4),
              Text(subtitle,
                  style: AppTextStyles.fig(14.5, FontWeight.w400,
                      color: V3Colors.ink60)),
              const SizedBox(height: 13),
              Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                      color: V3Colors.terra,
                      borderRadius: BorderRadius.circular(11)),
                  child: Text('v3.start'.tr(),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.fig(15.5, FontWeight.w700,
                          color: V3Colors.paper))),
            ]),
          ),
        ),
      );
}

class _PathEntry extends StatelessWidget {
  const _PathEntry(
      {required this.remainingLessons,
      required this.firstList,
      required this.rules});
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
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                    child: Text('v3.path_label'.tr(),
                        style: AppTextStyles.mono(12, FontWeight.w400,
                            letterSpacing: 1.1, color: V3Colors.light60))),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                      'v3.lessons_remaining'
                          .tr(namedArgs: {'count': '$remainingLessons'}),
                      textAlign: TextAlign.end,
                      style: AppTextStyles.mono(11, FontWeight.w400,
                          color: V3Colors.light60)),
                ),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('course.level_one'.tr(),
                          style: AppTextStyles.serif(21, FontWeight.w400,
                              color: V3Colors.light)),
                      const SizedBox(height: 2),
                      Text(
                          firstList == null
                              ? 'v3.prepare_words'.tr()
                              : 'v3.current_list'
                                  .tr(namedArgs: {'name': firstList!.name}),
                          style: AppTextStyles.fig(13, FontWeight.w400,
                              color: V3Colors.light70)),
                    ])),
                Text('v3.see'.tr(),
                    style: AppTextStyles.fig(15, FontWeight.w700,
                        color: V3Colors.amber)),
              ]),
            ]),
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
              Text('v3.path_title'.tr(),
                  style: AppTextStyles.serif(29, FontWeight.w400)),
              const SizedBox(height: 6),
              Text('v3.path_body'.tr(),
                  style: AppTextStyles.fig(15, FontWeight.w400,
                      color: V3Colors.ink60)),
              const SizedBox(height: 17),
              _SheetChoice(
                  label: firstList == null
                      ? 'v3.create_list'.tr()
                      : 'v3.resume_list'
                          .tr(namedArgs: {'name': firstList!.name}),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    firstList == null
                        ? context.go('/lists')
                        : context.push('/lists/${firstList!.id}');
                  }),
              const SizedBox(height: 7),
              _SheetChoice(
                  label: rules.isEmpty
                      ? 'v3.see_lessons'.tr()
                      : 'v3.see_lessons_count'
                          .tr(namedArgs: {'count': '${rules.length}'}),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    context.go('/grammar');
                  }),
            ]),
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid(
      {required this.due,
      required this.readLessons,
      required this.remainingLessons,
      required this.totalWords,
      required this.listCount});
  final int due;
  final int readLessons;
  final int remainingLessons;
  final int totalWords;
  final int listCount;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final largeText = MediaQuery.textScalerOf(context).scale(14) > 20;
          final width =
              largeText ? constraints.maxWidth : (constraints.maxWidth - 9) / 2;
          final metrics = [
            _Metric(
                value: '$due',
                title: 'v3.words_due_title'.tr(),
                meta: due > 0
                    ? 'v3.resume_label'.tr()
                    : 'v3.nothing_due_label'.tr(),
                amber: due > 0),
            _Metric(
                value: '$readLessons',
                title: 'v3.lessons_read'.tr(),
                meta: 'v3.to_discover'
                    .tr(namedArgs: {'count': '$remainingLessons'})),
            _Metric(
                value: '$totalWords',
                title: 'v3.words_in_lists'.tr(),
                meta: 'v3.at_your_pace'.tr()),
            _Metric(
                value: '$listCount',
                title: 'v3.available_lists'.tr(),
                meta: 'v3.building'.tr()),
          ];
          return Wrap(
            spacing: 9,
            runSpacing: 9,
            children: [
              for (final metric in metrics)
                SizedBox(width: width, child: metric),
            ],
          );
        },
      );
}

class _Metric extends StatelessWidget {
  const _Metric(
      {required this.value,
      required this.title,
      required this.meta,
      this.amber = false});
  final String value;
  final String title;
  final String meta;
  final bool amber;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
            color: V3Colors.block2, borderRadius: BorderRadius.circular(13)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value,
                    style: AppTextStyles.serif(25, FontWeight.w400,
                        color: V3Colors.light)),
                const SizedBox(height: 3),
                Text(title,
                    style: AppTextStyles.fig(13.5, FontWeight.w600,
                        color: V3Colors.light)),
                const SizedBox(height: 2),
                Text(meta,
                    style: AppTextStyles.mono(10.5, FontWeight.w400,
                        letterSpacing: .5,
                        color: amber ? V3Colors.amber : V3Colors.light60)),
              ]),
        ),
      );
}

class _SmallEntry extends StatelessWidget {
  const _SmallEntry(
      {required this.title,
      required this.meta,
      required this.onTap,
      this.accent = false});
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
            child: Row(children: [
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(title,
                        style: AppTextStyles.fig(13.5, FontWeight.w600,
                            color: V3Colors.light)),
                    const SizedBox(height: 3),
                    Text(meta,
                        style: AppTextStyles.mono(9.5, FontWeight.w400,
                            letterSpacing: .35,
                            color: accent ? V3Colors.amber : V3Colors.light60)),
                  ])),
              Text('›',
                  style: TextStyle(
                      fontSize: 19,
                      color: accent ? V3Colors.amber : V3Colors.light60)),
            ]),
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
          child: SingleChildScrollView(
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
                      offset: Offset(0, -12))
                ]),
            child: child,
          )),
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
              borderRadius: BorderRadius.circular(2))));
}

class _PairOption extends StatelessWidget {
  const _PairOption(
      {required this.pair, required this.selected, required this.onTap});
  final (String, String) pair;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => _SheetChoice(
        label:
            '${Languages.flagFor(pair.$1)}  ${Languages.displayName(pair.$1)} → ${Languages.displayName(pair.$2)}',
        selected: selected,
        onTap: onTap,
      );
}

class _SheetChoice extends StatelessWidget {
  const _SheetChoice(
      {required this.label, required this.onTap, this.selected = false});
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
            child: Row(children: [
              Expanded(
                  child: Text(label,
                      style: AppTextStyles.fig(14.5, FontWeight.w600,
                          color: selected ? V3Colors.paper : V3Colors.ink))),
              if (selected)
                const Icon(Icons.check_rounded,
                    color: V3Colors.paper, size: 18),
            ]),
          ),
        ),
      );
}
