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
    final conceptsAsync = ref.watch(listDetailProvider(listId));
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('List'),
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
            ? const Center(
                child: Text('No words yet. Add one!',
                    style: TextStyle(color: AppColors.grey500)))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: concepts.length,
                itemBuilder: (ctx, i) {
                  final concept = concepts[i];
                  final variantsAsync =
                      ref.watch(variantsProvider(concept.id));
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: variantsAsync.when(
                        loading: () => const LinearProgressIndicator(),
                        error: (_, __) => const Text('Error'),
                        data: (variants) {
                          final fr = variants
                              .where((v) =>
                                  v.langCode == 'fr' && !v.isDeleted)
                              .toList();
                          final ko = variants
                              .where((v) =>
                                  v.langCode == 'ko' && !v.isDeleted)
                              .toList();
                          return Row(
                            children: [
                              const Text('🇫🇷',
                                  style: TextStyle(fontSize: 18)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                    fr.isNotEmpty ? fr.first.word : '—',
                                    style: tt.titleMedium),
                              ),
                              const Icon(Icons.arrow_forward,
                                  color: AppColors.grey500, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                    ko.isNotEmpty ? ko.first.word : '—',
                                    style: tt.titleMedium),
                              ),
                              const Text('🇰🇷',
                                  style: TextStyle(fontSize: 18)),
                            ],
                          );
                        },
                      ),
                    ),
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
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Word'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: frCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                  labelText: 'French', prefixText: '🇫🇷 '),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: koCtrl,
              decoration: const InputDecoration(
                  labelText: 'Korean', prefixText: '🇰🇷 '),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (frCtrl.text.trim().isEmpty || koCtrl.text.trim().isEmpty) {
                return;
              }
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
