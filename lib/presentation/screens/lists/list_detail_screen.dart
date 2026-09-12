import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/lists/vocabulary_provider.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/errors/failure.dart';
import '../../../core/languages.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widget_keys.dart';
import '../../widgets/dotted_ground.dart';
import '../../widgets/frosted_box.dart';
import '../../providers/lists/vocab_assistant_provider.dart';
import '../../../data/datasources/remote/vocab_assistant_datasource.dart';
import '../../../domain/entities/word_variant.dart';
import '../../../domain/usecases/quiz/get_due_cards_usecase.dart'
    show QuizSource;
import '../../providers/quiz/quiz_provider.dart';

class ListDetailScreen extends ConsumerStatefulWidget {
  const ListDetailScreen({super.key, required this.listId});
  final String listId;

  @override
  ConsumerState<ListDetailScreen> createState() => _ListDetailScreenState();
}

class _ListDetailScreenState extends ConsumerState<ListDetailScreen> {
  bool _editMode = false;

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(listInfoProvider(widget.listId));
    final conceptsAsync = ref.watch(listDetailProvider(widget.listId));

    return Scaffold(
      key: const ValueKey(WidgetKeys.screenListDetail),
      appBar: AppBar(
        leading: IconButton(
          key: const ValueKey(WidgetKeys.listDetailBack),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: listAsync.when(
          data: (l) => Text(l?.name ?? 'list_detail.appbar_fallback'.tr()),
          loading: () => const SizedBox.shrink(),
          error: (_, __) => Text('list_detail.appbar_fallback'.tr()),
        ),
        actions: _editMode
            ? [
                TextButton(
                  onPressed: () => setState(() => _editMode = false),
                  child: Text(
                    'list_detail.action_done'.tr(),
                    style: AppTextStyles.fig(14, FontWeight.w600)
                        .copyWith(color: AppColors.clay),
                  ),
                ),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.ios_share_outlined, size: 22),
                  tooltip: 'list_detail.tooltip_export'.tr(),
                  onPressed: () =>
                      _exportList(context, listAsync.valueOrNull?.name ?? ''),
                ),
                PopupMenuButton<String>(
                  key: const ValueKey(WidgetKeys.listDetailMenu),
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    if (value == 'edit') setState(() => _editMode = true);
                    if (value == 'export') {
                      _exportList(context, listAsync.valueOrNull?.name ?? '');
                    }
                    if (value == 'ai_suggest') {
                      _showAiSuggestionsSheet(context);
                    }
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      key: const ValueKey(WidgetKeys.listDetailEditItem),
                      value: 'edit',
                      child: Row(
                        children: [
                          const Icon(Icons.edit_outlined, size: 18),
                          const SizedBox(width: 12),
                          // Flexible: the popup caps its width (~256 on 360dp
                          // screens) and long FR labels overflow otherwise.
                          Flexible(
                            child: Text('list_detail.menu_edit'.tr(),
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'ai_suggest',
                      child: Row(
                        children: [
                          const Icon(Icons.auto_awesome_rounded, size: 18),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text('list_detail.menu_ai_suggest'.tr(),
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'export',
                      child: Row(
                        children: [
                          const Icon(Icons.ios_share_outlined, size: 18),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text('list_detail.menu_export'.tr(),
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
      ),
      body: Stack(
        children: [
          const DottedGround(),
          conceptsAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(
                  color: AppColors.clay, strokeWidth: 2),
            ),
            error: (e, _) => Center(
              child: Text('$e',
                  style: AppTextStyles.caption.copyWith(color: AppColors.rose)),
            ),
            data: (concepts) => concepts.isEmpty
                ? _EmptyState(onAddTap: () => _showAddWordDialog(context))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    itemCount: concepts.length,
                    itemBuilder: (ctx, i) => _ConceptTile(
                      key: Key(concepts[i].id),
                      concept: concepts[i],
                      listId: widget.listId,
                      editMode: _editMode,
                    ),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: listAsync.when(
            loading: () => _addWordBar(context),
            error: (_, __) => _addWordBar(context),
            data: (list) => list == null
                ? _addWordBar(context)
                : _studyAndEditBar(context, list),
          ),
        ),
      ),
    );
  }

  // ── Bottom bar variants ───────────────────────────────────────────────────

  Widget _addWordBar(BuildContext context) {
    return GestureDetector(
      key: const ValueKey(WidgetKeys.listDetailAddWord),
      onTap: () => _showAddWordDialog(context),
      child: FrostedBox(
        borderRadius: BorderRadius.circular(999),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Builder(builder: (ctx) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final muted = isDark ? AppColors.onDarkMuted : AppColors.muted;
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add, color: muted, size: 18),
              const SizedBox(width: 8),
              Text('list_detail.add_word_bar'.tr(),
                  style: AppTextStyles.fig(15, FontWeight.w600)
                      .copyWith(color: muted)),
            ],
          );
        }),
      ),
    );
  }

  /// A prerequisite list must lead somewhere concrete. The primary action
  /// starts an immediate flashcard run; editing remains available alongside
  /// it instead of forcing a learner through the generic setup accordion.
  Widget _studyAndEditBar(BuildContext context, dynamic list) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: () => context.push(
              '/quiz',
              extra: QuizArgs(
                listId: list.id as String,
                source: QuizSource.list,
                mode: QuizMode.flashcard,
                direction: QuizDirectionChoice.both,
                cardLimit: 10,
                langA: list.langA as String,
                langB: list.langB as String,
              ),
            ),
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text('course.free_practice'.tr()),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 52,
          height: 52,
          child: OutlinedButton(
            key: const ValueKey(WidgetKeys.listDetailAddWord),
            onPressed: () => _showAddWordDialog(context),
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _exportList(BuildContext context, String listName) async {
    final messenger = ScaffoldMessenger.of(context);
    final error = await ref
        .read(listActionsProvider.notifier)
        .exportList(widget.listId, listName.isEmpty ? widget.listId : listName);
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _showAddWordDialog(BuildContext context) async {
    var quotaExceeded = false;
    final list = ref.read(listInfoProvider(widget.listId)).valueOrNull;
    final langA = list?.langA ?? 'fr';
    final langB = list?.langB ?? 'ko';
    // Existing source-language words give the assistant the list's theme context.
    final concepts = ref.read(listDetailProvider(widget.listId)).valueOrNull;
    final existingSource = <String>[
      if (concepts != null)
        for (final c in concepts)
          ...?ref
              .read(variantsProvider(c.id))
              .valueOrNull
              ?.where((v) => v.langCode == langA && !v.isDeleted)
              .map((v) => v.word),
    ];

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _AddWordDialog(
        langA: langA,
        langB: langB,
        existingSource: existingSource,
        onSubmit: (wordA, wordB) async {
          final result =
              await ref.read(listActionsProvider.notifier).addConcept(
                    listId: widget.listId,
                    wordA: wordA,
                    wordB: wordB,
                  );
          if (result.isFailure &&
              result.exceptionOrNull is QuotaExceededException) {
            quotaExceeded = true;
            return false;
          }
          return result.isSuccess;
        },
      ),
    );

    if (quotaExceeded && context.mounted) context.push('/paywall');
  }

  /// Themed AI suggestions: infer the list's theme from its pairs, propose
  /// new words, add the checked ones (user request 2026-07-11).
  Future<void> _showAiSuggestionsSheet(BuildContext context) async {
    final concepts =
        ref.read(listDetailProvider(widget.listId)).valueOrNull ?? [];
    final pairs = <WordPairSuggestion>[];
    for (final c in concepts) {
      final variants = await ref
          .read(variantsProvider(c.id).future)
          .catchError((_) => <WordVariant>[]);
      final fr = variants.where((v) => v.langCode == 'fr' && !v.isDeleted);
      final ko = variants.where((v) => v.langCode == 'ko' && !v.isDeleted);
      if (fr.isNotEmpty && ko.isNotEmpty) {
        pairs.add(
            WordPairSuggestion(source: fr.first.word, target: ko.first.word));
      }
    }
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _AiSuggestionsSheet(
        existingPairs: pairs,
        onAdd: (selected) async {
          for (final p in selected) {
            await ref.read(listActionsProvider.notifier).addConcept(
                  listId: widget.listId,
                  wordA: p.source,
                  wordB: p.target,
                );
          }
        },
      ),
    );
  }
}

/// Add-word dialog with AI assistance: type one side, get translation
/// suggestions (+ voice-friendly longer forms for short words) as tappable
/// chips. The manual flow is unchanged — AI is one optional button.
class _AddWordDialog extends ConsumerStatefulWidget {
  const _AddWordDialog({
    required this.langA,
    required this.langB,
    required this.existingSource,
    required this.onSubmit,
  });

  /// The list's language pair — drives field labels/flags and the assistant's
  /// translation direction (generic-language-pairs epic; was fr/ko-hardcoded).
  final String langA;
  final String langB;
  final List<String> existingSource;

  /// Returns true when the pair was added (dialog closes).
  final Future<bool> Function(String wordA, String wordB) onSubmit;

  @override
  ConsumerState<_AddWordDialog> createState() => _AddWordDialogState();
}

class _AddWordDialogState extends ConsumerState<_AddWordDialog> {
  final _frCtrl = TextEditingController();
  final _koCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  TranslateAssist? _assist;
  String? _assistError;
  // Captured at request time so the chips fill BOTH fields consistently,
  // regardless of what the fields hold when a chip is tapped.
  String _reqWord = '';
  bool _reqFromFr = true;

  @override
  void dispose() {
    _frCtrl.dispose();
    _koCtrl.dispose();
    super.dispose();
  }

  Future<void> _askAssistant() async {
    final fr = _frCtrl.text.trim();
    final ko = _koCtrl.text.trim();
    // Whichever side has text is the source; FR wins when both do.
    final fromFr = fr.isNotEmpty || ko.isEmpty;
    final word = fromFr ? fr : ko;
    if (word.isEmpty) return;
    _reqWord = word;
    _reqFromFr = fromFr;
    setState(() {
      _loading = true;
      _assist = null;
      _assistError = null;
    });
    final result = await ref.read(vocabAssistantProvider).translate(
          word: word,
          sourceLang: fromFr ? widget.langA : widget.langB,
          targetLang: fromFr ? widget.langB : widget.langA,
          existingWords: widget.existingSource,
        );
    if (!mounted) return;
    setState(() {
      _loading = false;
      result.fold(
        onSuccess: (a) => _assist = a,
        onFailure: (_) => _assistError = 'list_detail.ai_error'.tr(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('list_detail.add_dialog_title'.tr()),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                key: const ValueKey(WidgetKeys.addWordFr),
                controller: _frCtrl,
                autofocus: true,
                decoration: InputDecoration(
                    labelText: Languages.displayName(widget.langA),
                    prefixText: '${Languages.flagFor(widget.langA)}  '),
                textInputAction: TextInputAction.next,
                validator: (v) => (v?.trim().isEmpty ?? true) ? 'Requis' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey(WidgetKeys.addWordKo),
                controller: _koCtrl,
                decoration: InputDecoration(
                    labelText: Languages.displayName(widget.langB),
                    prefixText: '${Languages.flagFor(widget.langB)}  '),
                validator: (v) => (v?.trim().isEmpty ?? true) ? 'Requis' : null,
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: _loading
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 6),
                        child: SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : TextButton.icon(
                        key: const ValueKey(WidgetKeys.addWordAiSuggest),
                        onPressed: _askAssistant,
                        icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                        label: Text('list_detail.ai_translate'.tr()),
                      ),
              ),
              if (_assistError != null)
                Text(_assistError!,
                    style:
                        AppTextStyles.caption.copyWith(color: AppColors.rose)),
              if (_assist != null) ...[
                // Translation chips fill BOTH sides as a coherent pair
                // (source word → translation), shown FR → KO regardless of
                // which side was typed — tapping one never leaves a stale
                // 'optimized' word on the other side (bug 2026-07-14).
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final t in _assist!.translations)
                      ActionChip(
                        avatar: const Icon(Icons.translate_rounded, size: 14),
                        label: Text(_reqFromFr
                            ? '$_reqWord → ${t.display}'
                            : '${t.display} → $_reqWord'),
                        onPressed: () => setState(() {
                          if (_reqFromFr) {
                            _frCtrl.text = _reqWord;
                            _koCtrl.text = t.display;
                          } else {
                            _koCtrl.text = _reqWord;
                            _frCtrl.text = t.display;
                          }
                        }),
                      ),
                  ],
                ),
                if (_assist!.voiceFriendly.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 1),
                        child: Icon(Icons.mic_rounded,
                            size: 14, color: AppColors.clay),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text('list_detail.ai_voice_friendly'.tr(),
                            style: AppTextStyles.caption),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final p in _assist!.voiceFriendly)
                        ActionChip(
                          avatar: const Icon(Icons.mic_rounded, size: 14),
                          label: Text(_reqFromFr
                              ? '${p.source} → ${p.target}'
                              : '${p.target} → ${p.source}'),
                          // Voice-friendly pairs replace BOTH sides.
                          onPressed: () => setState(() {
                            if (_reqFromFr) {
                              _frCtrl.text = p.source;
                              _koCtrl.text = p.target;
                            } else {
                              _koCtrl.text = p.source;
                              _frCtrl.text = p.target;
                            }
                          }),
                        ),
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('common.cancel'.tr())),
        FilledButton(
          key: const ValueKey(WidgetKeys.addWordConfirm),
          onPressed: () async {
            if (!(_formKey.currentState?.validate() ?? false)) return;
            final ok =
                await widget.onSubmit(_frCtrl.text.trim(), _koCtrl.text.trim());
            if (context.mounted && ok) Navigator.pop(context);
            if (context.mounted && !ok) Navigator.pop(context);
          },
          child: Text('list_detail.add_confirm'.tr()),
        ),
      ],
    );
  }
}

/// Bottom sheet: AI-inferred theme + checkable new word pairs.
class _AiSuggestionsSheet extends ConsumerStatefulWidget {
  const _AiSuggestionsSheet({required this.existingPairs, required this.onAdd});
  final List<WordPairSuggestion> existingPairs;
  final Future<void> Function(List<WordPairSuggestion> selected) onAdd;

