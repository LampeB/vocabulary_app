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
import '../../../core/theme/v3_colors.dart';
import '../../../core/widget_keys.dart';
import '../../../domain/entities/concept.dart';
import '../../../domain/entities/vocabulary_list.dart';
import '../../../domain/entities/word_variant.dart';
import '../../../domain/repositories/vocabulary_repository.dart';
import '../../navigation/shell_route_visibility.dart';
import '../../providers/auth/auth_provider.dart';
import '../../widgets/scroll_affordance.dart';
import '../../widgets/v3_pond.dart';
import '../../providers/lists/vocab_assistant_provider.dart';
import '../../../data/datasources/remote/vocab_assistant_datasource.dart';
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

  VocabularyList? _confirmedList(AsyncValue<VocabularyList?> info) =>
      info.isLoading ? null : info.asData?.value;

  @override
  Widget build(BuildContext context) {
    final infoProvider = listInfoProvider(widget.listId);
    final listAsync = ref.watch(infoProvider);
    final list = _confirmedList(listAsync);
    final conceptsAsync = ref.watch(listDetailProvider(widget.listId));
    final dark = Theme.of(context).brightness == Brightness.dark;
    final foreground = dark ? V3Colors.light : V3Colors.ink;
    final muted = dark ? V3Colors.light70 : V3Colors.ink60;
    final surface = dark ? V3Colors.block : V3Colors.paper2;

    return Scaffold(
      key: const ValueKey(WidgetKeys.screenListDetail),
      backgroundColor: dark ? V3Colors.app : V3Colors.paper,
      appBar: AppBar(
        backgroundColor: dark ? V3Colors.app : V3Colors.paper,
        surfaceTintColor: Colors.transparent,
        foregroundColor: foreground,
        elevation: 0,
        leading: IconButton(
          key: const ValueKey(WidgetKeys.listDetailBack),
          tooltip: 'common.back'.tr(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/lists');
            }
          },
        ),
        actions: _editMode
            ? [
                TextButton(
                  onPressed: () => setState(() => _editMode = false),
                  child: Text(
                    'list_detail.action_done'.tr(),
                    style: AppTextStyles.fig(14, FontWeight.w600).copyWith(
                      color: dark ? V3Colors.amber : V3Colors.terraInk,
                    ),
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
                      enabled: list != null,
                      value: 'edit',
                      child: Row(
                        children: [
                          const Icon(Icons.edit_outlined, size: 18),
                          const SizedBox(width: 12),
                          // Flexible: the popup caps its width (~256 on 360dp
                          // screens) and long FR labels overflow otherwise.
                          Flexible(
                            child: Text(
                              'list_detail.menu_edit'.tr(),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      key: const ValueKey(WidgetKeys.listDetailAiSuggestItem),
                      enabled: list != null,
                      value: 'ai_suggest',
                      child: Row(
                        children: [
                          const Icon(Icons.auto_awesome_rounded, size: 18),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              'list_detail.menu_ai_suggest'.tr(),
                              overflow: TextOverflow.ellipsis,
                            ),
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
                            child: Text(
                              'list_detail.menu_export'.tr(),
                              overflow: TextOverflow.ellipsis,
                            ),
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
          const Positioned.fill(child: V3Pond(animate: false)),
          CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'list_detail.kind'.tr(),
                        style: AppTextStyles.mono(
                          10,
                          FontWeight.w700,
                        ).copyWith(color: muted, letterSpacing: 1.2),
                      ),
                      Text(
                        listAsync.valueOrNull?.name ??
                            'list_detail.appbar_fallback'.tr(),
                        style: AppTextStyles.serif(
                          24,
                          FontWeight.w400,
                        ).copyWith(color: foreground),
                      ),
                    ],
                  ),
                ),
              ),
              if (list == null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: listAsync.isLoading
                        ? const CircularProgressIndicator(color: V3Colors.terra)
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('common.error'.tr()),
                              TextButton(
                                onPressed: () => ref.invalidate(infoProvider),
                                child: Text('common.retry'.tr()),
                              ),
                            ],
                          ),
                  ),
                )
              else
                conceptsAsync.when(
                  loading: () => const SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(
                        color: V3Colors.terra,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                  error: (e, _) => SliverFillRemaining(
                    child: Center(
                      child: Text(
                        '$e',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.rose,
                        ),
                      ),
                    ),
                  ),
                  data: (concepts) => concepts.isEmpty
                      ? SliverFillRemaining(
                          hasScrollBody: false,
                          child: _EmptyState(
                            onAddTap: () => _showAddWordDialog(context),
                          ),
                        )
                      : SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          sliver: SliverList.builder(
                            itemCount: concepts.length,
                            itemBuilder: (ctx, i) => _ConceptTile(
                              key: Key(concepts[i].id),
                              concept: concepts[i],
                              langA: list.langA,
                              langB: list.langB,
                              editMode: _editMode,
                              onEdit: (a, b) =>
                                  _showEditWordDialog(context, a, b),
                            ),
                          ),
                        ),
                ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: list == null
          ? null
          : DecoratedBox(
              decoration: BoxDecoration(
                color: surface,
                border: Border(
                  top: BorderSide(
                    color: dark ? V3Colors.ruleDark : V3Colors.edgeWarm2,
                  ),
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: _studyAndEditBar(context, list),
                ),
              ),
            ),
    );
  }

  // ── Bottom bar ──────────────────────────────────────────────────────────

  /// A prerequisite list must lead somewhere concrete. The primary action
  /// starts an immediate flashcard run; editing remains available alongside
  /// it instead of forcing a learner through the generic setup accordion.
  Widget _studyAndEditBar(BuildContext context, VocabularyList list) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final outline = dark ? V3Colors.ruleDark : V3Colors.edgeWarm2;
    final icon = dark ? V3Colors.light : V3Colors.ink;
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: V3Colors.terra,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              minimumSize: const Size.fromHeight(52),
            ),
            onPressed: () => context.push(
              '/quiz',
              extra: QuizArgs(
                listId: list.id,
                source: QuizSource.list,
                mode: QuizMode.flashcard,
                direction: QuizDirectionChoice.both,
                cardLimit: 10,
                langA: list.langA,
                langB: list.langB,
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
            style: OutlinedButton.styleFrom(
              foregroundColor: icon,
              backgroundColor: dark ? V3Colors.block : V3Colors.paper2,
              side: BorderSide(color: outline),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            key: const ValueKey(WidgetKeys.listDetailHandsFree),
            onPressed: () => context.push(
              '/quiz',
              extra: QuizArgs(
                listId: list.id,
                source: QuizSource.list,
                mode: QuizMode.handsFree,
                direction: QuizDirectionChoice.both,
                cardLimit: 10,
                langA: list.langA,
                langB: list.langB,
              ),
            ),
            child: Icon(
              Icons.headset_mic_rounded,
              semanticLabel: 'quiz_setup.mode_hands_free_label'.tr(),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 52,
          height: 52,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: icon,
              backgroundColor: dark ? V3Colors.block : V3Colors.paper2,
              side: BorderSide(color: outline),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            key: const ValueKey(WidgetKeys.listDetailAddWord),
            onPressed: () => _showAddWordDialog(context),
            child: Icon(
              Icons.add,
              semanticLabel: 'list_detail.add_word_bar'.tr(),
            ),
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

  bool _isCurrentForm(String listId, VocabularyRepository repository) =>
      mounted &&
      widget.listId == listId &&
      identical(ref.read(vocabularyRepositoryProvider), repository);

  bool _canSuggest(
    VocabularyList list,
    VocabularyRepository repository,
    Object sessionToken,
  ) {
    if (!_isCurrentForm(list.id, repository) ||
        !identical(ref.read(authSessionIdentityProvider).token, sessionToken)) {
      return false;
    }
    final latest = _confirmedList(ref.read(listInfoProvider(list.id)));
    return (latest?.langA, latest?.langB) == (list.langA, list.langB);
  }

  Future<void> _showAddWordDialog(BuildContext context) async {
    final listId = widget.listId;
    final list = _confirmedList(ref.read(listInfoProvider(listId)));
    if (list == null) return;
    final repository = ref.read(vocabularyRepositoryProvider);
    final sessionToken = ref.read(authSessionIdentityProvider).token;

    final failure = await showDialog<AppException>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _WordPairDialog(
        listId: listId,
        langA: list.langA,
        langB: list.langB,
        canTranslate: () => _canSuggest(list, repository, sessionToken),
        onSubmit: (wordA, wordB) async {
          if (!_isCurrentForm(listId, repository)) {
            return const PermissionException();
          }
          final result = await ref
              .read(listActionsProvider.notifier)
              .addConcept(
                listId: listId,
                wordA: wordA,
                wordB: wordB,
                expectedPair: (list.langA, list.langB),
              );
          return result.exceptionOrNull;
        },
      ),
    );

    if (failure is QuotaExceededException &&
        context.mounted &&
        _isCurrentForm(listId, repository)) {
      context.push('/paywall');
    }
  }

  Future<void> _showEditWordDialog(
    BuildContext context,
    WordVariant variantA,
    WordVariant variantB,
  ) async {
    final listId = widget.listId;
    final list = _confirmedList(ref.read(listInfoProvider(listId)));
    if (list == null ||
        (list.langA, list.langB) != (variantA.langCode, variantB.langCode)) {
      return;
    }
    final repository = ref.read(vocabularyRepositoryProvider);
    await showDialog<AppException>(
      context: context,
      builder: (ctx) => _WordPairDialog(
        listId: listId,
        langA: list.langA,
        langB: list.langB,
        originalWords: (variantA.word, variantB.word),
        onSubmit: (wordA, wordB) async {
          if (!_isCurrentForm(listId, repository)) {
            return const PermissionException();
          }
          final result = await ref
              .read(listActionsProvider.notifier)
              .updateVariants(
                listId: listId,
                variantA: variantA,
                variantB: variantB,
                wordA: wordA,
                wordB: wordB,
              );
          return result.exceptionOrNull;
        },
      ),
    );
  }

  /// Themed AI suggestions: infer the list's theme from its pairs, propose
  /// new words, add the checked ones (user request 2026-07-11).
  Future<void> _showAiSuggestionsSheet(BuildContext context) async {
    final listId = widget.listId;
    final list = _confirmedList(ref.read(listInfoProvider(listId)));
    if (list == null) return;
    final repository = ref.read(vocabularyRepositoryProvider);
    final sessionToken = ref.read(authSessionIdentityProvider).token;
    final actions = ref.read(listActionsProvider.notifier);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _AiSuggestionsSheet(
        listId: listId,
        langA: list.langA,
        langB: list.langB,
        canSuggest: () => _canSuggest(list, repository, sessionToken),
        onQuota: () {
          if (context.mounted && _isCurrentForm(listId, repository)) {
            context.push('/paywall');
          }
        },
        onAdd: (selected) async {
          final added = <WordPairSuggestion>[];
          for (final p in selected) {
            try {
              if (!_isCurrentForm(listId, repository)) {
                return (added: added, error: const PermissionException());
              }
              final result = await actions.addConcept(
                listId: listId,
                wordA: p.source,
                wordB: p.target,
                expectedPair: (list.langA, list.langB),
              );
              if (result.isFailure) {
                return (added: added, error: result.exceptionOrNull);
              }
              added.add(p);
            } catch (_) {
              return (added: added, error: const UnknownException());
            }
          }
          return (added: added, error: null);
        },
      ),
    );
  }
}

/// Delivers a pending result only while its own modal is topmost. The route
/// dependency rebuilds this widget when an overlay above the modal leaves.
class _WhenRouteCurrent extends StatelessWidget {
  const _WhenRouteCurrent({required this.onCurrent, required this.child});

  final VoidCallback? onCurrent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final callback = onCurrent;
    final route = ModalRoute.of(context);
    final shellRoute = ShellRouteVisibility.routeOf(context);
    if (callback != null &&
        route != null &&
        route.isCurrent &&
        (shellRoute?.isCurrent ?? true)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted &&
            route.isCurrent &&
            (shellRoute?.isCurrent ?? true)) {
          callback();
        }
      });
    }
    return child;
  }
}

