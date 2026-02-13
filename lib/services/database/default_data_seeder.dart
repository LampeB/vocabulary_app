import 'package:uuid/uuid.dart';
import '../../models/vocabulary_list.dart';
import 'vocabulary_list_repository.dart';
import 'concept_repository.dart';

class DefaultDataSeeder {
  final VocabularyListRepository _listRepo = VocabularyListRepository();
  final ConceptRepository _conceptRepo = ConceptRepository();

  static const _defaultWords = [
    {'fr': 'bonjour', 'ko': '안녕하세요', 'category': 'greetings'},
    {'fr': 'merci', 'ko': '감사합니다', 'category': 'greetings'},
    {'fr': 'au revoir', 'ko': '안녕히 가세요', 'category': 'greetings'},
    {'fr': 'école', 'ko': '학교', 'category': 'general'},
    {'fr': 'maison', 'ko': '집', 'category': 'general'},
    {'fr': 'eau', 'ko': '물', 'category': 'food'},
    {'fr': 'cheval', 'ko': '말', 'category': 'general'},
    {'fr': 'chat', 'ko': '고양이', 'category': 'general'},
    {'fr': 'chien', 'ko': '개', 'category': 'general'},
    {'fr': 'livre', 'ko': '책', 'category': 'general'},
  ];

  /// Seeds a default FR-KO list if no lists exist yet.
  /// Returns true if seeding was performed.
  Future<bool> seedIfEmpty() async {
    final lists = await _listRepo.getAllLists();
    if (lists.isNotEmpty) return false;

    final list = VocabularyList(
      id: const Uuid().v4(),
      name: 'FR-KO Basique',
      lang1Code: 'fr',
      lang2Code: 'ko',
      createdAt: DateTime.now().toIso8601String(),
    );
    await _listRepo.createList(list);

    for (final entry in _defaultWords) {
      await _conceptRepo.createConceptWithVariants(
        listId: list.id,
        category: entry['category']!,
        lang1Variants: [{'word': entry['fr']!}],
        lang2Variants: [{'word': entry['ko']!}],
        lang1Code: 'fr',
        lang2Code: 'ko',
      );
    }

    // Update total concepts count on the list
    await _listRepo.updateList(list.copyWith(
      totalConcepts: _defaultWords.length,
    ));

    return true;
  }
}
