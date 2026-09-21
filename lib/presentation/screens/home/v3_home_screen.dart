import 'dart:math' as math;

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
            Text('Ta langue du moment',
                style: AppTextStyles.serif(29, FontWeight.w400)),
            const SizedBox(height: 6),
            Text('Chaque paire garde son propre parcours.',
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
        ? '$dueCount ${dueCount == 1 ? 'mot à revoir' : 'mots à revoir'}'
        : firstList == null
            ? 'Préparer ta première liste'
            : '${math.min(7, math.max(1, firstList.wordCount))} mots à découvrir';
    final nextSubtitle = dueCount > 0
        ? 'Reprendre ce que tu as déjà rencontré'
        : firstList == null
            ? 'Quelques mots suffisent pour commencer'
            : 'Liste «\u202f${firstList.name}\u202f» · environ 4 minutes';

    return SingleChildScrollView(
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
          _DailyStack(
            countLabel:
                dueCount > 0 ? '$dueCount MOTS À REVOIR' : '1 ACTIVITÉ À FAIRE',
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
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _SmallEntry(
                  title: 'Mes listes',
                  meta: 'VOIR MES MOTS',
                  accent: true,
                  onTap: () => context.go('/lists'),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _SmallEntry(
                  title: 'Choisir une activité',
                  meta: 'EN DEHORS DU PARCOURS',
                  onTap: () => _showActivitySheet(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            dueCount > 0
                ? 'À reprendre quand tu veux'
                : 'Rien à rattraper aujourd’hui',
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
            Text('Que veux-tu faire\u202f?',
                style: AppTextStyles.serif(29, FontWeight.w400)),
            const SizedBox(height: 6),
            Text(
                'Choisis ce que tu veux travailler. Ton parcours reste tel quel.',
                style: AppTextStyles.fig(15, FontWeight.w400,
                    color: V3Colors.ink60)),
            const SizedBox(height: 17),
            Text('CHOISIR UNE ACTIVITÉ',
                style: AppTextStyles.mono(12, FontWeight.w700,
                    letterSpacing: 1.2, color: V3Colors.ink60)),
            const SizedBox(height: 9),
            _SheetChoice(
                label: 'Une liste',
                onTap: () {
                  Navigator.pop(sheetContext);
                  context.go('/lists');
                }),
            const SizedBox(height: 7),
            _SheetChoice(
                label: 'Une leçon',
                onTap: () {
                  Navigator.pop(sheetContext);
                  context.go('/grammar');
                }),
            const SizedBox(height: 7),
            _SheetChoice(
                label: 'Choisir un quiz',
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
  Widget build(BuildContext context) => Row(children: [
        TextButton(
          key: const ValueKey(WidgetKeys.homePairPicker),
          onPressed: onPairTap,
          style: TextButton.styleFrom(
              padding: EdgeInsets.zero, foregroundColor: V3Colors.light60),
          child: Text('${pair.$1.toUpperCase()} → ${pair.$2.toUpperCase()}',
              style:
                  AppTextStyles.mono(12, FontWeight.w400, letterSpacing: 1.2)),
        ),
        const Spacer(),
        Text('$streak JOUR${streak == 1 ? '' : 'S'}',
            style: AppTextStyles.mono(12, FontWeight.w400,
                letterSpacing: .7, color: V3Colors.amber)),
        const SizedBox(width: 12),
        InkWell(
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
        ),
      ]);
}

class _DailyStack extends StatelessWidget {
  const _DailyStack(
      {required this.countLabel,
      required this.title,
      required this.subtitle,
      required this.onTap});
  final String countLabel;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
              left: 7,
              right: 7,
              top: -7,
              height: 30,
              child: DecoratedBox(
                  decoration: BoxDecoration(
                      color: V3Colors.edgeWarm2,
                      borderRadius: BorderRadius.circular(12)))),
          Positioned(
              left: 3,
              right: 3,
              top: -3,
              height: 30,
              child: DecoratedBox(
                  decoration: BoxDecoration(
                      color: V3Colors.edgeWarm1,
                      borderRadius: BorderRadius.circular(13)))),
          Material(
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
                      Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('À FAIRE AUJOURD’HUI',
                                style: AppTextStyles.mono(12, FontWeight.w700,
                                    letterSpacing: 1.1,
                                    color: V3Colors.terraInk)),
                            Flexible(
                                child: Text(countLabel,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.mono(
                                        11, FontWeight.w400,
                                        color: V3Colors.ink60))),
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
                          child: Text('Commencer',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.fig(15.5, FontWeight.w700,
                                  color: V3Colors.paper))),
                    ]),
              ),
            ),
          ),
        ],
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
                Text('MON PARCOURS',
                    style: AppTextStyles.mono(12, FontWeight.w400,
                        letterSpacing: 1.1, color: V3Colors.light60)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('$remainingLessons LEÇONS À DÉCOUVRIR',
                      textAlign: TextAlign.end,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                      Text('Niveau 1',
                          style: AppTextStyles.serif(21, FontWeight.w400,
                              color: V3Colors.light)),
                      const SizedBox(height: 2),
                      Text(
                          firstList == null
                              ? 'Prépare tes premiers mots'
                              : 'En ce moment · ${firstList!.name}',
                          style: AppTextStyles.fig(13, FontWeight.w400,
                              color: V3Colors.light70)),
                    ])),
                Text('Voir ›',
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
              Text('Mon parcours',
                  style: AppTextStyles.serif(29, FontWeight.w400)),
              const SizedBox(height: 6),
              Text(
                  'Tu avances à ton rythme. Les leçons se débloquent avec les mots dont elles ont besoin.',
                  style: AppTextStyles.fig(15, FontWeight.w400,
                      color: V3Colors.ink60)),
              const SizedBox(height: 17),
              _SheetChoice(
                  label: firstList == null
                      ? 'Créer une première liste'
                      : 'Reprendre «\u202f${firstList!.name}\u202f»',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    firstList == null
                        ? context.go('/lists')
                        : context.push('/lists/${firstList!.id}');
                  }),
              const SizedBox(height: 7),
              _SheetChoice(
                  label: rules.isEmpty
                      ? 'Voir les leçons'
                      : 'Voir les ${rules.length} leçons',
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
      required this.totalWords});
  final int due;
  final int readLessons;
  final int remainingLessons;
  final int totalWords;

  @override
  Widget build(BuildContext context) => GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 9,
        mainAxisSpacing: 9,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1.3,
        children: [
          _Metric(
              value: '$due',
              title: 'Mots à revoir',
              meta: due > 0 ? 'À REPRENDRE' : 'RIEN À REVOIR',
              amber: due > 0),
          _Metric(
              value: '$readLessons',
              title: 'Leçons lues',
              meta: '$remainingLessons À DÉCOUVRIR'),
          _Metric(
              value: '$totalWords',
              title: 'Mots dans tes listes',
              meta: 'À TON RYTHME'),
          _Metric(
              value: '${readLessons + totalWords}',
              title: 'Ce que tu connais',
              meta: 'ÇA SE CONSTRUIT'),
        ],
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.fig(13.5, FontWeight.w600,
                        color: V3Colors.light)),
                const SizedBox(height: 2),
                Text(meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.fig(13.5, FontWeight.w600,
                            color: V3Colors.light)),
                    const SizedBox(height: 3),
                    Text(meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