/// Add-word dialog with AI assistance: type one side, get translation
/// suggestions (+ voice-friendly longer forms for short words) as tappable
/// chips. The manual flow is unchanged — AI is one optional button.
class _WordPairDialog extends ConsumerStatefulWidget {
  const _WordPairDialog({
    required this.listId,
    required this.langA,
    required this.langB,
    this.canTranslate,
    this.originalWords,
    required this.onSubmit,
  });

  /// The list's language pair — drives field labels/flags and the assistant's
  /// translation direction (generic-language-pairs epic; was fr/ko-hardcoded).
  final String langA;
  final String langB;
  final String listId;
  final bool Function()? canTranslate;
  final (String, String)? originalWords;
  final Future<AppException?> Function(String wordA, String wordB) onSubmit;

  @override
  ConsumerState<_WordPairDialog> createState() => _WordPairDialogState();
}

class _WordPairDialogState extends ConsumerState<_WordPairDialog> {
  late final _wordACtrl = TextEditingController(text: widget.originalWords?.$1);
  late final _wordBCtrl = TextEditingController(text: widget.originalWords?.$2);
  final _formKey = GlobalKey<FormState>();
  bool get _editing => widget.originalWords != null;
  bool _loading = false;
  bool _saving = false;
  Result<void>? _saveResult;
  String? _saveError;
  TranslateAssist? _assist;
  String? _assistError;
  // Captured at request time so the chips fill BOTH fields consistently,
  // regardless of what the fields hold when a chip is tapped.
  String _reqWord = '';
  bool _reqFromA = true;

