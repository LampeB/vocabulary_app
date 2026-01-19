import 'package:uuid/uuid.dart';
import '../../models/concept.dart';
import '../../models/word_variant.dart';
import '../../models/variant_progress.dart';
import '../audio/audio_service.dart';
import '../../config/app_config.dart';
import 'database_service.dart';

class ConceptRepository {
  final DatabaseService _db = DatabaseService();
  final AudioService _audioService;

  /// Constructeur avec injection de dépendance
  /// Permet de passer un service audio custom (utile pour les tests)
  ConceptRepository({AudioService? audioService})
      : _audioService = audioService ?? AppConfig.createAudioService();

  /// Régénérer l'audio pour une variante spécifique
  Future<bool> regenerateAudioForVariant({
    required String variantId,
    Function(String)? onProgress,
  }) async {
    try {
      // Récupérer la variante
      final variantMap = await _db.getVariantById(variantId);
      if (variantMap == null) {
        throw Exception('Variante introuvable: $variantId');
      }

      final variant = WordVariant.fromMap(variantMap);

      onProgress?.call('Régénération de l\'audio pour "${variant.word}"...');

      // Supprimer l'ancien audio si existe
      if (variant.audioHash != null) {
        try {
          await _audioService.deleteAudio(variant.audioHash!);
        } catch (e) {
          print('Avertissement: Impossible de supprimer l\'ancien audio: $e');
        }
      }

      // Générer le nouvel audio avec forceRegenerate = true
      final audioResult = await _audioService.getOrGenerateAudio(
        text: variant.word,
        langCode: variant.langCode,
        onProgress: onProgress,
        forceRegenerate: true,
      );

      // Mettre à jour le hash dans la DB
      await _db.updateWordVariant(variantId, {
        'audio_hash': audioResult.hash,
      });

      onProgress?.call('Audio régénéré avec succès !');
      return true;
    } catch (e) {
      print('Erreur lors de la régénération audio: $e');
      onProgress?.call('Erreur: $e');
      return false;
    }
  }

  /// Régénérer l'audio pour toutes les variantes d'un concept
  Future<int> regenerateAudioForConcept({
    required String conceptId,
    Function(String)? onProgress,
  }) async {
    int successCount = 0;

    try {
      final variants = await _db.getVariantsByConceptId(conceptId);

      print('🔄 Régénération pour ${variants.length} variante(s)');

      for (int i = 0; i < variants.length; i++) {
        final variant = WordVariant.fromMap(variants[i]);

        print('📝 Variante ${i + 1}: ${variant.word} (${variant.langCode})');

        onProgress
            ?.call('Régénération ${i + 1}/${variants.length}: ${variant.word}');

        final success = await regenerateAudioForVariant(
          variantId: variant.id,
          onProgress: onProgress,
        );

        if (success) {
          successCount++;
          print('✅ Succès pour ${variant.word}');
        } else {
          print('❌ Échec pour ${variant.word}');
        }

        // Pause pour rate limiting
        if (i < variants.length - 1) {
          print('⏸️ Pause 1s...');
          await Future.delayed(const Duration(seconds: 1));
        }
      }

      print('🎉 Régénération terminée: $successCount/${variants.length}');
      return successCount;
    } catch (e) {
      print('💥 Erreur régénération: $e');
      return successCount;
    }
  }

  /// Créer un concept avec ses variantes ET générer l'audio
  Future<Concept> createConceptWithVariants({
    required String listId,
    required String category,
    required List<Map<String, String>> lang1Variants,
    required List<Map<String, String>> lang2Variants,
    String? contextLang1,
    String? contextLang2,
    Function(String)? onProgress,
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

    // Créer les variantes langue 1 AVEC audio
    onProgress?.call('Génération audio français...');
    for (int i = 0; i < lang1Variants.length; i++) {
      await _createVariantWithAudio(
        conceptId: conceptId,
        variantData: lang1Variants[i],
        langCode: 'fr',
        position: i,
        onProgress: onProgress,
      );
    }

    // Créer les variantes langue 2 AVEC audio
    onProgress?.call('Génération audio coréen...');
    for (int i = 0; i < lang2Variants.length; i++) {
      await _createVariantWithAudio(
        conceptId: conceptId,
        variantData: lang2Variants[i],
        langCode: 'ko',
        position: i,
        onProgress: onProgress,
      );
    }

    onProgress?.call('Terminé !');
    return concept;
  }

  /// Créer une variante avec génération audio
  Future<void> _createVariantWithAudio({
    required String conceptId,
    required Map<String, String> variantData,
    required String langCode,
    required int position,
    Function(String)? onProgress,
  }) async {
    final word = variantData['word']!;
    String? audioHash;

    try {
      // Générer ou récupérer l'audio via le service
      onProgress?.call('Génération audio: "$word"...');

      final audioResult = await _audioService.getOrGenerateAudio(
        text: word,
        langCode: langCode,
        onProgress: onProgress,
      );

      audioHash = audioResult.hash;

      if (audioResult.fromCache) {
        onProgress?.call('Audio trouvé dans le cache');
      }
    } catch (e) {
      print('Erreur génération audio pour "$word": $e');
      // Continue sans audio en cas d'erreur
    }

    // Créer la variante
    final variant = WordVariant(
      id: const Uuid().v4(),
      conceptId: conceptId,
      word: word,
      langCode: langCode,
      registerTag: variantData['register'] ?? 'neutral',
      position: position,
      isPrimary: position == 0,
      audioHash: audioHash,
      createdAt: DateTime.now().toIso8601String(),
    );

    await _db.insertWordVariant(variant.toMap());
    await _createProgressForVariant(variant.id);
  }

  /// Créer les progressions pour une variante (2 directions)
  Future<void> _createProgressForVariant(String variantId) async {
    final progress1 = VariantProgress(
      id: const Uuid().v4(),
      variantId: variantId,
      direction: 'lang1_to_lang2',
      nextReviewDate: DateTime.now().toIso8601String(),
    );
    await _db.insertVariantProgress(progress1.toMap());

    final progress2 = VariantProgress(
      id: const Uuid().v4(),
      variantId: variantId,
      direction: 'lang2_to_lang1',
      nextReviewDate: DateTime.now().toIso8601String(),
    );
    await _db.insertVariantProgress(progress2.toMap());
  }

  /// Récupérer tous les concepts d'une liste avec leurs variantes
  Future<List<Map<String, dynamic>>> getConceptsWithVariants(
      String listId) async {
    final concepts = await _db.getConceptsByListId(listId);
    final results = <Map<String, dynamic>>[];

    for (var conceptMap in concepts) {
      final concept = Concept.fromMap(conceptMap);
      final variants = await _db.getVariantsByConceptId(concept.id);

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

  /// Supprimer un concept (et toutes ses variantes + audio)
  Future<void> deleteConcept(String conceptId) async {
    // Récupérer les variantes pour supprimer leurs fichiers audio
    final variants = await _db.getVariantsByConceptId(conceptId);

    for (var variantMap in variants) {
      final variant = WordVariant.fromMap(variantMap);
      if (variant.audioHash != null) {
        try {
          await _audioService.deleteAudio(variant.audioHash!);
        } catch (e) {
          print('Erreur suppression audio ${variant.audioHash}: $e');
        }
      }
    }

    await _db.deleteConcept(conceptId);
  }
}
