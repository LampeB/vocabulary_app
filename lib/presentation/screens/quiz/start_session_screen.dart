import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../domain/entities/vocabulary_list.dart';
import '../../providers/lists/vocabulary_provider.dart';
import '../../providers/quiz/quiz_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../widgets/dotted_ground.dart';

/// The single front door to studying (start-session-screen.md). An accordion:
/// one section open at a time; selecting a value auto-advances to the next.
///
/// MVP scope: real vocab lists + quiz type + direction + count. The dynamic
/// smart-lists ("En cours d'apprentissage" / "À réviser maintenant") and the
/// Home one-tap deep link are deferred — they need cross-list FSRS queries
/// (tracked separately).
class StartSessionScreen extends ConsumerStatefulWidget {
  const StartSessionScreen({super.key});

  @override
  ConsumerState<StartSessionScreen> createState() => _StartSessionScreenState();
}

class _StartSessionScreenState extends ConsumerState<StartSessionScreen> {
  // Sections: 0 type · 1 list · 2 quiz-type · 3 direction · 4 count.
  int _open = 1; // type defaults to Vocabulaire, so start on List.
  String? _listId;
  String _listName = '';
  QuizMode _mode = QuizMode.voice;
  QuizDirectionChoice _dir = QuizDirectionChoice.frToKo;
  int _count = 20;

  static const _limits = [10, 20, 50, 100];

  void _select(int next) => setState(() => _open = next);

  @override
  Widget build(BuildContext context) {
    final listsAsync = ref.watch(myListsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text('start_session.title'.tr()),
      ),
      body: Stack(
        children: [
          const DottedGround(),
          ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
            children: [
              // 0 — Type de session.
              _Section(
                index: 0,
                isOpen: _open == 0,
                label: 'start_session.section_type'.tr(),
                value: 'start_session.type_vocab'.tr(),
                onHeaderTap: () => _select(0),
                child: Column(
                  children: [
                    _OptionTile(
                      label: 'start_session.type_vocab'.tr(),
                      selected: true,
                      onTap: () => _select(1),
                    ),
                    const SizedBox(height: 8),
                    _OptionTile(
                      label: 'start_session.type_grammar'.tr(),
                      selected: false,
                      disabled: true,
                      trailing: 'start_session.soon'.tr(),
                      onTap: () {},
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // 1 — Liste.
              _Section(
                index: 1,
                isOpen: _open == 1,
                label: 'start_session.section_list'.tr(),
                value: _listName,
                onHeaderTap: () => _select(1),
                child: listsAsync.when(
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
              // 2 — Type de quiz.
              _Section(
                index: 2,
                isOpen: _open == 2,
                label: 'quiz_setup.section_mode'.tr(),
                value: _modeLabel(_mode),
                onHeaderTap: () => _select(2),
                child: Column(
                  children: [
                    for (final m in QuizMode.values) ...[
                      if (m != QuizMode.values.first) const SizedBox(height: 8),
                      _OptionTile(
                        label: _modeLabel(m),
                        selected: _mode == m,
                        onTap: () {
                          setState(() => _mode = m);
                          _select(3);
                        },
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // 3 — Sens.
              _Section(
                index: 3,
                isOpen: _open == 3,
                label: 'quiz_setup.section_direction'.tr(),
                value: _dirLabel(_dir),
                onHeaderTap: () => _select(3),
                child: Column(
                  children: [
                    for (final d in QuizDirectionChoice.values) ...[
                      if (d != QuizDirectionChoice.values.first)
                        const SizedBox(height: 8),
                      _OptionTile(
                        label: _dirLabel(d),
                        selected: _dir == d,
                        onTap: () {
                          setState(() => _dir = d);
                          _select(4);
                        },
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // 4 — Nombre de mots.
              _Section(
                index: 4,
                isOpen: _open == 4,
                label: 'quiz_setup.section_card_count'.tr(),
                value: '$_count',
                onHeaderTap: () => _select(4),
                child: Wrap(
                  spacing: 8,
                  children: [
                    for (final n in _limits)
                      _CountChip(
                        n: n,
                        selected: _count == n,
                        onTap: () => setState(() => _count = n),
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
                onPressed: _listId == null ? null : _start,
                icon: const Icon(Icons.play_arrow_rounded,
                    color: Colors.white, size: 22),
                label: Text(
                  'start_session.start_with_count'
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

  Widget _listOptions(List<VocabularyList> lists) {
    if (lists.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text('start_session.empty_lists'.tr(),
            style: AppTextStyles.body.copyWith(color: AppColors.muted)),
      );
    }
    return Column(
      children: [
        for (final l in lists) ...[
          if (l != lists.first) const SizedBox(height: 8),
          _OptionTile(
            label: l.name,
            trailing: '${l.wordCount}',
            selected: _listId == l.id,
            onTap: () {
              setState(() {
                _listId = l.id;
                _listName = l.name;
              });
              _select(2);
            },
          ),
        ],
      ],
    );
  }

  String _modeLabel(QuizMode m) => switch (m) {
        QuizMode.voice => 'quiz_setup.mode_voice_label'.tr(),
        QuizMode.flashcard => 'quiz_setup.mode_flashcard_label'.tr(),
        QuizMode.typing => 'quiz_setup.mode_typing_label'.tr(),
        QuizMode.handsFree => 'quiz_setup.mode_hands_free_label'.tr(),
      };

  String _dirLabel(QuizDirectionChoice d) => switch (d) {
        QuizDirectionChoice.frToKo => 'quiz_setup.dir_fr_to_kr'.tr(),
        QuizDirectionChoice.koToFr => 'quiz_setup.dir_kr_to_fr'.tr(),
        QuizDirectionChoice.both => 'quiz_setup.dir_both'.tr(),
      };

  void _start() {
    context.go(
      '/quiz',
      extra: QuizArgs(
        listId: _listId!,
        mode: _mode,
        direction: _dir,
        cardLimit: _count,
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

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: isDark ? 0.4 : 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        children: [
          InkWell(
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
                  Icon(isOpen ? Icons.expand_less : Icons.expand_more,
                      color: muted, size: 20),
                ],
              ),
            ),
          ),
          if (isOpen)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: child,
            ),
        ],
      ),
    );
  }
}

// ── Option tile (unified filled selected style) ───────────────────────────────

class _OptionTile extends StatelessWidget {
  const _OptionTile({
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
                Text(trailing!,
                    style: AppTextStyles.caption.copyWith(
                        color: selected ? Colors.white70 : muted)),
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
      {required this.n, required this.selected, required this.onTap});
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
