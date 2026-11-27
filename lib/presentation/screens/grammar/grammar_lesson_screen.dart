import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/languages.dart' show uiLocaleCode;
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widget_keys.dart';
import '../../../domain/entities/grammar_rule.dart';
import '../../providers/grammar/grammar_provider.dart';
import '../../providers/settings/default_pair_provider.dart';
import '../../widgets/dotted_ground.dart';
import '../../widgets/scroll_affordance.dart';

/// The non-graded reading leg of a grammar rule.
///
/// Existing rules render a concise legacy page from their authored explanation
/// and worked examples. Once a U7 content unit adds `lesson_pages`, the same
/// reader becomes a manually swipeable sequence without a route redesign.
class GrammarLessonScreen extends ConsumerWidget {
  const GrammarLessonScreen({required this.ruleId, super.key});

  final String ruleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pair = ref.watch(defaultPairProvider);
    final targetLang = pair.$2;
    final rulesAsync = ref.watch(grammarRulesProvider(targetLang));
    return Scaffold(
      key: const ValueKey(WidgetKeys.screenGrammarLesson),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: context.canPop()
            ? IconButton(
                tooltip: 'common.back'.tr(),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: () => context.pop(),
              )
            : null,
        title: Text('lesson.screen_title'.tr()),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DottedGround(),
          Positioned.fill(
            child: rulesAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(
                  color: AppColors.clay,
                  strokeWidth: 2,
                ),
              ),
              error: (_, _) => _UnavailableLesson(),
              data: (rules) {
                final matches = rules.where((rule) => rule.id == ruleId);
                return matches.isEmpty
                    ? _UnavailableLesson()
                    : _LessonReader(rule: matches.first, pair: pair);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _UnavailableLesson extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Text(
        'lesson.not_found'.tr(),
        textAlign: TextAlign.center,
        style: AppTextStyles.body.copyWith(color: AppColors.muted),
      ),
    ),
  );
}

class _LessonReader extends StatefulWidget {
  const _LessonReader({required this.rule, required this.pair});

  final GrammarRule rule;
  final (String, String) pair;

  @override
  State<_LessonReader> createState() => _LessonReaderState();
}

class _LessonReaderState extends State<_LessonReader> {
  late final PageController _controller;
  var _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = uiLocaleCode(context);
    final pages = _ReaderPage.fromRule(widget.rule, widget.pair.$1);
    final atLastPage = _index == pages.length - 1;

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenSize = MediaQuery.sizeOf(context);
        final compact =
            constraints.maxHeight < 400 ||
            MediaQuery.textScalerOf(context).scale(25) >= 37.5;
        final title = Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              widget.rule.title(locale),
              style: AppTextStyles.grotesk(25, FontWeight.w700),
            ),
          ),
        );
        final controls = Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Row(
            children: [
              SizedBox(
                width: 120,
                child: OutlinedButton(
                  onPressed: _index == 0
                      ? null
                      : () => _controller.previousPage(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
                        ),
                  child: Text('lesson.previous'.tr()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  key: atLastPage
                      ? const ValueKey(WidgetKeys.grammarLessonPractice)
                      : null,
                  onPressed: atLastPage
                      ? () => context.push(
                          Uri(
                            path: '/start-session-grammar',
                            queryParameters: {
                              'rule': widget.rule.id,
                              'langA': widget.pair.$1,
                              'langB': widget.pair.$2,
                            },
                          ).toString(),
                        )
                      : () => _controller.nextPage(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
                        ),
                  icon: Icon(
                    atLastPage
                        ? Icons.play_arrow_rounded
                        : Icons.arrow_forward_rounded,
                  ),
                  label: Text(
                    atLastPage ? 'lesson.practice'.tr() : 'lesson.next'.tr(),
                  ),
                ),
              ),
            ],
          ),
        );
        return SizedBox(
          width: constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : screenSize.width,
          height: constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : screenSize.height,
          child: Column(
            children: [
              if (!compact) title,
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: pages.length,
                  onPageChanged: (value) => setState(() => _index = value),
                  itemBuilder: (_, index) => compact
                      ? ScrollAffordance(
                          hint: 'lesson.scroll_hint'.tr(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              title,
                              _LessonPage(
                                page: pages[index],
                                scrollable: false,
                              ),
                              controls,
                            ],
                          ),
                        )
                      : _LessonPage(page: pages[index]),
                ),
              ),
              if (!compact) controls,
            ],
          ),
        );
      },
    );
  }
}

class _LessonPage extends StatelessWidget {
  const _LessonPage({required this.page, this.scrollable = true});

  final _ReaderPage page;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(page.text, style: AppTextStyles.body.copyWith(height: 1.55)),
        for (final example in page.examples) ...[
          const SizedBox(height: 20),
          _TappableExample(example: example),
        ],
      ],
    );
    const padding = EdgeInsets.fromLTRB(20, 4, 20, 28);
    return scrollable
        ? ScrollAffordance(
            hint: 'lesson.scroll_hint'.tr(),
            padding: padding,
            child: content,
          )
        : Padding(padding: padding, child: content);
  }
}

class _TappableExample extends StatelessWidget {
  const _TappableExample({required this.example});

  final _ReaderExample example;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: 'lesson.example_open'.tr(),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showContext(context),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.clay.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.clay.withValues(alpha: 0.38)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('lesson.example_label'.tr(), style: AppTextStyles.eyebrow),
              const SizedBox(height: 6),
              Text(
                example.target,
                style: AppTextStyles.grotesk(21, FontWeight.w700),
              ),
              const SizedBox(height: 5),
              Text(
                example.translation,
                style: AppTextStyles.body.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.open_in_new_rounded,
                    size: 15,
                    color: cs.onSurface,
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      'lesson.example_open'.tr(),
                      style: AppTextStyles.caption.copyWith(
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showContext(BuildContext context) => showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: SizedBox(
        width: 440,
        child: ScrollAffordance(
          hint: 'lesson.scroll_hint'.tr(),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                namesRoute: true,
                child: Text(
                  example.target,
                  style: Theme.of(dialogContext).textTheme.headlineSmall,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'lesson.translation_label'.tr(),
                style: AppTextStyles.eyebrow,
              ),
              const SizedBox(height: 5),
              Text(example.translation, style: AppTextStyles.body),
              if (example.detail.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(example.detail, style: AppTextStyles.body),
              ],
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text('common.close'.tr()),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ReaderPage {
  const _ReaderPage({required this.text, this.examples = const []});

  final String text;
  final List<_ReaderExample> examples;

  static List<_ReaderPage> fromRule(GrammarRule rule, String locale) {
    if (rule.lessonPages.isNotEmpty) {
      return [
        for (final page in rule.lessonPages)
          _ReaderPage(
            text: page.text(locale),
            examples: page.example == null
                ? const []
                : [
                    _ReaderExample(
                      target: page.example!.target,
                      translation: page.example!.translation(locale),
                      detail: page.example!.detail(locale),
                    ),
                  ],
          ),
      ];
    }

    return [
      _ReaderPage(
        text: rule.explanation(locale),
        examples: [
          for (final example in rule.workedExamples)
            _ReaderExample(
              target: example.target,
              translation: example.translation(locale),
            ),
        ],
      ),
    ];
  }
}

class _ReaderExample {
  const _ReaderExample({
    required this.target,
    required this.translation,
    this.detail = '',
  });

  final String target;
  final String translation;
  final String detail;
}