  @override
  void dispose() {
    _wordACtrl.dispose();
    _wordBCtrl.dispose();
    super.dispose();
  }

  Future<void> _askAssistant() async {
    final canTranslate = widget.canTranslate;
    if (_saving || _loading || canTranslate == null) return;
    final a = _wordACtrl.text.trim();
    final b = _wordBCtrl.text.trim();
    // Translate from the first filled side.
    final fromA = a.isNotEmpty || b.isEmpty;
    final word = fromA ? a : b;
    if (word.isEmpty) return;
    final route = ModalRoute.of(context);
    _reqWord = word;
    _reqFromA = fromA;
    setState(() {
      _loading = true;
      _assist = null;
      _assistError = null;
    });
    Result<TranslateAssist> result;
    try {
      final pairs = canTranslate()
          ? await ref
                .read(listActionsProvider.notifier)
                .getSuggestionContext(
                  widget.listId,
                  expectedPair: (widget.langA, widget.langB),
                )
          : null;
      if (!mounted || route?.isActive != true) return;
      result = pairs == null || !canTranslate()
          ? const Failure(PermissionException())
          : await ref
                .read(vocabAssistantProvider)
                .translate(
                  word: word,
                  sourceLang: fromA ? widget.langA : widget.langB,
                  targetLang: fromA ? widget.langB : widget.langA,
                  existingWords: [
                    for (final pair in pairs) fromA ? pair.source : pair.target,
                  ],
                );
    } catch (_) {
      result = const Failure(UnknownException());
    }
    if (!mounted || route?.isActive != true) return;
    setState(() {
      _loading = false;
      if (!canTranslate() || result.exceptionOrNull is PermissionException) {
        _assistError = 'list_detail.word_pair_changed'.tr();
        return;
      }
      result.fold(
        onSuccess: (a) => _assist = a,
        onFailure: (_) => _assistError = 'list_detail.ai_error'.tr(),
      );
    });
  }

