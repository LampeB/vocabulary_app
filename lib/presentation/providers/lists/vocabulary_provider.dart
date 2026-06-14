import 'dart:async' show unawaited;
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import '../../../core/errors/failure.dart';
import '../auth/auth_provider.dart';

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
          String name, String? description) =>
      _repo.createList(name: name, description: description);

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
    final conceptResult = await _repo.createConcept(
        listId: listId, notes: notes, category: category);
    return conceptResult.fold(
      onSuccess: (concept) async {
        unawaited(_repo.createVariant(
            conceptId: concept.id,
            word: frWord,
            langCode: 'fr',
            isPrimary: true));
        unawaited(_repo.createVariant(
            conceptId: concept.id,
            word: koWord,
            langCode: 'ko',
            isPrimary: true));
        return Success(concept);
      },
      onFailure: (e) async => Failure(e),
    );
  }

  Future<Result<void>> deleteConcept(String conceptId) =>
      _repo.deleteConcept(conceptId);
}
