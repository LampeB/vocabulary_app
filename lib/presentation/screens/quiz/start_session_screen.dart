import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../domain/entities/vocabulary_list.dart';
import '../../../core/languages.dart';
import '../../../domain/entities/grammar_rule.dart';
import '../../providers/grammar/grammar_provider.dart';
import '../../../domain/usecases/quiz/get_due_cards_usecase.dart'
    show QuizSource;
import '../../providers/lists/vocabulary_provider.dart';
import '../../providers/quiz/quiz_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widget_keys.dart';
import '../../widgets/dotted_ground.dart';

/// Session setup (start-session-screen.md). An accordion: one section open
/// at a time; selecting a value auto-advances to the next.
///
/// Vocabulary and grammar are SEPARATE flows (product decision 2026-07-05):
/// the default screen is vocabulary-only — list + quiz type + direction +
/// count, no grammar anywhere. `grammar: true` (its own route, entered from
/// the Home grammar card) swaps the flow to rule + quiz type + count.
class StartSessionScreen extends ConsumerStatefulWidget {
  const StartSessionScreen({super.key, this.grammar = false});

  final bool grammar;

  @override
  ConsumerState<StartSessionScreen> createState() => _StartSessionScreenState();
}

class _StartSessionScreenState extends ConsumerState<StartSessionScreen> {
  static const _kTestMode = bool.fromEnvironment('TEST_MODE');

  // Sections: 0 list|rule · 1 quiz-type · 2 direction (vocab only) · 3 count.
  // Everything starts EMPTY and COLLAPSED (user feedback 2026-07-05: no
  // preselected values); each choice auto-opens the next section. E2E is the
  // exception: the list section starts open and direction/count stay
  // prefilled there, so emulator sessions keep the tiny TEST_CARD_LIMIT
  // instead of a 10-card minimum.
  int _open = _kTestMode ? 0 : -1;
  bool get _grammar => widget.grammar;
  String? _ruleId;
  String _ruleTitle = '';
  String? _listId;
  QuizSource _source = QuizSource.list;
  String _listName = '';
  // The selected list's language pair drives the direction labels (smart
  // sources span lists — all FR/KR today, so they use the defaults).
  String _langA = 'fr';
  String _langB = 'ko';
  QuizMode? _mode;
  QuizDirectionChoice? _dir = _kTestMode ? QuizDirectionChoice.frToKo : null;
  int? _count = _kTestMode
      ? const int.fromEnvironment('TEST_CARD_LIMIT', defaultValue: 20)
      : null;

  static const _limits = [10, 20, 50, 100];

  void _select(int next) => setState(() => _open = next);

