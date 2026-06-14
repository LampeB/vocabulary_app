import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/datasources/local/app_database.dart';
import '../../../data/datasources/local/daos/vocabulary_list_dao.dart';
import '../../../data/datasources/local/daos/concept_dao.dart';
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

final myListsProvider = StreamProvider<List<VocabularyList>>((ref) {
  return ref.watch(vocabularyRepositoryProvider).watchMyLists();
});

final listDetailProvider =
    StreamProvider.family<List<Concept>, String>((ref, listId) {
  return ref.watch(vocabularyRepositoryProvider).watchConcepts(listId);
});

final variantsProvider =
    FutureProvider.family<List<WordVariant>, String>((ref, conceptId) {
  return ref
      .watch(vocabularyRepositoryProvider)
      .getVariants(conceptId)
      .then((r) => r.valueOrNull ?? []);
});

final listActionsProvider =
    NotifierProvider<ListActionsNotifier, void>(ListActionsNotifier.new);

class ListActionsNotifier extends Notifier<void> {
  @override
  void build() {}

  Future<Result<VocabularyList>> createList(
          String name, String? description) =>
      ref
          .read(vocabularyRepositoryProvider)
          .createList(name: name, description: description);

  Future<Result<void>> deleteList(String listId) =>
      ref.read(vocabularyRepositoryProvider).deleteList(listId);

  Future<Result<Concept>> addConcept({
    required String listId,
    required String frWord,
    required String koWord,
    String? notes,
    String? category,
  }) async {
    final repo = ref.read(vocabularyRepositoryProvider);
    final conceptResult = await repo.createConcept(
        listId: listId, notes: notes, category: category);
    return conceptResult.fold(
      onSuccess: (concept) async {
        await repo.createVariant(
            conceptId: concept.id,
            word: frWord,
            langCode: 'fr',
            isPrimary: true);
        await repo.createVariant(
            conceptId: concept.id,
            word: koWord,
            langCode: 'ko',
            isPrimary: true);
        return Success(concept);
      },
      onFailure: (e) => Failure(e),
    );
  }
}
