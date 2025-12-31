import 'package:flutter/material.dart';
import '../models/vocabulary_list.dart';
import '../models/concept.dart';
import '../models/word_variant.dart';
import '../services/database/concept_repository.dart';
import '../services/database/vocabulary_list_repository.dart';

class ListDetailScreen extends StatefulWidget {
  final VocabularyList list;

  const ListDetailScreen({super.key, required this.list});

  @override
  State<ListDetailScreen> createState() => _ListDetailScreenState();
}

class _ListDetailScreenState extends State<ListDetailScreen> {
  final ConceptRepository _conceptRepo = ConceptRepository();
  final VocabularyListRepository _listRepo = VocabularyListRepository();

  List<Map<String, dynamic>> _concepts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConcepts();
  }

  Future<void> _loadConcepts() async {
    setState(() => _isLoading = true);
    try {
      final concepts =
          await _conceptRepo.getConceptsWithVariants(widget.list.id);
      setState(() {
        _concepts = concepts;
        _isLoading = false;
      });

      // Mettre à jour le nombre total de concepts
      await _listRepo.updateTotalConcepts(widget.list.id);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  Future<void> _showAddWordDialog() async {
    final lang1Controller = TextEditingController();
    final lang2Controller = TextEditingController();
    final categoryController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajouter un mot'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: lang1Controller,
                decoration: InputDecoration(
                  labelText: 'Français',
                  hintText: 'Ex: bonjour',
                  border: const OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: lang2Controller,
                decoration: InputDecoration(
                  labelText: 'Coréen',
                  hintText: 'Ex: 안녕하세요',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: categoryController,
                decoration: InputDecoration(
                  labelText: 'Catégorie (optionnel)',
                  hintText: 'Ex: greetings',
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );

    if (result == true &&
        lang1Controller.text.trim().isNotEmpty &&
        lang2Controller.text.trim().isNotEmpty) {
      await _conceptRepo.createConceptWithVariants(
        listId: widget.list.id,
        category: categoryController.text.trim().isNotEmpty
            ? categoryController.text.trim()
            : 'general',
        lang1Variants: [
          {'word': lang1Controller.text.trim(), 'register': 'neutral'}
        ],
        lang2Variants: [
          {'word': lang2Controller.text.trim(), 'register': 'neutral'}
        ],
      );

      _loadConcepts();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mot ajouté !')),
        );
      }
    }
  }

  Future<void> _deleteConcept(String conceptId) async {
    await _conceptRepo.deleteConcept(conceptId);
    _loadConcepts();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mot supprimé')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.list.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Informations'),
                  content: Text(
                    'Liste: ${widget.list.name}\n'
                    'Langues: ${widget.list.lang1Code.toUpperCase()} ↔ ${widget.list.lang2Code.toUpperCase()}\n'
                    'Créée le: ${DateTime.parse(widget.list.createdAt).day}/${DateTime.parse(widget.list.createdAt).month}/${DateTime.parse(widget.list.createdAt).year}\n'
                    'Nombre de mots: ${_concepts.length}',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _concepts.isEmpty
              ? _buildEmptyState()
              : _buildConceptsList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddWordDialog,
        icon: const Icon(Icons.add),
        label: const Text('Ajouter un mot'),
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
              Icons.school,
              size: 80,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            ),
            const SizedBox(height: 24),
            Text(
              'Aucun mot dans cette liste',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Ajoutez votre premier mot pour commencer',
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
              onPressed: _showAddWordDialog,
              icon: const Icon(Icons.add),
              label: const Text('Ajouter un mot'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConceptsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _concepts.length,
      itemBuilder: (context, index) {
        final item = _concepts[index];
        final concept = item['concept'] as Concept;
        final lang1Variants = item['lang1Variants'] as List<WordVariant>;
        final lang2Variants = item['lang2Variants'] as List<WordVariant>;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Catégorie (si présente)
                      if (concept.category != null &&
                          concept.category != 'general') ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            concept.category!,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onPrimaryContainer,
                                    ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      // Mots langue 1
                      Row(
                        children: [
                          Text(
                            widget.list.lang1Code.toUpperCase(),
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              lang1Variants.map((v) => v.word).join(', '),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Mots langue 2
                      Row(
                        children: [
                          Text(
                            widget.list.lang2Code.toUpperCase(),
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              lang2Variants.map((v) => v.word).join(', '),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Supprimer'),
                        content: const Text('Supprimer ce mot ?'),
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
                      _deleteConcept(concept.id);
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
