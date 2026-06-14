import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/lists/vocabulary_provider.dart';
import '../../../core/theme/app_colors.dart';

class ListDetailScreen extends ConsumerWidget {
  const ListDetailScreen({super.key, required this.listId});
  final String listId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(listInfoProvider(listId));
    final conceptsAsync = ref.watch(listDetailProvider(listId));
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: listAsync.when(
          data: (l) => Text(l?.name ?? 'List'),
          loading: () => const Text('...'),
          error: (_, __) => const Text('List'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.play_arrow),
            tooltip: 'Study',
            onPressed: () => context.go('/lists/$listId/quiz-setup'),
          ),
        ],
      ),
      body: conceptsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (concepts) => concepts.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.menu_book_outlined,
                        size: 64, color: AppColors.grey300),
                    const SizedBox(height: 16),
                    Text('No words yet',
                        style: tt.titleMedium
                            ?.copyWith(color: AppColors.grey500)),
                    const SizedBox(height: 8),
                    const Text('Tap + to add a word pair',
                        style: TextStyle(color: AppColors.grey500)),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                itemCount: concepts.length,
                itemBuilder: (ctx, i) {
                  final concept = concepts[i];
                  return _ConceptTile(
                    key: Key(concept.id),
                    concept: concept,
                    listId: listId,
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddWordDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add Word'),
      ),
    );
  }

  Future<void> _showAddWordDialog(BuildContext context, WidgetRef ref) async {
    final frCtrl = TextEditingController();
    final koCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Word'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: frCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                    labelText: 'French', prefixText: '🇫🇷 '),
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    (v?.trim().isEmpty ?? true) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: koCtrl,
                decoration: const InputDecoration(
                    labelText: 'Korean', prefixText: '🇰🇷 '),
                validator: (v) =>
                    (v?.trim().isEmpty ?? true) ? 'Required' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (!(formKey.currentState?.validate() ?? false)) return;
              await ref.read(listActionsProvider.notifier).addConcept(
                    listId: listId,
                    frWord: frCtrl.text.trim(),
                    koWord: koCtrl.text.trim(),
                  );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class _ConceptTile extends ConsumerWidget {
  const _ConceptTile({super.key, required this.concept, required this.listId});
  final dynamic concept;
  final String listId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final variantsAsync = ref.watch(variantsProvider(concept.id));
    final tt = Theme.of(context).textTheme;

    return variantsAsync.when(
      loading: () => const Card(
          margin: EdgeInsets.only(bottom: 8),
          child: Padding(
              padding: EdgeInsets.all(16),
              child: LinearProgressIndicator())),
      error: (_, __) => const SizedBox.shrink(),
      data: (variants) {
        final fr =
            variants.where((v) => v.langCode == 'fr' && !v.isDeleted).toList();
        final ko =
            variants.where((v) => v.langCode == 'ko' && !v.isDeleted).toList();
        final frWord = fr.isNotEmpty ? fr.first.word : '—';
        final koWord = ko.isNotEmpty ? ko.first.word : '—';

        return Dismissible(
          key: Key(concept.id),
          direction: DismissDirection.endToStart,
          background: Container(
            margin: const EdgeInsets.only(bottom: 8),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(
              color: AppColors.secondary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.delete_outline, color: Colors.white),
          ),
          confirmDismiss: (_) => showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Delete word?'),
              content:
                  Text('Remove "$frWord / $koWord" from this list?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel')),
                FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.secondary),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Delete'),
                ),
              ],
            ),
          ),
          onDismissed: (_) {
            ref
                .read(listActionsProvider.notifier)
                .deleteConcept(concept.id);
          },
          child: Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  const Text('🇫🇷', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Expanded(
                    child:
                        Text(frWord, style: tt.titleMedium),
                  ),
                  const Icon(Icons.arrow_forward,
                      color: AppColors.grey500, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child:
                        Text(koWord, style: tt.titleMedium),
                  ),
                  const Text('🇰🇷', style: TextStyle(fontSize: 18)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