  void _applySuggestion(String source, String target) {
    if (_saving) return;
    setState(() {
      _wordACtrl.text = _reqFromA ? source : target;
      _wordBCtrl.text = _reqFromA ? target : source;
    });
  }

  Future<void> _submit() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    AppException? failure;
    try {
      failure = await widget.onSubmit(
        _wordACtrl.text.trim(),
        _wordBCtrl.text.trim(),
      );
    } catch (_) {
      failure = const UnknownException();
    }
    if (!mounted) return;
    setState(
      () => _saveResult = failure == null
          ? const Success(null)
          : Failure(failure),
    );
  }

  void _consumeSaveResult() {
    final result = _saveResult;
    if (result == null) return;
    _saveResult = null;
    final failure = result.exceptionOrNull;
    if (failure == null || failure is QuotaExceededException) {
      Navigator.pop(context, failure);
      return;
    }
    _showSaveError(failure);
  }

  void _showSaveError(AppException failure) => setState(() {
    _saving = false;
    _saveError = switch (failure) {
      ValidationException() ||
      PermissionException() ||
      NotFoundException() => 'list_detail.word_pair_changed',
      _ => 'common.error',
    };
  });

  String? _requireWord(String? input) =>
      (input?.trim().isEmpty ?? true) ? 'common.required'.tr() : null;

  @override
  Widget build(BuildContext context) {
    return _WhenRouteCurrent(
      onCurrent: _saveResult == null ? null : _consumeSaveResult,
      child: _buildDialog(context),
    );
  }

  Widget _buildDialog(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: SizedBox(
        width: 400,
        child: ScrollAffordance(
          hint: 'v3.scroll_hint'.tr(),
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  (_editing
                          ? 'list_detail.edit_dialog_title'
                          : 'list_detail.add_dialog_title')
                      .tr(),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: ValueKey(
                    _editing ? WidgetKeys.editWordFr : WidgetKeys.addWordFr,
                  ),
                  controller: _wordACtrl,
                  readOnly: _saving,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: Languages.displayName(widget.langA),
                    prefixText: '${Languages.flagFor(widget.langA)}  ',
                  ),
                  textInputAction: TextInputAction.next,
                  validator: _requireWord,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: ValueKey(
                    _editing ? WidgetKeys.editWordKo : WidgetKeys.addWordKo,
                  ),
                  controller: _wordBCtrl,
                  readOnly: _saving,
                  decoration: InputDecoration(
                    labelText: Languages.displayName(widget.langB),
                    prefixText: '${Languages.flagFor(widget.langB)}  ',
                  ),
                  validator: _requireWord,
                ),
                if (!_editing) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _loading
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 6),
                            child: SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : TextButton.icon(
                            key: const ValueKey(WidgetKeys.addWordAiSuggest),
                            onPressed: _saving ? null : _askAssistant,
                            icon: const Icon(
                              Icons.auto_awesome_rounded,
                              size: 16,
                            ),
                            label: Text('list_detail.ai_translate'.tr()),
                          ),
                  ),
                  if (_assistError != null)
                    Text(
                      _assistError!,
                      style: AppTextStyles.caption.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  if (_assist != null) ...[
                    // Translation chips fill BOTH sides as a coherent pair
                    // (source word → translation), in list order regardless of
                    // which side was typed — tapping one never leaves a stale
                    // 'optimized' word on the other side (bug 2026-07-14).
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final t in _assist!.translations)
                          ActionChip(
                            avatar: const Icon(
                              Icons.translate_rounded,
                              size: 14,
                            ),
                            label: Text(
                              _reqFromA
                                  ? '$_reqWord → ${t.display}'
                                  : '${t.display} → $_reqWord',
                            ),
                            onPressed: _saving
                                ? null
                                : () => _applySuggestion(_reqWord, t.display),
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
                            child: Icon(
                              Icons.mic_rounded,
                              size: 14,
                              color: AppColors.clay,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'list_detail.ai_voice_friendly'.tr(),
                              style: AppTextStyles.caption,
                            ),
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
                              label: Text(
                                _reqFromA
                                    ? '${p.source} → ${p.target}'
                                    : '${p.target} → ${p.source}',
                              ),
                              // Voice-friendly pairs replace BOTH sides.
                              onPressed: _saving
                                  ? null
                                  : () => _applySuggestion(p.source, p.target),
                            ),
                        ],
                      ),
                    ],
                  ],
                ],
                if (_saveError case final error?) ...[
                  const SizedBox(height: 12),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      error.tr(),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.pop(context),
                        child: Text('common.cancel'.tr()),
                      ),
                      FilledButton(
                        key: ValueKey(
                          _editing
                              ? WidgetKeys.editWordConfirm
                              : WidgetKeys.addWordConfirm,
                        ),
                        onPressed: _saving ? null : _submit,
                        child: Text(
                          (_editing
                                  ? 'list_detail.edit_confirm'
                                  : 'list_detail.add_confirm')
                              .tr(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

typedef _SuggestionAddResult = ({
  List<WordPairSuggestion> added,
  AppException? error,
});

class _AiSuggestionsSheet extends ConsumerStatefulWidget {
  const _AiSuggestionsSheet({
    required this.listId,
    required this.langA,
    required this.langB,
    required this.canSuggest,
    required this.onAdd,
    required this.onQuota,
  });
  final String listId;
  final String langA, langB;
  final bool Function() canSuggest;
  final Future<_SuggestionAddResult> Function(List<WordPairSuggestion> selected)
  onAdd;
  final VoidCallback onQuota;

  @override
  ConsumerState<_AiSuggestionsSheet> createState() =>
      _AiSuggestionsSheetState();
}

class _AiSuggestionsSheetState extends ConsumerState<_AiSuggestionsSheet> {
  ThemedSuggestions? _result;
  String? _error;
  final _selected = <int>{};
  final _added = <int>{};
  AppException? _addError;
  _SuggestionAddResult? _addResult;
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fetch();
    });
  }

  Future<void> _fetch() async {
    final route = ModalRoute.of(context);
    Result<ThemedSuggestions> result;
    try {
      final pairs = widget.canSuggest()
          ? await ref
                .read(listActionsProvider.notifier)
                .getSuggestionContext(
                  widget.listId,
                  expectedPair: (widget.langA, widget.langB),
                )
          : null;
      if (!mounted || route?.isActive != true) return;
      result = pairs == null || !widget.canSuggest()
          ? const Failure(PermissionException())
          : await ref
                .read(vocabAssistantProvider)
                .suggest(
                  sourceLang: widget.langA,
                  targetLang: widget.langB,
                  existingPairs: pairs,
                );
    } catch (_) {
      result = const Failure(UnknownException());
    }
    if (!mounted || route?.isActive != true) return;
    setState(() {
      if (!widget.canSuggest() ||
          result.exceptionOrNull is PermissionException) {
        _error = 'list_detail.word_pair_changed'.tr();
        return;
      }
      result.fold(
        onSuccess: (r) {
          _result = r;
          _selected.addAll(List.generate(r.pairs.length, (i) => i));
        },
        onFailure: (_) => _error = 'list_detail.ai_error'.tr(),
      );
    });
  }

  Future<void> _addSelected() async {
    if (_adding || _selected.isEmpty) return;
    setState(() => _adding = true);
    final result = await widget.onAdd([
      for (final i in _selected) _result!.pairs[i],
    ]);
    if (!mounted) return;
    setState(() => _addResult = result);
  }

  void _consumeAddResult() {
    final result = _addResult;
    if (result == null) return;
    _addResult = null;
    setState(() {
      _adding = false;
      _addError = result.error;
      final completed = _selected
          .where((i) => result.added.contains(_result!.pairs[i]))
          .toList();
      _added.addAll(completed);
      _selected.removeAll(completed);
    });
    if (result.error == null && _selected.isEmpty) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return _WhenRouteCurrent(
      onCurrent: _addResult == null ? null : _consumeAddResult,
      child: _buildSheet(),
    );
  }

  Widget _buildSheet() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
        child: _error != null
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _error!,
                  style: AppTextStyles.caption.copyWith(color: AppColors.rose),
                ),
              )
            : _result == null
            ? const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'list_detail.ai_suggest_title'.tr(
                      namedArgs: {'theme': _result!.theme},
                    ),
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
                          value: _selected.contains(i) || _added.contains(i),
                          subtitle: _added.contains(i)
                              ? Text('list_detail.ai_added'.tr())
                              : null,
                          onChanged: _adding || _added.contains(i)
                              ? null
                              : (v) => setState(() {
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
                  if (_addError != null) ...[
                    Text(
                      'list_detail.ai_add_partial'.tr(
                        namedArgs: {
                          'added': '${_added.length}',
                          'remaining': '${_selected.length}',
                        },
                      ),
                      style: AppTextStyles.caption,
                    ),
                    Text(
                      (_addError is QuotaExceededException
                              ? 'list_detail.ai_add_quota'
                              : 'list_detail.ai_add_error')
                          .tr(),
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.rose,
                      ),
                    ),
                    if (_addError is QuotaExceededException)
                      TextButton(
                        onPressed: _adding ? null : widget.onQuota,
                        child: Text('profile.upgrade_button'.tr()),
                      ),
                  ],
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      key: const ValueKey(WidgetKeys.listDetailAiAddSelected),
                      onPressed: _selected.isEmpty || _adding
                          ? null
                          : _addSelected,
                      child: Text(
                        _adding
                            ? '…'
                            : 'list_detail.ai_add_selected'.tr(
                                namedArgs: {'n': '${_selected.length}'},
                              ),
                      ),
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
    required this.langA,
    required this.langB,
    required this.editMode,
    required this.onEdit,
  });
  final Concept concept;
  final String langA, langB;
  final bool editMode;
  final void Function(WordVariant, WordVariant) onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surface = dark ? V3Colors.block2 : V3Colors.paper3;
    final ink = dark ? V3Colors.light : V3Colors.ink;
    final rule = dark ? V3Colors.ruleDark : V3Colors.edgeWarm2;
    final variantsAsync = ref.watch(variantsProvider(concept.id));

    return variantsAsync.when(
      loading: () => Container(
        margin: const EdgeInsets.only(bottom: 8),
        height: 64,
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (variants) {
        final fr = variants
            .where((v) => v.langCode == langA && !v.isDeleted)
            .toList();
        final ko = variants
            .where((v) => v.langCode == langB && !v.isDeleted)
            .toList();
        final frWord = fr.isNotEmpty ? fr.first.word : '—';
        final koWord = ko.isNotEmpty ? ko.first.word : '—';

        final VoidCallback? edit = editMode && fr.isNotEmpty && ko.isNotEmpty
            ? () => onEdit(fr.first, ko.first)
            : null;

        Future<void> confirmDelete() async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text('list_detail.delete_dialog_title'.tr()),
              content: Text(
                'list_detail.delete_dialog_body'.tr(
                  namedArgs: {'wordA': frWord, 'wordB': koWord},
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text('common.cancel'.tr()),
                ),
                TextButton(
                  key: const ValueKey(WidgetKeys.deleteWordConfirm),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(ctx).colorScheme.error,
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(
                    'common.delete'.tr(),
                    style: AppTextStyles.fig(14, FontWeight.w600),
                  ),
                ),
              ],
            ),
          );
          if (confirmed == true) {
            ref.read(listActionsProvider.notifier).deleteConcept(concept.id);
          }
        }

        final tile = Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: rule),
          ),
          child: Row(
            children: [
              // French side
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Languages.displayName(langA),
                      style: AppTextStyles.eyebrowSm.copyWith(
                        color: dark ? AppColors.tealDark : V3Colors.ink60,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      frWord,
                      style:
                          (Languages.usesHangul(langA)
                                  ? AppTextStyles.kr(15, FontWeight.w600)
                                  : AppTextStyles.fig(15, FontWeight.w600))
                              .copyWith(color: ink),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Divider
              Container(
                width: 1,
                height: 36,
                color: rule,
                margin: const EdgeInsets.symmetric(horizontal: 14),
              ),
              // Korean side
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Languages.displayName(langB),
                      style: AppTextStyles.eyebrowSm.copyWith(
                        color: dark ? AppColors.clayDark : AppColors.clayText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      koWord,
                      style:
                          (Languages.usesHangul(langB)
                                  ? AppTextStyles.kr(16, FontWeight.w500)
                                  : AppTextStyles.fig(16, FontWeight.w500))
                              .copyWith(color: ink),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Edit-mode action buttons
              if (editMode) ...[
                if (edit != null)
                  IconButton(
                    key: ValueKey(WidgetKeys.conceptEditIcon(frWord)),
                    tooltip: 'list_detail.edit_word_action'.tr(
                      namedArgs: {'word': frWord},
                    ),
                    style: IconButton.styleFrom(
                      minimumSize: const Size.square(48),
                      visualDensity: VisualDensity.standard,
                      foregroundColor: ink,
                    ),
                    onPressed: edit,
                    icon: const Icon(Icons.edit_outlined, size: 20),
                  ),
                IconButton(
                  key: ValueKey(WidgetKeys.conceptDeleteIcon(frWord)),
                  tooltip: 'list_detail.delete_word_action'.tr(
                    namedArgs: {'word': fr.isEmpty ? koWord : frWord},
                  ),
                  style: IconButton.styleFrom(
                    minimumSize: const Size.square(48),
                    visualDensity: VisualDensity.standard,
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  onPressed: confirmDelete,
                  icon: const Icon(Icons.delete_outline, size: 20),
                ),
              ],
            ],
          ),
        );

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: edit == null
              ? tile
              : GestureDetector(
                  onTap: edit,
                  excludeFromSemantics: true,
                  child: tile,
                ),
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
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? V3Colors.light : V3Colors.ink;
    final muted = dark ? V3Colors.light70 : V3Colors.ink60;
    final faint = dark ? V3Colors.moss : V3Colors.edgeWarm2;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_stories_outlined, size: 56, color: faint),
            const SizedBox(height: 16),
            Text(
              'list_detail.empty_title'.tr(),
              style: AppTextStyles.grotesk(
                20,
                FontWeight.w700,
              ).copyWith(color: ink),
            ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: V3Colors.terra,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'list_detail.empty_button'.tr(),
                  style: AppTextStyles.fig(
                    15,
                    FontWeight.w700,
                  ).copyWith(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
