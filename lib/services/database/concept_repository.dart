import 'package:uuid/uuid.dart';
import '../../models/concept.dart';
import '../../models/word_variant.dart';
import '../../models/variant_progress.dart';
import 'database_service.dart';

class ConceptRepository {
  final DatabaseService _db = DatabaseService();

  // Créer un concept avec ses variantes
  Future<Concept> createConceptWithVariants({
    required String listId,
    required String category,
    required List<Map<String, String>> lang1Variants, // [{word, register}]
    required List<Map<String, String>> lang2Variants, // [{word, register}]
    String? contextLang1,
    String? contextLang2,
  }) async {
    final conceptId = const Uuid().v4();

    // Créer le concept
    final concept = Concept(
      id: conceptId,
      listId: listId,
      category: category,
      contextLang1: contextLang1,
      contextLang2: contextLang2,
      createdAt: DateTime.now().toIso8601String(),
    );

    await _db.insertConcept(concept.toMap());

    // Créer les variantes langue 1
    for (int i = 0; i < lang1Variants.length; i++) {
      final variantData = lang1Variants[i];
      final variant = WordVariant(
        id: const Uuid().v4(),
        conceptId: conceptId,
        word: variantData['word']!,
        langCode: 'fr', // TODO: récupérer de la liste
        registerTag: variantData['register'] ?? 'neutral',
        position: i,
        isPrimary: i == 0,
        createdAt: DateTime.now().toIso8601String(),
      );

      await _db.insertWordVariant(variant.toMap());

      // Créer la progression pour cette variante
      await _createProgressForVariant(variant.id);
    }

    // Créer les variantes langue 2
    for (int i = 0; i < lang2Variants.length; i++) {
      final variantData = lang2Variants[i];
      final variant = WordVariant(
        id: const Uuid().v4(),
        conceptId: conceptId,
        word: variantData['word']!,
        langCode: 'ko', // TODO: récupérer de la liste
        registerTag: variantData['register'] ?? 'neutral',
        position: i,
        isPrimary: i == 0,
        createdAt: DateTime.now().toIso8601String(),
      );

      await _db.insertWordVariant(variant.toMap());

      // Créer la progression pour cette variante
      await _createProgressForVariant(variant.id);
    }

    return concept;
  }

  // Créer les progressions pour une variante (2 directions)
  Future<void> _createProgressForVariant(String variantId) async {
    // Direction 1: lang1 → lang2
    final progress1 = VariantProgress(
      id: const Uuid().v4(),
      variantId: variantId,
      direction: 'lang1_to_lang2',
      nextReviewDate: DateTime.now().toIso8601String(),
    );
    await _db.insertVariantProgress(progress1.toMap());

    // Direction 2: lang2 → lang1
    final progress2 = VariantProgress(
      id: const Uuid().v4(),
      variantId: variantId,
      direction: 'lang2_to_lang1',
      nextReviewDate: DateTime.now().toIso8601String(),
    );
    await _db.insertVariantProgress(progress2.toMap());
  }

  // Récupérer tous les concepts d'une liste avec leurs variantes
  Future<List<Map<String, dynamic>>> getConceptsWithVariants(
      String listId) async {
    final concepts = await _db.getConceptsByListId(listId);
    final results = <Map<String, dynamic>>[];

    for (var conceptMap in concepts) {
      final concept = Concept.fromMap(conceptMap);
      final variants = await _db.getVariantsByConceptId(concept.id);

      // Séparer les variantes par langue
      final lang1Variants = variants
          .where((v) => v['lang_code'] == 'fr')
          .map((v) => WordVariant.fromMap(v))
          .toList();

      final lang2Variants = variants
          .where((v) => v['lang_code'] == 'ko')
          .map((v) => WordVariant.fromMap(v))
          .toList();

      results.add({
        'concept': concept,
        'lang1Variants': lang1Variants,
        'lang2Variants': lang2Variants,
      });
    }

    return results;
  }

  // Supprimer un concept (et toutes ses variantes)
  Future<void> deleteConcept(String conceptId) async {
    await _db.deleteConcept(conceptId);
  }
}
