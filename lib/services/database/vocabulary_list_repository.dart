import '../../models/vocabulary_list.dart';
import 'database_service.dart';

class VocabularyListRepository {
  final DatabaseService _db = DatabaseService();

  // Créer une nouvelle liste
  Future<VocabularyList> createList(VocabularyList list) async {
    await _db.insertVocabularyList(list.toMap());
    return list;
  }

  // Récupérer toutes les listes
  Future<List<VocabularyList>> getAllLists() async {
    final maps = await _db.getAllVocabularyLists();
    return maps.map((map) => VocabularyList.fromMap(map)).toList();
  }

  // Récupérer une liste par ID
  Future<VocabularyList?> getListById(String id) async {
    final map = await _db.getVocabularyListById(id);
    return map != null ? VocabularyList.fromMap(map) : null;
  }

  // Mettre à jour une liste
  Future<void> updateList(VocabularyList list) async {
    await _db.updateVocabularyList(list.id, list.toMap());
  }

  // Supprimer une liste
  Future<void> deleteList(String id) async {
    await _db.deleteVocabularyList(id);
  }

  // Récupérer les listes avec statistiques
  Future<List<Map<String, dynamic>>> getListsWithStats() async {
    final lists = await getAllLists();
    final results = <Map<String, dynamic>>[];

    for (var list in lists) {
      final totalConcepts = await _db.getConceptCountForList(list.id);
      final knownWords = await _db.getKnownWordsCountForList(list.id);

      results.add({
        'list': list,
        'totalConcepts': totalConcepts,
        'knownWords': knownWords,
        'progressPercent':
            totalConcepts > 0 ? (knownWords / totalConcepts * 100).round() : 0,
      });
    }

    return results;
  }

  // Mettre à jour le nombre total de concepts
  Future<void> updateTotalConcepts(String listId) async {
    final count = await _db.getConceptCountForList(listId);
    await _db.updateVocabularyList(listId, {'total_concepts': count});
  }

  // Marquer une liste comme téléchargée
  Future<void> markAsDownloaded(String listId) async {
    await _db.updateVocabularyList(listId, {
      'is_downloaded': 1,
      'download_status': 'completed',
    });
  }

  // Mettre à jour le statut de téléchargement
  Future<void> updateDownloadStatus(String listId, String status) async {
    await _db.updateVocabularyList(listId, {
      'download_status': status,
    });
  }
}
