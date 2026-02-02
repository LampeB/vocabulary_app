import 'package:flutter/material.dart';
import '../models/vocabulary_list.dart';
import '../models/concept.dart';
import '../models/word_variant.dart';
import '../services/database/concept_repository.dart';
import '../services/database/vocabulary_list_repository.dart';
import '../services/audio/audio_player_service.dart';

class ListDetailScreen extends StatefulWidget {
  final VocabularyList list;

  const ListDetailScreen({super.key, required this.list});

  @override
  State<ListDetailScreen> createState() => _ListDetailScreenState();
}

class _ListDetailScreenState extends State<ListDetailScreen> {
  final ConceptRepository _conceptRepo = ConceptRepository();
  final VocabularyListRepository _listRepo = VocabularyListRepository();
  final AudioPlayerService _audioPlayer = AudioPlayerService();

  List<Map<String, dynamic>> _concepts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConcepts();
    // Audio initialization is lazy - done on first play via _ensureInitialized()
    // Removing eager init to avoid triggering Bluetooth popup on Android
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
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
    String progressMessage = '';
    bool isGenerating = false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            key: const Key('add_word_dialog'),
            title: const Text('Ajouter un mot'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    key: const Key('french_word_field'),
                    controller: lang1Controller,
                    decoration: const InputDecoration(
                      labelText: 'Français',
                      hintText: 'Ex: bonjour',
                      border: OutlineInputBorder(),
                    ),
                    enabled: !isGenerating,
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    key: const Key('korean_word_field'),
                    controller: lang2Controller,
                    decoration: const InputDecoration(
                      labelText: 'Coréen',
                      hintText: 'Ex: 안녕하세요',
                      border: OutlineInputBorder(),
                    ),
                    enabled: !isGenerating,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: categoryController,
                    decoration: const InputDecoration(
                      labelText: 'Catégorie (optionnel)',
                      hintText: 'Ex: greetings',
                      border: OutlineInputBorder(),
                    ),
                    enabled: !isGenerating,
                  ),
                  if (isGenerating) ...[
                    const SizedBox(height: 16),
                    const CircularProgressIndicator(),
                    const SizedBox(height: 8),
                    Text(
                      progressMessage,
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              if (!isGenerating)
                TextButton(
                  key: const Key('cancel_add_word_button'),
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Annuler'),
                ),
              if (!isGenerating)
                FilledButton(
                  key: const Key('confirm_add_word_button'),
                  onPressed: () async {
                    if (lang1Controller.text.trim().isEmpty ||
                        lang2Controller.text.trim().isEmpty) {
                      return;
                    }

                    setState(() {
                      isGenerating = true;
                      progressMessage = 'Préparation...';
                    });

                    try {
                      await _conceptRepo.createConceptWithVariants(
                        listId: widget.list.id,
                        category: categoryController.text.trim().isNotEmpty
                            ? categoryController.text.trim()
                            : 'general',
                        lang1Variants: [
                          {
                            'word': lang1Controller.text.trim(),
                            'register': 'neutral'
                          }
                        ],
                        lang2Variants: [
                          {
                            'word': lang2Controller.text.trim(),
                            'register': 'neutral'
                          }
                        ],
                        onProgress: (message) {
                          if (mounted) {
                            setState(() {
                              progressMessage = message;
                            });
                          }
                        },
                      );

                      if (context.mounted) {
                        Navigator.pop(context, true);
                      }
                    } catch (e) {
                      if (mounted) {
                        setState(() {
                          isGenerating = false;
                          progressMessage = 'Erreur: $e';
                        });
                      }
                    }
                  },
                  child: const Text('Ajouter'),
                ),
            ],
          );
        },
      ),
    );

    if (result == true) {
      _loadConcepts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mot ajouté avec audio !')),
        );
      }
    }
  }

  Future<void> _deleteConcept(String conceptId) async {
    await _conceptRepo.deleteConcept(conceptId);
    _loadConcepts();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mot et audio supprimés')),
      );
    }
  }

  // Jouer l'audio d'une variante (TTS natif ou fichier audio)
  Future<void> _playAudio(WordVariant variant, String langCode) async {
    final success = await _audioPlayer.playAudioSmart(
      audioHash: variant.audioHash,
      text: variant.word,
      langCode: langCode,
    );

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur de lecture audio')),
      );
    }
  }

  // Régénérer l'audio d'un concept
  Future<void> _regenerateAudio(Concept concept) async {
    // ✅ Empêcher clics multiples
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // Force à choisir
      builder: (context) => AlertDialog(
        title: const Text('Régénérer l\'audio'),
        content: const Text(
          'Voulez-vous régénérer l\'audio pour ce mot ?\n\n'
          'Les nouveaux audios utiliseront vos paramètres actuels '
          '(voix, stabilité, etc.).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Régénérer'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    // ✅ Bloquer l'interface pendant la régénération
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        // Variable locale (pas de setState dans callback!)
        return FutureBuilder<int>(
          future: _conceptRepo.regenerateAudioForConcept(
            conceptId: concept.id,
            onProgress: (message) {
              // ✅ Juste print, pas de setState
              print('📢 $message');
            },
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              // Fermer le dialogue après completion
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }

                if (mounted) {
                  _loadConcepts();

                  if (snapshot.hasError) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Erreur: ${snapshot.error}'),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 5),
                      ),
                    );
                  } else {
                    final successCount = snapshot.data ?? 0;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('$successCount audio(s) régénéré(s) !'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                }
              });
            }

            return AlertDialog(
              title: const Text('Régénération audio'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    snapshot.connectionState == ConnectionState.waiting
                        ? 'Régénération en cours...'
                        : 'Terminé !',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('list_detail_screen'),
      appBar: AppBar(
        title: Text(widget.list.name, key: const Key('list_detail_title')),
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
        key: const Key('add_word_button'),
        onPressed: _showAddWordDialog,
        icon: const Icon(Icons.add),
        label: const Text('Ajouter un mot'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      key: const Key('empty_list_state'),
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
              key: const Key('empty_list_message'),
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

        final wordKey = lang1Variants.isNotEmpty ? lang1Variants.first.word : concept.id;
        return Card(
          key: Key('word_card_$wordKey'),
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (concept.category != null &&
                    concept.category != 'general') ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      concept.category!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                          ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                // Mots langue 1 avec bouton audio
                Row(
                  children: [
                    Text(
                      widget.list.lang1Code.toUpperCase(),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
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
                    Semantics(
                      label: 'audio_lang1_$wordKey',
                      child: IconButton(
                        key: Key('audio_button_lang1_$wordKey'),
                        icon: const Icon(Icons.volume_up, size: 20),
                        onPressed: () => _playAudio(lang1Variants.first, widget.list.lang1Code),
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Mots langue 2 avec bouton audio
                Row(
                  children: [
                    Text(
                      widget.list.lang2Code.toUpperCase(),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
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
                    Semantics(
                      label: 'audio_lang2_$wordKey',
                      child: IconButton(
                        key: Key('audio_button_lang2_$wordKey'),
                        icon: const Icon(Icons.volume_up, size: 20),
                        onPressed: () => _playAudio(lang2Variants.first, widget.list.lang2Code),
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Boutons d'action
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Régénérer audio'),
                      onPressed: () => _regenerateAudio(concept),
                      style: TextButton.styleFrom(
                        foregroundColor:
                            Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                    IconButton(
                      key: Key('delete_word_button_$wordKey'),
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            key: const Key('delete_word_dialog'),
                            title: const Text('Supprimer'),
                            content:
                                const Text('Supprimer ce mot et son audio ?'),
                            actions: [
                              TextButton(
                                key: const Key('cancel_delete_word_button'),
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Annuler'),
                              ),
                              FilledButton(
                                key: const Key('confirm_delete_word_button'),
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
              ],
            ),
          ),
        );
      },
    );
  }
}
