import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/vocabulary_lists_table.dart';
import '../tables/concepts_table.dart';
import '../tables/word_variants_table.dart';

part 'vocabulary_list_dao.g.dart';

@DriftAccessor(tables: [VocabularyListsTable, ConceptsTable, WordVariantsTable])
class VocabularyListDao extends DatabaseAccessor<AppDatabase>
    with _$VocabularyListDaoMixin {
  VocabularyListDao(super.db);

  Stream<List<VocabularyListsTableData>> watchByOwner(String ownerId) =>
      (select(vocabularyListsTable)
            ..where((t) => t.ownerId.equals(ownerId) & t.isDeleted.equals(false))
            ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
          .watch();

  Future<VocabularyListsTableData?> getById(String id) =>
      (select(vocabularyListsTable)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<VocabularyListsTableData?> getByShareToken(String token) =>
      (select(vocabularyListsTable)..where((t) => t.shareToken.equals(token)))
          .getSingleOrNull();

  Future<int> upsert(VocabularyListsTableCompanion companion) =>
      into(vocabularyListsTable).insertOnConflictUpdate(companion);

  Future<int> softDelete(String id) => (update(vocabularyListsTable)
        ..where((t) => t.id.equals(id)))
      .write(VocabularyListsTableCompanion(
        isDeleted: const Value(true),
        isSynced: const Value(false),
        updatedAt: Value(DateTime.now()),
      ));

  Future<List<VocabularyListsTableData>> getUnsyncedLists() =>
      (select(vocabularyListsTable)..where((t) => t.isSynced.equals(false))).get();

  Future<int> updateWordCount(String listId, int newCount) =>
      (update(vocabularyListsTable)..where((t) => t.id.equals(listId))).write(
        VocabularyListsTableCompanion(
          wordCount: Value(newCount),
          updatedAt: Value(DateTime.now()),
          isSynced: const Value(false),
        ),
      );

  Future<int> setShareToken(String listId, String token) =>
      (update(vocabularyListsTable)..where((t) => t.id.equals(listId))).write(
        VocabularyListsTableCompanion(
          shareToken: Value(token),
          isSynced: const Value(false),
          updatedAt: Value(DateTime.now()),
        ),
      );
}
