import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/vocabulary_list.dart';
import '../services/database/vocabulary_list_repository.dart';
import 'list_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final VocabularyListRepository _repository = VocabularyListRepository();
  List<Map<String, dynamic>> _listsWithStats = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLists();
  }

  Future<void> _loadLists() async {
    setState(() => _isLoading = true);
    try {
      final lists = await _repository.getListsWithStats();
      setState(() {
        _listsWithStats = lists;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  Future<void> _createNewList() async {
    final nameController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nouvelle liste'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Nom de la liste',
            hintText: 'Ex: Salutations quotidiennes',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Créer'),
          ),
        ],
      ),
    );

    if (result == true && nameController.text.trim().isNotEmpty) {
      final newList = VocabularyList(
        id: const Uuid().v4(),
        name: nameController.text.trim(),
        lang1Code: 'fr',
        lang2Code: 'ko',
        createdAt: DateTime.now().toIso8601String(),
      );

      await _repository.createList(newList);
      _loadLists();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Liste créée !')),
        );
      }
    }
  }

  Future<void> _deleteList(String listId, String listName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content:
            Text('Supprimer "$listName" ?\nCette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _repository.deleteList(listId);
      _loadLists();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Liste supprimée')),
        );
      }
    }
  }

  void _openListDetail(VocabularyList list) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ListDetailScreen(list: list),
      ),
    );
    // Recharger les stats quand on revient
    _loadLists();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Listes de Vocabulaire'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Paramètres - À venir')),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _listsWithStats.isEmpty
              ? _buildEmptyState()
              : _buildListView(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNewList,
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle liste'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.library_books,
              size: 80,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            ),
            const SizedBox(height: 24),
            Text(
              'Aucune liste de vocabulaire',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Créez votre première liste pour commencer',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.6),
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _createNewList,
              icon: const Icon(Icons.add),
              label: const Text('Créer une liste'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListView() {
    return RefreshIndicator(
      onRefresh: _loadLists,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _listsWithStats.length,
        itemBuilder: (context, index) {
          final item = _listsWithStats[index];
          final list = item['list'] as VocabularyList;
          final totalConcepts = item['totalConcepts'] as int;
          final knownWords = item['knownWords'] as int;
          final progressPercent = item['progressPercent'] as int;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _openListDetail(list),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                list.name,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${list.lang1Code.toUpperCase()} ↔ ${list.lang2Code.toUpperCase()}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _deleteList(list.id, list.name),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Barre de progression
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: totalConcepts > 0 ? progressPercent / 100 : 0,
                        minHeight: 8,
                        backgroundColor:
                            Theme.of(context).colorScheme.surfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$knownWords / $totalConcepts mots maîtrisés',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        Text(
                          '$progressPercent%',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => _openListDetail(list),
                            icon: const Icon(Icons.edit),
                            label: const Text('Gérer'),
                          ),
                        ),
                        if (totalConcepts > 0) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton.tonalIcon(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Quiz - À venir')),
                                );
                              },
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('Réviser'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
