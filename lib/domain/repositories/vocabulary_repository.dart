import '../entities/concept.dart';
import '../entities/vocabulary_list.dart';
import '../entities/word_variant.dart';
import '../../core/errors/failure.dart';

abstract interface class VocabularyRepository {
  // Lists
  Stream<List<VocabularyList>> watchMyLists();
  Future<Result<VocabularyList>> createList({required String name, String? description});
  Future<Result<VocabularyList>> updateList(VocabularyList list);
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
  Future<Result<Concept>> addConceptWithVariants({
    required String listId,
    required String frWord,
    required String koWord,
    String? notes,
    String? category,
  });
  Future<Result<Concept>> updateConcept(Concept concept);
  Future<Result<void>> deleteConcept(String conceptId);

  // Variants
  Future<Result<List<WordVariant>>> getVariants(String conceptId);
  Future<Result<WordVariant>> createVariant({
    required String conceptId,
    required String word,
    required String langCode,
    String registerTag = 'neutral',
    bool isPrimary = false,
  });
  Future<Result<WordVariant>> updateVariant(WordVariant variant);
  Future<Result<void>> deleteVariant(String variantId);

  // Import / Export
  Future<Result<VocabularyList>> importFromJson(Map<String, dynamic> json);
  Future<Result<Map<String, dynamic>>> exportToJson(String listId);
  Future<Result<String>> generateShareLink(String listId);
  Future<Result<VocabularyList>> importFromShareToken(String token);

  // Sync
  Future<void> syncFromRemote();
}
