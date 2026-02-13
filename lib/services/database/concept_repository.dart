import 'package:uuid/uuid.dart';
import '../../config/constants.dart';
import '../../models/concept.dart';
import '../../models/word_variant.dart';
import '../../models/variant_progress.dart';
import '../audio/audio_service.dart';
import '../../config/app_config.dart';
import 'database_service.dart';

class ConceptRepository {
  final DatabaseService _db = DatabaseService();
  final AudioService _audioService;

  ConceptRepository({AudioService? audioService})
      : _audioService = audioService ?? AppConfig.createAudioService();

  Future<bool> regenerateAudioForVariant({
    required String variantId,
    Function(String)? onProgress,
  }) async {
    try {
      final variantMap = await _db.getVariantById(variantId);
      if (variantMap == null) {
        throw Exception('Variante introuvable: $variantId');
      }

      final variant = WordVariant.fromMap(variantMap);

      onProgress?.call('Régénération de l\'audio pour "${variant.word}"...');

      if (variant.audioHash != null) {
        try {
          await _audioService.deleteAudio(variant.audioHash!);
        } catch (_) {}
      }

      final audioResult = await _audioService.getOrGenerateAudio(
        text: variant.word,
        langCode: variant.langCode,
        onProgress: onProgress,
        forceRegenerate: true,
      );

      await _db.updateWordVariant(variantId, {
        'audio_hash': audioResult.hash,
      });

      onProgress?.call('Audio régénéré avec succès !');
      return true;
    } catch (e) {
      onProgress?.call('Erreur: $e');
      return false;
    }
  }

  Future<int> regenerateAudioForConcept({
    required String conceptId,
    Function(String)? onProgress,
  }) async {
    int successCount = 0;

    try {
      final variants = await _db.getVariantsByConceptId(conceptId);

      for (int i = 0; i < variants.length; i++) {
        final variant = WordVariant.fromMap(variants[i]);

        onProgress
            ?.call('Régénération ${i + 1}/${variants.length}: ${variant.word}');

        final success = await regenerateAudioForVariant(
          variantId: variant.id,
          onProgress: onProgress,
        );

        if (success) successCount++;

        if (i < variants.length - 1) {
          await Future.delayed(const Duration(seconds: 1));
        }
      }

      return successCount;
    } catch (e) {
      return successCount;
    }
  }

  Future<Concept> createConceptWithVariants({
    required String listId,
    required String category,
    required List<Map<String, String>> lang1Variants,
    required List<Map<String, String>> lang2Variants,
    required String lang1Code,
    required String lang2Code,
    String? contextLang1,
    String? contextLang2,
    Function(String)? onProgress,
  }) async {
    final conceptId = const Uuid().v4();

    final concept = Concept(
      id: conceptId,
      listId: listId,
      category: category,
      contextLang1: contextLang1,
      contextLang2: contextLang2,
      createdAt: DateTime.now().toIso8601String(),
    );

    await _db.insertConcept(concept.toMap());

    final lang1Name = AppConstants.languageNames[lang1Code] ?? lang1Code;
    onProgress?.call('Génération audio $lang1Name...');
    for (int i = 0; i < lang1Variants.length; i++) {
      await _createVariantWithAudio(
        conceptId: conceptId,
        variantData: lang1Variants[i],
        langCode: lang1Code,
        position: i,
        onProgress: onProgress,
      );
    }

    final lang2Name = AppConstants.languageNames[lang2Code] ?? lang2Code;
    onProgress?.call('Génération audio $lang2Name...');
    for (int i = 0; i < lang2Variants.length; i++) {
      await _createVariantWithAudio(
        conceptId: conceptId,
        variantData: lang2Variants[i],
        langCode: lang2Code,
        position: i,
        onProgress: onProgress,
      );
    }

    onProgress?.call('Terminé !');
    return concept;
  }

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
    } catch (_) {}

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

  Future<void> deleteConcept(String conceptId) async {
    final variants = await _db.getVariantsByConceptId(conceptId);

    for (var variantMap in variants) {
      final variant = WordVariant.fromMap(variantMap);
      if (variant.audioHash != null) {
        try {
          await _audioService.deleteAudio(variant.audioHash!);
        } catch (_) {}
      }
    }

    await _db.deleteConcept(conceptId);
  }
}