  @override
  ConsumerState<_AiSuggestionsSheet> createState() =>
      _AiSuggestionsSheetState();
}

class _AiSuggestionsSheetState extends ConsumerState<_AiSuggestionsSheet> {
  ThemedSuggestions? _result;
  String? _error;
  final _selected = <int>{};
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final result = await ref.read(vocabAssistantProvider).suggest(
          sourceLang: 'fr',
          targetLang: 'ko',
          existingPairs: widget.existingPairs,
        );
    if (!mounted) return;
    setState(() {
      result.fold(
        onSuccess: (r) {
          _result = r;
          _selected.addAll(List.generate(r.pairs.length, (i) => i));
        },
        onFailure: (_) => _error = 'list_detail.ai_error'.tr(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
        child: _error != null
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!,
                    style:
                        AppTextStyles.caption.copyWith(color: AppColors.rose)),
              )
            : _result == null
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'list_detail.ai_suggest_title'
                            .tr(namedArgs: {'theme': _result!.theme}),
                        style: AppTextStyles.sectionTitle,
                      ),
                      const SizedBox(height: 8),
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _result!.pairs.length,
                          itemBuilder: (ctx, i) {
                            final p = _result!.pairs[i];
                            return CheckboxListTile(
                              dense: true,
                              controlAffinity: ListTileControlAffinity.leading,
                              value: _selected.contains(i),
                              onChanged: (v) => setState(() {
                                if (v == true) {
                                  _selected.add(i);
                                } else {
                                  _selected.remove(i);
                                }
                              }),
                              title: Text('${p.source}  —  ${p.target}'),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _selected.isEmpty || _adding
                              ? null
                              : () async {
                                  setState(() => _adding = true);
                                  await widget.onAdd([
                                    for (final i in _selected)
                                      _result!.pairs[i],
                                  ]);
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                  }
                                },
                          child: Text(_adding
                              ? '…'
                              : 'list_detail.ai_add_selected'
                                  .tr(namedArgs: {'n': '${_selected.length}'})),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}

// ── Concept tile ──────────────────────────────────────────────────────────────

class _ConceptTile extends ConsumerWidget {
  const _ConceptTile({
    super.key,
    required this.concept,
    required this.listId,
    required this.editMode,
  });
  final dynamic concept;
  final String listId;
  final bool editMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final variantsAsync = ref.watch(variantsProvider(concept.id));

    return variantsAsync.when(
      loading: () => Container(
        margin: const EdgeInsets.only(bottom: 8),
        height: 64,
        decoration: BoxDecoration(
          color: cs.outline.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (variants) {
        final fr =
            variants.where((v) => v.langCode == 'fr' && !v.isDeleted).toList();
        final ko =
            variants.where((v) => v.langCode == 'ko' && !v.isDeleted).toList();
        final frWord = fr.isNotEmpty ? fr.first.word : '—';
        final koWord = ko.isNotEmpty ? ko.first.word : '—';

        Future<void> showEditDialog() async {
          if (fr.isEmpty || ko.isEmpty) return;
          final frCtrl = TextEditingController(text: frWord);
          final koCtrl = TextEditingController(text: koWord);
          final formKey = GlobalKey<FormState>();
          await showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text('list_detail.edit_dialog_title'.tr()),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      key: const ValueKey(WidgetKeys.editWordFr),
                      controller: frCtrl,
                      autofocus: true,
                      decoration: InputDecoration(
                          labelText: 'list_detail.field_french'.tr(),
                          prefixText: '🇫🇷  '),
                      textInputAction: TextInputAction.next,
                      validator: (v) =>
                          (v?.trim().isEmpty ?? true) ? 'Requis' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const ValueKey(WidgetKeys.editWordKo),
                      controller: koCtrl,
                      decoration: InputDecoration(
                          labelText: 'list_detail.field_korean'.tr(),
                          prefixText: '🇰🇷  '),
                      validator: (v) =>
                          (v?.trim().isEmpty ?? true) ? 'Requis' : null,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('common.cancel'.tr()),
                ),
                FilledButton(
                  key: const ValueKey(WidgetKeys.editWordConfirm),
                  onPressed: () async {
                    if (!(formKey.currentState?.validate() ?? false)) return;
                    await ref.read(listActionsProvider.notifier).updateVariants(
                          frVariant: fr.first,
                          newFrWord: frCtrl.text.trim(),
                          koVariant: ko.first,
                          newKoWord: koCtrl.text.trim(),
                        );
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: Text('list_detail.edit_confirm'.tr()),
                ),
              ],
            ),
          );
        }

        Future<void> confirmDelete() async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text('list_detail.delete_dialog_title'.tr()),
              content: Text('list_detail.delete_dialog_body'
                  .tr(namedArgs: {'wordA': frWord, 'wordB': koWord})),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text('common.cancel'.tr()),
                ),
                TextButton(
                  key: const ValueKey(WidgetKeys.deleteWordConfirm),
                  style: TextButton.styleFrom(foregroundColor: AppColors.rose),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text('common.delete'.tr(),
                      style: AppTextStyles.fig(14, FontWeight.w600)
                          .copyWith(color: AppColors.rose)),
                ),
              ],
            ),
          );
          if (confirmed == true) {
            ref.read(listActionsProvider.notifier).deleteConcept(concept.id);
          }
        }

        final tile = FrostedBox(
          borderRadius: BorderRadius.circular(16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Builder(builder: (ctx) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            final ink = isDark ? AppColors.onDark : AppColors.ink;
            return Row(
              children: [
                // French side
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('list_detail.lang_fr'.tr(),
                          style: AppTextStyles.eyebrowSm
                              .copyWith(color: AppColors.teal)),
                      const SizedBox(height: 2),
                      Text(frWord,
                          style: AppTextStyles.fig(15, FontWeight.w600)
                              .copyWith(color: ink),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                // Divider
                Container(
                  width: 1,
                  height: 36,
                  color: cs.outline,
                  margin: const EdgeInsets.symmetric(horizontal: 14),
                ),
                // Korean side
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('list_detail.lang_kr'.tr(),
                          style: AppTextStyles.eyebrowSm
                              .copyWith(color: AppColors.clay)),
                      const SizedBox(height: 2),
                      Text(koWord,
                          style: AppTextStyles.kr(16, FontWeight.w500)
                              .copyWith(color: ink),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                // Edit-mode action buttons
                if (editMode) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    key: ValueKey(WidgetKeys.conceptEditIcon(frWord)),
                    onTap: showEditDialog,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.edit_outlined,
                          color: AppColors.teal.withValues(alpha: 0.7),
                          size: 20),
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    key: ValueKey(WidgetKeys.conceptDeleteIcon(frWord)),
                    onTap: confirmDelete,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.delete_outline,
                          color: AppColors.rose.withValues(alpha: 0.6),
                          size: 20),
                    ),
                  ),
                ],
              ],
            );
          }),
        );

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: editMode
              ? GestureDetector(onTap: showEditDialog, child: tile)
              : tile,
        );
      },
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAddTap});
  final VoidCallback onAddTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final muted = isDark ? AppColors.onDarkMuted : AppColors.muted;
    final faint = isDark ? AppColors.onDarkFaint : AppColors.faint;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_stories_outlined, size: 56, color: faint),
            const SizedBox(height: 16),
            Text('list_detail.empty_title'.tr(),
                style: AppTextStyles.grotesk(20, FontWeight.w700)
                    .copyWith(color: cs.onSurface)),
            const SizedBox(height: 8),
            Text(
              'list_detail.empty_subtitle'.tr(),
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(color: muted),
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: onAddTap,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.clay,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('list_detail.empty_button'.tr(),
                    style: AppTextStyles.fig(15, FontWeight.w700)
                        .copyWith(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
