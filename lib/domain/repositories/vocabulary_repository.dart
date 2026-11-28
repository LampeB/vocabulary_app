import '../entities/concept.dart';
import '../entities/vocabulary_list.dart';
import '../entities/word_variant.dart';
import '../../core/errors/failure.dart';

abstract interface class VocabularyRepository {
  // Lists
  Stream<List<VocabularyList>> watchMyLists();
  Stream<VocabularyList?> watchListById(String listId);

  /// [langA]/[langB] are the list's learning-language pair (generic-language-
  /// pairs epic). Defaults keep pre-multi-language callers on FR↔KO.
  Future<Result<VocabularyList>> createList({
    required String name,
    String? description,
    String langA = 'fr',
    String langB = 'ko',
  });
  Future<Result<VocabularyList>> updateList(VocabularyList list);
  Future<Result<VocabularyList>> renameList(String listId, String name);
  Future<Result<void>> deleteList(String listId);
  Future<Result<VocabularyList>> getListById(String listId);
  Future<Result<VocabularyList?>> getListByShareToken(String token);

  // Concepts
  Stream<List<Concept>> watchConcepts(String listId);
  Future<Result<Concept>> createConcept({
    required String listId,
    String? category,
    String? notes,
    String? exampleFr,
    String? exampleKo,
  });

  /// Creates a concept with one variant per side of the list's language pair.
  /// [wordA] is stored in [langA] and [wordB] in [langB]. The write is rejected
  /// if those languages no longer match the owning list in that order.
  Future<Result<Concept>> addConceptWithVariants({
    required String listId,
    required String wordA,
    required String wordB,
    String langA = 'fr',
    String langB = 'ko',
    String? notes,
    String? category,
  });
  Future<Result<Concept>> updateConcept(Concept concept);
  Future<Result<void>> deleteConcept(String conceptId);

  // Variants
  Future<Result<List<WordVariant>>> getVariants(String conceptId);
  Stream<List<WordVariant>> watchVariants(String conceptId);
  Future<List<({String source, String target})>> getWordPairSample(
    String listId, {
    required int limit,
  });
  Future<Result<WordVariant>> createVariant({
    required String conceptId,
    required String word,
    required String langCode,
    String registerTag = 'neutral',
    bool isPrimary = false,
  });
  Future<Result<WordVariant>> updateVariant(WordVariant variant);
  Future<Result<WordVariant>> updateVariantWord(String variantId, String word);

  /// Changes the edited sides of a concept together, provided the list and
  /// both variants still match the pair shown when the form was opened.
  Future<Result<void>> updateWordPair({
    required String listId,
    required WordVariant variantA,
    required WordVariant variantB,
    required String wordA,
    required String wordB,
  });
  Future<Result<void>> deleteVariant(String variantId);

  // Import / Export
  /// [origin] tags the created list: 'user' (default, counts against the
  /// free quota), 'starter' or 'premium' (quota-exempt content).
  Future<Result<VocabularyList>> importFromJson(
    Map<String, dynamic> json, {
    String origin = 'user',
  });
  Future<Result<Map<String, dynamic>>> exportToJson(String listId);
  Future<Result<String>> generateShareLink(String listId);
  Future<Result<VocabularyList>> importFromShareToken(String token);

  // Sync
  Future<void> syncFromRemote();
}