  @override
  Widget build(BuildContext context) {
    final listsAsync = ref.watch(myListsProvider);

    return Scaffold(
      key: const ValueKey(WidgetKeys.screenStartSession),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text((_grammar
                ? 'start_session.title_grammar'
                : 'start_session.title')
            .tr()),
      ),
      body: Stack(
        children: [
          const DottedGround(),
          ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
            children: [
              // 0 — Liste (vocab) | Règle (grammar).
              _Section(
                index: 0,
                isOpen: _open == 0,
                label: (_grammar
                        ? 'start_session.section_rule'
                        : 'start_session.section_list')
                    .tr(),
                value: _grammar ? _ruleTitle : _listName,
                onHeaderTap: () => _select(0),
                child: _grammar
                    ? _ruleOptions()
                    : listsAsync.when(
                        loading: () => const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: CircularProgressIndicator(
                                color: AppColors.clay, strokeWidth: 2),
                          ),
                        ),
                        error: (_, __) => Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text('common.error'.tr()),
                        ),
                        data: (lists) => _listOptions(lists),
                      ),
              ),
              const SizedBox(height: 10),
              // 1 — Type de quiz.
              _Section(
                index: 1,
                isOpen: _open == 1,
                label: 'quiz_setup.section_mode'.tr(),
                value: _mode == null ? '' : _modeLabel(_mode!),
                onHeaderTap: () => _select(1),
                child: Column(
                  children: [
                    for (final m in QuizMode.values) ...[
                      if (m != QuizMode.values.first) const SizedBox(height: 8),
                      _OptionTile(
                        key: ValueKey(WidgetKeys.startQuizType(m.name)),
                        label: _modeLabel(m),
                        selected: _mode == m,
                        onTap: () {
                          setState(() => _mode = m);
                          _select(_grammar ? 3 : 2);
                        },
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // 2 — Sens (vocab only: grammar drills are FR → KR by nature).
              if (!_grammar)
                _Section(
                index: 2,
                isOpen: _open == 2,
                label: 'quiz_setup.section_direction'.tr(),
                value: _dir == null ? '' : _dirLabel(_dir!),
                onHeaderTap: () => _select(2),
                child: Column(
                  children: [
                    for (final d in QuizDirectionChoice.values) ...[
                      if (d != QuizDirectionChoice.values.first)
                        const SizedBox(height: 8),
                      _OptionTile(
                        key: ValueKey(WidgetKeys.startDirection(d.name)),
                        label: _dirLabel(d),
                        selected: _dir == d,
                        onTap: () {
                          setState(() => _dir = d);
                          _select(3);
                        },
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // 3 — Nombre de mots.
              _Section(
                index: 3,
                isOpen: _open == 3,
                label: 'quiz_setup.section_card_count'.tr(),
                value: _count == null ? '' : '$_count',
                onHeaderTap: () => _select(3),
                child: Wrap(
                  spacing: 8,
                  children: [
                    for (final n in _limits)
                      _CountChip(
                        key: ValueKey(WidgetKeys.startCount(n)),
                        n: n,
                        selected: _count == n,
                        // Last choice: picking the count folds the accordion.
                        onTap: () {
                          setState(() => _count = n);
                          _select(-1);
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
          // Pinned Commencer CTA.
          Positioned(
            left: 20,
            right: 20,
            bottom: 20 + MediaQuery.of(context).padding.bottom,
            child: SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                key: const ValueKey(WidgetKeys.startSessionStart),
                onPressed: _canStart ? _start : null,
                icon: const Icon(Icons.play_arrow_rounded,
                    color: Colors.white, size: 22),
                label: Text(
                  _count == null
                      ? 'start_session.start'.tr()
                      : 'start_session.start_with_count'
                          .tr(namedArgs: {'count': _count.toString()}),
                  style: AppTextStyles.fig(15, FontWeight.w700)
                      .copyWith(color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _listOptions(List<VocabularyList> unsorted) {
    // STABLE alphabetical order. The provider streams by updatedAt, and a
    // background sync re-sorting the tiles between the user's glance and
    // tap selects the wrong list (field report 2026-07-07).
    final lists = [...unsorted]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final dueCount = ref.watch(dueCountProvider).valueOrNull ?? 0;
    // Smart lists first (cross-list FSRS sources), then the user's own lists.
    final smartTiles = [
      _OptionTile(
        key: ValueKey(WidgetKeys.startSmart('due')),
        label: 'start_session.smart_due'.tr(),
        trailing: '$dueCount',
        selected: _source == QuizSource.allDue,
        onTap: () => _selectSmart(QuizSource.allDue,
            'start_session.smart_due'.tr()),
      ),
      const SizedBox(height: 8),
      _OptionTile(
        key: ValueKey(WidgetKeys.startSmart('inprogress')),
        label: 'start_session.smart_in_progress'.tr(),
        selected: _source == QuizSource.inProgress,
        onTap: () => _selectSmart(QuizSource.inProgress,
            'start_session.smart_in_progress'.tr()),
      ),
    ];
    if (lists.isEmpty && dueCount == 0) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text('start_session.empty_lists'.tr(),
            style: AppTextStyles.body.copyWith(color: AppColors.muted)),
      );
    }
    return Column(
      children: [
        ...smartTiles,
        for (final l in lists) ...[
          const SizedBox(height: 8),
          _OptionTile(
            label: l.name,
            trailing: '${l.wordCount}',
            selected: _source == QuizSource.list && _listId == l.id,
            onTap: () {
              setState(() {
                _source = QuizSource.list;
                _listId = l.id;
                _listName = l.name;
                _langA = l.langA;
                _langB = l.langB;
              });
              _select(1);
            },
          ),
        ],
      ],
    );
  }

  Widget _ruleOptions() {
    final statusesAsync = ref.watch(ruleStatusesProvider);
    return statusesAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child:
              CircularProgressIndicator(color: AppColors.clay, strokeWidth: 2),
        ),
      ),
      error: (_, __) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text('common.error'.tr()),
      ),
      data: (statuses) => Column(
        children: [
          for (final st in statuses) ...[
            if (st != statuses.first) const SizedBox(height: 8),
            _OptionTile(
              key: ValueKey(WidgetKeys.startRule(st.rule.id)),
              label: st.rule.titleFr,
              selected: _ruleId == st.rule.id,
              disabled: st.availability == RuleAvailability.locked ||
                  !st.enoughWords,
              trailing: switch (st.availability) {
                RuleAvailability.mastered =>
                  'start_session.rule_mastered'.tr(),
                RuleAvailability.unlocked when !st.enoughWords =>
                  'start_session.rule_not_enough_words'.tr(),
                RuleAvailability.unlocked =>
                  '${st.correct}/$ruleMasteryTarget',
                RuleAvailability.locked => 'start_session.rule_locked'
                    .tr(namedArgs: {'lists': st.missingLists.join(', ')}),
              },
              onTap: () => _showLessonSheet(st.rule),
            ),
          ],
        ],
      ),
    );
  }

  /// Stage-2 lesson: the rule explanation + worked examples, then start.
  Future<void> _showLessonSheet(GrammarRule rule) async {
    final start = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(rule.titleFr,
                    style: AppTextStyles.grotesk(22, FontWeight.w700)
                        .copyWith(color: cs.onSurface)),
                const SizedBox(height: 12),
                Text(rule.explanationFr,
                    style: AppTextStyles.body.copyWith(color: cs.onSurface)),
                const SizedBox(height: 16),
                Text('grammar.lesson.examples'.tr(),
                    style: AppTextStyles.eyebrow
                        .copyWith(color: AppColors.muted)),
                const SizedBox(height: 8),
                for (final e in rule.workedExamples) ...[
                  Text(e.ko,
                      style: AppTextStyles.kr(16, FontWeight.w600)
                          .copyWith(color: cs.onSurface)),
                  Text(e.fr,
                      style:
                          AppTextStyles.caption.copyWith(color: AppColors.muted)),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: const ValueKey(WidgetKeys.grammarLessonStart),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text('grammar.lesson.start'.tr()),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (start == true && mounted) {
      setState(() {
        _ruleId = rule.id;
        _ruleTitle = rule.titleFr;
      });
      _select(1);
    }
  }

  void _selectSmart(QuizSource source, String label) {
    setState(() {
      _source = source;
      _listId = null;
      _listName = label;
      _langA = 'fr';
      _langB = 'ko';
    });
    _select(1);
  }

  String _modeLabel(QuizMode m) => switch (m) {
        QuizMode.voice => 'quiz_setup.mode_voice_label'.tr(),
        QuizMode.flashcard => 'quiz_setup.mode_flashcard_label'.tr(),
        QuizMode.typing => 'quiz_setup.mode_typing_label'.tr(),
        QuizMode.handsFree => 'quiz_setup.mode_hands_free_label'.tr(),
      };

  // Direction labels are DERIVED from the selected list's language pair —
  // never hardcoded (generic-language-pairs epic). The enum values keep their
  // legacy names until the generic-direction sub-task lands.
  String _dirLabel(QuizDirectionChoice d) {
    final a = _cap(Languages.displayName(_langA));
    final b = _cap(Languages.displayName(_langB));
    return switch (d) {
      QuizDirectionChoice.frToKo => '$a → $b',
      QuizDirectionChoice.koToFr => '$b → $a',
      QuizDirectionChoice.both => 'quiz_setup.dir_both'.tr(),
    };
  }

  static String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  // No field has a default, so every one must be chosen before starting.
  bool get _canStart {
    if (_mode == null || _count == null) return false;
    if (_grammar) return _ruleId != null;
    if (_dir == null) return false;
    return _source != QuizSource.list || _listId != null;
  }

  void _start() {
    context.go(
      '/quiz',
      extra: _grammar
          ? QuizArgs(
              source: QuizSource.grammar,
              ruleId: _ruleId,
              ruleTitle: _ruleTitle,
              mode: _mode!,
              direction: QuizDirectionChoice.frToKo,
              cardLimit: _count!,
            )
          : QuizArgs(
              listId: _listId,
              source: _source,
              mode: _mode!,
              direction: _dir!,
              cardLimit: _count!,
              langA: _langA,
              langB: _langB,
            ),
    );
  }
}

// ── Accordion section ─────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section({
    required this.index,
    required this.isOpen,
    required this.label,
    required this.value,
    required this.onHeaderTap,
    required this.child,
  });
  final int index;
  final bool isOpen;
  final String label;
  final String value;
  final VoidCallback onHeaderTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final muted = isDark ? AppColors.onDarkMuted : AppColors.muted;
    // Sections must stand out from the page: lighter than the background in
    // dark mode, darker in light mode — and the expanded section pushes
    // further in the same direction so the active step reads at a glance.
    final bg = isDark
        ? Color.lerp(cs.surface, Colors.white, isOpen ? 0.16 : 0.08)!
        : Color.lerp(cs.surface, Colors.black, isOpen ? 0.10 : 0.05)!;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        children: [
          InkWell(
            key: ValueKey(WidgetKeys.startSection(index)),
            onTap: onHeaderTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Text(label,
                      style: AppTextStyles.eyebrow.copyWith(color: muted)),
                  const Spacer(),
                  if (!isOpen && value.isNotEmpty)
                    Flexible(
                      child: Text(value,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.fig(14, FontWeight.w600)
                              .copyWith(color: cs.onSurface)),
                    ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: isOpen ? 0.5 : 0,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeInOut,
                    child: Icon(Icons.expand_more, color: muted, size: 20),
                  ),
                ],
              ),
            ),
          ),
          // Open/close slides the body in and out (user feedback 2026-07-05).
          ClipRect(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: isOpen
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: child,
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Option tile (unified filled selected style) ───────────────────────────────

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.trailing,
    this.disabled = false,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? trailing;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final muted = isDark ? AppColors.onDarkMuted : AppColors.muted;
    final fg = selected
        ? Colors.white
        : (disabled ? (isDark ? AppColors.onDarkFaint : AppColors.faint) : cs.onSurface);

    return Opacity(
      opacity: disabled ? 0.6 : 1,
      child: GestureDetector(
        onTap: disabled ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: selected ? AppColors.teal : cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? AppColors.teal : cs.outline),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(label,
                    style: AppTextStyles.fig(15, FontWeight.w600)
                        .copyWith(color: fg)),
              ),
              if (trailing != null)
                // Flexible: long trailings (e.g. a locked rule's prerequisite
                // list names) must ellipsize, not overflow the tile.
                Flexible(
                  child: Text(trailing!,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: AppTextStyles.caption.copyWith(
                          color: selected ? Colors.white70 : muted)),
                ),
              if (selected)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(Icons.check_rounded, color: Colors.white, size: 18),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Count chip ────────────────────────────────────────────────────────────────

class _CountChip extends StatelessWidget {
  const _CountChip(
      {super.key,
      required this.n,
      required this.selected,
      required this.onTap});
  final int n;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final muted = isDark ? AppColors.onDarkMuted : AppColors.muted;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.teal : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? AppColors.teal : cs.outline),
        ),
        child: Text('$n',
            style: AppTextStyles.fig(14, FontWeight.w700)
                .copyWith(color: selected ? Colors.white : muted)),
      ),
    );
  }
}
