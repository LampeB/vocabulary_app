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
  // Language-first flow (vocab only): the pair must be chosen before the list
  // section reveals the lists for that language. Prefilled under test.
  bool _langChosen = _kTestMode;
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

    // Section indices. Vocab gains a Language step at 0, shifting the rest;
    // grammar keeps its Rule → Type → Count layout (no language/list/direction).
    final iList = _grammar ? 0 : 1; // grammar: Rule; vocab: List
    final iMode = _grammar ? 1 : 2;
    const iDir = 3; // vocab only
    final iCount = _grammar ? 3 : 4;

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
              // 0 — Langue (vocab only). Pick the pair; the list section then
              // shows only that language's lists.
              if (!_grammar) ...[
                _Section(
                  index: 0,
                  isOpen: _open == 0,
                  label: 'start_session.section_language'.tr(),
                  value: _langChosen
                      ? '${Languages.flagFor(_langA)} → ${Languages.flagFor(_langB)}  '
                          '${_cap(Languages.displayName(_langB))}'
                      : '',
                  onHeaderTap: () => _select(0),
                  child: listsAsync.when(
                    loading: () => _loadingBox(),
                    error: (_, __) => _errorBox(),
                    data: (lists) => _languageOptions(lists),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              // iList — Liste (vocab) | Règle (grammar).
              _Section(
                index: iList,
                isOpen: _open == iList,
                label: (_grammar
                        ? 'start_session.section_rule'
                        : 'start_session.section_list')
                    .tr(),
                value: _grammar ? _ruleTitle : _listName,
                onHeaderTap: () => _select(iList),
                child: _grammar
                    ? _ruleOptions()
                    : listsAsync.when(
                        loading: () => _loadingBox(),
                        error: (_, __) => _errorBox(),
                        data: (lists) => _listOptions(lists),
                      ),
              ),
              const SizedBox(height: 10),
              // iMode — Type de quiz.
              _Section(
                index: iMode,
                isOpen: _open == iMode,
                label: 'quiz_setup.section_mode'.tr(),
                value: _mode == null ? '' : _modeLabel(_mode!),
                onHeaderTap: () => _select(iMode),
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
                          _select(_grammar ? iCount : iDir);
                        },
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // iDir — Sens (vocab only: grammar drills are FR → KR by nature).
              if (!_grammar)
                _Section(
                index: iDir,
                isOpen: _open == iDir,
                label: 'quiz_setup.section_direction'.tr(),
                value: _dir == null ? '' : _dirLabel(_dir!),
                onHeaderTap: () => _select(iDir),
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
                          _select(iCount);
                        },
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // iCount — Nombre de mots.
              _Section(
                index: iCount,
                isOpen: _open == iCount,
                label: 'quiz_setup.section_card_count'.tr(),
                value: _count == null ? '' : '$_count',
                onHeaderTap: () => _select(iCount),
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

  Widget _loadingBox() => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child:
              CircularProgressIndicator(color: AppColors.clay, strokeWidth: 2),
        ),
      );

  Widget _errorBox() => Padding(
        padding: const EdgeInsets.all(16),
        child: Text('common.error'.tr()),
      );

  Widget _groupLabel(String text) => Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 2),
          child: Text(text.toUpperCase(),
              style: AppTextStyles.eyebrowSm.copyWith(color: AppColors.muted)),
        ),
      );

  /// Step ①: the distinct language pairs the user actually has lists for.
  /// Since langA is the user's own language, each row reads as the target
  /// language; selecting one reveals its lists in step ②.
  Widget _languageOptions(List<VocabularyList> lists) {
    final pairs = <(String, String)>{
      for (final l in lists) (l.langA, l.langB),
    }.toList()
      ..sort((a, b) =>
          Languages.displayName(a.$2).compareTo(Languages.displayName(b.$2)));

    if (pairs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text('start_session.empty_lists'.tr(),
            style: AppTextStyles.body.copyWith(color: AppColors.muted)),
      );
    }
    return Column(
      children: [
        for (final (i, p) in pairs.indexed) ...[
          if (i != 0) const SizedBox(height: 8),
          _OptionTile(
            key: ValueKey(WidgetKeys.startLanguage(p.$2)),
            label: '${Languages.flagFor(p.$1)} → ${Languages.flagFor(p.$2)}'
                '   ${_cap(Languages.displayName(p.$2))}',
            selected: _langChosen && _langA == p.$1 && _langB == p.$2,
            onTap: () {
              setState(() {
                _langA = p.$1;
                _langB = p.$2;
                _langChosen = true;
                // The previously-selected list may not belong to this pair.
                _listId = null;
                _listName = '';
                _source = QuizSource.list;
              });
              _select(1); // open the list step
            },
          ),
        ],
      ],
    );
  }

  /// Step ②: lists for the chosen language, split into "currently studying"
  /// (≥1 reviewed card) and "not yet studied", plus the two cross-list smart
  /// sources — scoped to this language via the pair carried into QuizArgs.
  Widget _listOptions(List<VocabularyList> all) {
    final studied =
        ref.watch(studiedListIdsProvider).valueOrNull ?? const <String>{};
    // Only this language's lists, STABLE alphabetical (the provider streams by
    // updatedAt; a background re-sort between glance and tap picks the wrong
    // list — field report 2026-07-07).
    final lists = all
        .where((l) => l.langA == _langA && l.langB == _langB)
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final studying = lists.where((l) => studied.contains(l.id)).toList();
    final fresh = lists.where((l) => !studied.contains(l.id)).toList();

    // Scoped to the chosen pair so "to study now" counts THIS language's due
    // cards, not every language's (the session itself is already pair-scoped).
    final dueCount =
        ref.watch(dueCountForPairProvider((_langA, _langB))).valueOrNull ?? 0;
    final smartTiles = [
      _OptionTile(
        key: ValueKey(WidgetKeys.startSmart('due')),
        label: 'start_session.smart_due'.tr(),
        trailing: '$dueCount',
        selected: _source == QuizSource.allDue,
        onTap: () =>
            _selectSmart(QuizSource.allDue, 'start_session.smart_due'.tr()),
      ),
      const SizedBox(height: 8),
      _OptionTile(
        key: ValueKey(WidgetKeys.startSmart('inprogress')),
        label: 'start_session.smart_in_progress'.tr(),
        selected: _source == QuizSource.inProgress,
        onTap: () => _selectSmart(
            QuizSource.inProgress, 'start_session.smart_in_progress'.tr()),
      ),
    ];

    if (lists.isEmpty && dueCount == 0) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text('start_session.empty_lists'.tr(),
            style: AppTextStyles.body.copyWith(color: AppColors.muted)),
      );
    }

    Widget tile(VocabularyList l) => _OptionTile(
          label: l.name,
          trailing: '${l.wordCount}',
          onPreview:
              l.wordCount > 0 ? () => _showListPreview(context, l) : null,
          selected: _source == QuizSource.list && _listId == l.id,
          onTap: () {
            setState(() {
              _source = QuizSource.list;
              _listId = l.id;
              _listName = l.name;
              _langA = l.langA;
              _langB = l.langB;
            });
            _select(2); // open the mode step
          },
        );

    return Column(
      children: [
        ...smartTiles,
        if (studying.isNotEmpty) ...[
          const SizedBox(height: 14),
          _groupLabel('start_session.group_studying'.tr()),
          for (final l in studying) ...[const SizedBox(height: 8), tile(l)],
        ],
        if (fresh.isNotEmpty) ...[
          const SizedBox(height: 14),
          _groupLabel('start_session.group_not_studied'.tr()),
          for (final l in fresh) ...[const SizedBox(height: 8), tile(l)],
        ],
      ],
    );
  }

  Widget _ruleOptions() {
    final statusesAsync = ref.watch(ruleStatusesProvider(_langB));
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
              label: st.rule.title(uiLocaleCode(context)),
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
                Text(rule.title(uiLocaleCode(ctx)),
                    style: AppTextStyles.grotesk(22, FontWeight.w700)
                        .copyWith(color: cs.onSurface)),
                const SizedBox(height: 12),
                Text(rule.explanation(uiLocaleCode(ctx)),
                    style: AppTextStyles.body.copyWith(color: cs.onSurface)),
                const SizedBox(height: 16),
                Text('grammar.lesson.examples'.tr(),
                    style: AppTextStyles.eyebrow
                        .copyWith(color: AppColors.muted)),
                const SizedBox(height: 8),
                for (final e in rule.workedExamples) ...[
                  Text(e.target,
                      style: (Languages.usesHangul(_langB)
                              ? AppTextStyles.kr(16, FontWeight.w600)
                              : AppTextStyles.fig(16, FontWeight.w600))
                          .copyWith(color: cs.onSurface)),
                  Text(e.translation(uiLocaleCode(ctx)),
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
        _ruleTitle = rule.title(uiLocaleCode(context));
      });
      _select(1);
    }
  }

  void _selectSmart(QuizSource source, String label) {
    // Keep the chosen language pair — the smart source scopes to it (a due
    // row's direction is 'a>b', so QuizArgs' pair filters to this language).
    setState(() {
      _source = source;
      _listId = null;
      _listName = label;
    });
    _select(2); // open the mode step
  }

  /// Peek at a list's words without leaving the quiz setup — the "what's in it"
  /// bottom sheet (user request 2026-07-19).
  void _showListPreview(BuildContext context, VocabularyList list) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ListPreviewSheet(list: list),
    );
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
    if (!_langChosen) return false; // vocab: language is the first choice
    if (_dir == null) return false;
    return _source != QuizSource.list || _listId != null;
  }

  void _start() {
    // Wipe any prior session so the quiz screen doesn't flash the old
    // summary before its cards load (field 2026-07-14).
    ref.read(quizProvider.notifier).reset();
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
    this.onPreview,
    this.disabled = false,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? trailing;
  // When set, a peek icon appears that opens a word preview (not selection).
  final VoidCallback? onPreview;
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
              // Peek icon LAST so it sits at the row's right edge
              // (user feedback 2026-07-19).
              if (onPreview != null)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onPreview,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: Icon(Icons.visibility_outlined,
                        size: 18, color: selected ? Colors.white70 : muted),
                  ),
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
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(list.name,
                        style: AppTextStyles.grotesk(20, FontWeight.w700)),
                  ),
                  Text(
                      '${Languages.flagFor(list.langA)} → '
                      '${Languages.flagFor(list.langB)}',
                      style: AppTextStyles.body),
                ],
              ),
              const SizedBox(height: 12),
              Flexible(
                child: conceptsAsync.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(
                          color: AppColors.clay, strokeWidth: 2),
                    ),
                  ),
                  error: (_, __) => Text('common.error'.tr()),
                  data: (concepts) {
                    final visible =
                        concepts.where((c) => !c.isDeleted).toList();
                    if (visible.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text('start_session.empty_lists'.tr(),
                            style: AppTextStyles.body
                                .copyWith(color: AppColors.muted)),
                      );
                    }
                    return ListView.separated(
                      shrinkWrap: true,
                      itemCount: visible.length,
                      separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: Theme.of(context).colorScheme.outline),
                      itemBuilder: (_, i) => _PreviewRow(
                        conceptId: visible[i].id,
                        langA: list.langA,
                        langB: list.langB,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewRow extends ConsumerWidget {
  const _PreviewRow(
      {required this.conceptId, required this.langA, required this.langB});
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

    TextStyle styleFor(String lang, {Color? color}) => Languages.usesHangul(lang)
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
            child: Text(wordFor(langB),
                textAlign: TextAlign.end,
                style: styleFor(langB, color: muted)),
          ),
        ],
      ),
    );
  }
}
