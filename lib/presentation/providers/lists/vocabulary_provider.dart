import 'dart:async' show unawaited;
import 'dart:convert' show jsonDecode, jsonEncode;
import 'dart:io' show File;
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../data/datasources/local/app_database.dart';
import '../../../data/datasources/local/daos/vocabulary_list_dao.dart';
import '../../../data/datasources/local/daos/concept_dao.dart';
import '../../../data/datasources/local/daos/progress_dao.dart';
import '../../../data/datasources/remote/vocabulary_remote_datasource.dart';
import '../../../data/repositories/vocabulary_repository_impl.dart';
import '../../../domain/entities/vocabulary_list.dart';
import '../../../domain/entities/concept.dart';
import '../../../domain/entities/word_variant.dart';
import '../../../domain/repositories/vocabulary_repository.dart';
import '../../../core/config/app_config.dart';
import '../../../core/errors/failure.dart';
import '../../../core/errors/app_exception.dart';
import '../auth/auth_provider.dart';
import '../purchases/purchase_provider.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final vocabularyListDaoProvider = Provider<VocabularyListDao>(
  (ref) => ref.watch(appDatabaseProvider).vocabularyListDao,
);

final conceptDaoProvider = Provider<ConceptDao>(
  (ref) => ref.watch(appDatabaseProvider).conceptDao,
);

final progressDaoProvider = Provider<ProgressDao>(
  (ref) => ref.watch(appDatabaseProvider).progressDao,
);

final vocabularyRemoteProvider = Provider<VocabularyRemoteDataSource>(
  (ref) => VocabularyRemoteDataSource(ref.watch(supabaseClientProvider)),
);

final vocabularyRepositoryProvider = Provider<VocabularyRepository>((ref) {
  final userId = ref.watch(currentUserProvider)?.id ?? '';
  return VocabularyRepositoryImpl(
    ref.watch(vocabularyListDaoProvider),
    ref.watch(conceptDaoProvider),
    ref.watch(vocabularyRemoteProvider),
    userId,
    ref.watch(appDatabaseProvider),
  );
});

// Streams local DB — auto-updates whenever a list changes.
final myListsProvider = StreamProvider<List<VocabularyList>>((ref) {
  return ref.watch(vocabularyRepositoryProvider).watchMyLists();
});

// Fetches metadata for a single list (for AppBar titles etc.).
final listInfoProvider =
    FutureProvider.family<VocabularyList?, String>((ref, listId) {
  return ref
      .watch(vocabularyRepositoryProvider)
      .getListById(listId)
      .then((r) => r.valueOrNull);
});

// Streams concepts for a given list.
final listDetailProvider =
    StreamProvider.family<List<Concept>, String>((ref, listId) {
  return ref.watch(vocabularyRepositoryProvider).watchConcepts(listId);
});

// Fetches variants for a concept (cached per conceptId).
final variantsProvider =
    FutureProvider.family<List<WordVariant>, String>((ref, conceptId) {
  return ref
      .watch(vocabularyRepositoryProvider)
      .getVariants(conceptId)
      .then((r) => r.valueOrNull ?? []);
});

// Streams the number of cards due for review today.
final dueCountProvider = StreamProvider<int>((ref) {
  final userId = ref.watch(currentUserProvider)?.id ?? '';
  if (userId.isEmpty) return Stream.value(0);
  return ref.watch(progressDaoProvider).watchDueCount(userId);
});

// Pulls the user's lists from Supabase into the local DB on login.
// Watchers (myListsProvider) update automatically when Drift rows change.
final syncOnLoginProvider = FutureProvider<void>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return;
  await ref.watch(vocabularyRepositoryProvider).syncFromRemote();
});

final listActionsProvider =
    NotifierProvider<ListActionsNotifier, void>(ListActionsNotifier.new);

class ListActionsNotifier extends Notifier<void> {
  @override
  void build() {}

  VocabularyRepository get _repo => ref.read(vocabularyRepositoryProvider);

  Future<Result<VocabularyList>> createList(
      String name, String? description) async {
    if (!ref.read(isPremiumProvider)) {
      final count = ref.read(myListsProvider).valueOrNull?.length ?? 0;
      if (count >= AppConfig.maxFreeVocabLists) {
        return const Failure(QuotaExceededException(
          'Free plan includes ${AppConfig.maxFreeVocabLists} lists. Upgrade to create more.',
        ));
      }
    }
    return _repo.createList(name: name, description: description);
  }

  Future<Result<VocabularyList>> renameList(
      String listId, String newName) async {
    final r = await _repo.getListById(listId);
    return r.fold(
      onSuccess: (list) => _repo.updateList(list.copyWith(name: newName)),
      onFailure: (e) async => Failure(e),
    );
  }

  Future<Result<void>> deleteList(String listId) =>
      _repo.deleteList(listId);

  Future<Result<Concept>> addConcept({
    required String listId,
    required String frWord,
    required String koWord,
    String? notes,
    String? category,
  }) async {
    if (!ref.read(isPremiumProvider)) {
      final listResult = await _repo.getListById(listId);
      if (listResult case Success(:final value)) {
        if (value.wordCount >= AppConfig.maxFreeWordsPerList) {
          return const Failure(QuotaExceededException(
            'Free plan includes ${AppConfig.maxFreeWordsPerList} words per list. Upgrade for unlimited words.',
          ));
        }
      }
    }
    return _repo.addConceptWithVariants(
      listId: listId,
      frWord: frWord,
      koWord: koWord,
      notes: notes,
      category: category,
    );
  }

  Future<Result<void>> deleteConcept(String conceptId) =>
      _repo.deleteConcept(conceptId);

  // Returns an error message on failure, null on success.
  Future<String?> exportList(String listId, String listName) async {
    final result = await _repo.exportToJson(listId);
    if (result.isFailure) {
      return result.exceptionOrNull?.message ?? 'Export failed';
    }
    try {
      final jsonStr = jsonEncode(result.valueOrNull!);
      final dir = await getTemporaryDirectory();
      final safeName = listName.replaceAll(RegExp(r'[^\w ]'), '_').trim();
      final file = File('${dir.path}/${safeName}_vocabkr.json');
      await file.writeAsString(jsonStr);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/json')],
        subject: '$listName — VocabKR Export',
      );
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // Returns null if the user cancelled, Result<VocabularyList> otherwise.
  Future<Result<VocabularyList>?> importList() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (picked == null || picked.files.isEmpty) return null;

    final path = picked.files.single.path;
    if (path == null) {
      return const Failure(StorageException('No file path available'));
    }

    try {
      final content = await File(path).readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      return _repo.importFromJson(json);
    } catch (_) {
      return const Failure(StorageException('Invalid JSON file'));
    }
  }

  // Generates a share token, saves it, and opens the native share sheet.
  Future<Result<String>> generateAndShareLink(
      String listId, String listName) async {
    final result = await _repo.generateShareLink(listId);
    if (result.isFailure) return result;
    await Share.share(result.valueOrNull!, subject: '$listName — VocabKR');
    return result;
  }

  // Imports a publicly shared list by its share token (from a deep link).
  Future<Result<VocabularyList>> importFromLink(String token) =>
      _repo.importFromShareToken(token);
}
