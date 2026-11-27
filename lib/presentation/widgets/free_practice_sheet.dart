import 'dart:math' as math;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/languages.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/v3_colors.dart';
import '../../domain/entities/vocabulary_list.dart';
import '../../domain/usecases/quiz/get_due_cards_usecase.dart' show QuizSource;
import '../providers/lists/vocabulary_provider.dart';
import '../providers/quiz/quiz_provider.dart';
import '../providers/quiz/quiz_availability_provider.dart';
import 'list_preview_sheet.dart';
import 'quiz_mode_label.dart';
import 'scroll_affordance.dart';

Future<void> showFreePracticeSheet(
  BuildContext context, {
  required (String, String) pair,
}) async {
  final args = await showModalBottomSheet<QuizArgs>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => FreePracticeSheet(pair: pair),
  );
  if (args != null && context.mounted) await context.push('/quiz', extra: args);
}

/// The header's pair is kept throughout this short, three-choice flow.
class FreePracticeSheet extends ConsumerStatefulWidget {
  const FreePracticeSheet({super.key, required this.pair});
  final (String, String) pair;
  @override
  ConsumerState<FreePracticeSheet> createState() => _FreePracticeSheetState();
}

class _FreePracticeSheetState extends ConsumerState<FreePracticeSheet> {
  QuizSource _source = QuizSource.allDue;
  String? _listId;
  QuizMode _mode = QuizMode.flashcard;
  QuizDirectionChoice _direction = QuizDirectionChoice.both;

  // Keep the existing short-session default; quantity is not a fourth field.
  static const _sessionLimit = 20;

  @override
  Widget build(BuildContext context) {
    final listState = ref.watch(myListsProvider);
    final due =
        ref
            .watch(
              quizAvailabilityProvider((
                pair: widget.pair,
                source: QuizSource.allDue,
                direction: _direction,
                listId: null,
              )),
            )
            .valueOrNull ??
        0;
    final studied =
        ref.watch(studiedListIdsProvider).valueOrNull ?? const <String>{};
    final lists =
        (listState.valueOrNull ?? const <VocabularyList>[])
            .where(
              (list) =>
                  list.langA == widget.pair.$1 &&
                  list.langB == widget.pair.$2 &&
                  !list.isDeleted,
            )
            .toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
    final selected = lists.where((list) => list.id == _listId).firstOrNull;
    final query = (
      pair: widget.pair,
      source: _source,
      direction: _direction,
      listId: _source == QuizSource.list ? selected?.id : null,
    );
    final availability = ref.watch(quizAvailabilityProvider(query));
    final count = availability.valueOrNull ?? 0;
    final canStart =
        !availability.isLoading && !availability.hasError && count > 0;
    final limit = math.min(count, _sessionLimit);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? V3Colors.light : V3Colors.ink;
    final pairLabel =
        '${Languages.displayName(widget.pair.$1)} → ${Languages.displayName(widget.pair.$2)}';

    Widget heading(String label) => Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Text(label, style: AppTextStyles.eyebrow.copyWith(color: ink)),
    );
    Widget listChoice(VocabularyList list) => Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: ChoiceChip(
              key: ValueKey('free-practice-list-${list.id}'),
              label: Text(list.name),
              selected: _source == QuizSource.list && _listId == list.id,
              onSelected: (_) => setState(() {
                _source = QuizSource.list;
                _listId = list.id;
              }),
            ),
          ),
        ),
        IconButton(
          tooltip: 'common.preview'.tr(),
          onPressed: () => showListPreviewSheet(context, list),
          icon: const Icon(Icons.visibility_outlined),
        ),
      ],
    );

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .85,
        ),
        child: ScrollAffordance(
          hint: 'v3.scroll_hint'.tr(),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'course.free_practice'.tr(),
                      style: AppTextStyles.serif(
                        29,
                        FontWeight.w400,
                      ).copyWith(color: ink),
                    ),
                  ),
                  IconButton(
                    tooltip: 'common.close'.tr(),
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Text(
                pairLabel,
                style: AppTextStyles.caption.copyWith(color: ink),
              ),
              heading('free_practice.source'.tr()),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    key: const ValueKey('free-practice-due'),
                    label: Text('${'start_session.smart_due'.tr()} · $due'),
                    selected: _source == QuizSource.allDue,
                    onSelected: (_) => setState(() {
                      _source = QuizSource.allDue;
                      _listId = null;
                    }),
                  ),
                  ChoiceChip(
                    key: const ValueKey('free-practice-in-progress'),
                    label: Text('start_session.smart_in_progress'.tr()),
                    selected: _source == QuizSource.inProgress,
                    onSelected: (_) => setState(() {
                      _source = QuizSource.inProgress;
                      _listId = null;
                    }),
                  ),
                ],
              ),
              if (listState.isLoading) const LinearProgressIndicator(),
              if (listState.hasError) Text('common.error'.tr()),
              for (final group in [true, false])
                if (lists.any(
                  (list) => studied.contains(list.id) == group,
                )) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      (group
                              ? 'start_session.group_studying'
                              : 'start_session.group_not_studied')
                          .tr(),
                      style: AppTextStyles.caption,
                    ),
                  ),
                  for (final list in lists.where(
                    (list) => studied.contains(list.id) == group,
                  ))
                    listChoice(list),
                ],
              heading('quiz_setup.section_direction'.tr()),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final direction in QuizDirectionChoice.values)
                    ChoiceChip(
                      key: ValueKey(
                        'free-practice-direction-${direction.name}',
                      ),
                      label: Text(switch (direction) {
                        QuizDirectionChoice.both =>
                          'quiz_setup.dir_both_sub'.tr(),
                        QuizDirectionChoice.frToKo => pairLabel,
                        QuizDirectionChoice.koToFr =>
                          '${Languages.displayName(widget.pair.$2)} → ${Languages.displayName(widget.pair.$1)}',
                      }),
                      selected: _direction == direction,
                      onSelected: (_) => setState(() => _direction = direction),
                    ),
                ],
              ),
              heading('quiz_setup.section_mode'.tr()),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final mode in QuizMode.values)
                    ChoiceChip(
                      key: ValueKey('free-practice-mode-${mode.name}'),
                      label: Text(quizModeLabel(mode)),
                      selected: _mode == mode,
                      onSelected: (_) => setState(() => _mode = mode),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              if (availability.isLoading) const LinearProgressIndicator(),
              if (availability.hasError) ...[
                Text('common.error'.tr()),
                TextButton(
                  onPressed: () =>
                      ref.invalidate(quizAvailabilityProvider(query)),
                  child: Text('common.retry'.tr()),
                ),
              ] else if (!availability.isLoading && count == 0)
                Text('quiz.no_cards_available'.tr()),
              FilledButton(
                key: const ValueKey('free-practice-start'),
                onPressed: !canStart
                    ? null
                    : () => Navigator.pop(
                        context,
                        QuizArgs(
                          listId: _source == QuizSource.list
                              ? selected!.id
                              : null,
                          source: _source,
                          mode: _mode,
                          direction: _direction,
                          cardLimit: limit,
                          langA: widget.pair.$1,
                          langB: widget.pair.$2,
                        ),
                      ),
                child: Text(
                  'start_session.start_with_count'.tr(
                    namedArgs: {'count': '$limit'},
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
