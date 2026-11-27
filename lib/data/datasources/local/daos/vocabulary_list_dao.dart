import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:drift/drift.dart';
import '../app_database.dart';
import '../sync_snapshot.dart';
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
            ..where(
              (t) => t.ownerId.equals(ownerId) & t.isDeleted.equals(false),
            )
            ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
          .watch();

  Future<VocabularyListsTableData?> getById(String id) => (select(
    vocabularyListsTable,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Stream<VocabularyListsTableData?> watchById(String id) => (select(
    vocabularyListsTable,
  )..where((t) => t.id.equals(id))).watchSingleOrNull();

  Future<VocabularyListsTableData?> getByShareToken(
    String token, {
    String? ownerId,
  }) =>
      (select(vocabularyListsTable)..where(
            (t) =>
                t.shareToken.equals(token) &
                (ownerId == null
                    ? const Constant(true)
                    : t.ownerId.equals(ownerId)) &
                t.isDeleted.equals(false),
          ))
          .getSingleOrNull();

  Future<int> upsert(VocabularyListsTableCompanion companion) =>
      into(vocabularyListsTable).insertOnConflictUpdate(companion);

  Future<VocabularyListsTableData?> getImportedCopy(
    String token,
    String ownerId,
  ) =>
      (select(vocabularyListsTable)
            ..where(
              (t) =>
                  t.ownerId.equals(ownerId) &
                  t.importedFromShareToken.equals(token) &
                  t.isDeleted.equals(false),
            )
            ..orderBy([
              (t) => OrderingTerm.asc(t.createdAt),
              (t) => OrderingTerm.asc(t.id),
            ])
            ..limit(1))
          .getSingleOrNull();

  Future<List<String>> getPendingListIds({String? ownerId}) => customSelect(
    'SELECT l.id FROM vocabulary_lists l '
    'WHERE (? IS NULL OR l.owner_id = ?) AND (l.is_synced = 0 '
    'OR EXISTS(SELECT 1 FROM concepts c WHERE c.list_id = l.id AND c.is_synced = 0) '
    'OR EXISTS(SELECT 1 FROM concepts c JOIN word_variants w ON w.concept_id = c.id '
    'WHERE c.list_id = l.id AND w.is_synced = 0))',
    variables: [Variable<String>(ownerId), Variable<String>(ownerId)],
  ).map((row) => row.read<String>('id')).get();

  /// The common base for a shared import until all of its edits are acknowledged.
  Future<void> rememberSharedImport(String id, DataClass row) =>
      into(db.sharedImportBootstrapTable).insertOnConflictUpdate(
        SharedImportBootstrapTableCompanion.insert(
          id: id,
          snapshot: jsonEncode(row.toJson()),
        ),
      );

  Future<Map<String, dynamic>?> getSharedImportBase(String id) async {
    final initial = await (select(
      db.sharedImportBootstrapTable,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return initial == null
        ? null
        : jsonDecode(initial.snapshot) as Map<String, dynamic>;
  }

  Future<void> forgetSharedImportBases(Iterable<String> ids) => (delete(
    db.sharedImportBootstrapTable,
  )..where((t) => t.id.isIn(ids))).go();

  Future<int> softDelete(String id) =>
      (update(vocabularyListsTable)..where((t) => t.id.equals(id))).write(
        VocabularyListsTableCompanion(
          isDeleted: const Value(true),
          isSynced: const Value(false),
          updatedAt: Value(DateTime.now()),
        ),
      );

  Future<List<VocabularyListsTableData>> getUnsyncedLists({String? ownerId}) =>
      (select(vocabularyListsTable)..where(
            (t) =>
                t.isSynced.equals(false) &
                (ownerId == null
                    ? const Constant(true)
                    : t.ownerId.equals(ownerId)),
          ))
          .get();

  Future<int> updateWordCount(String listId, int newCount) =>
      (update(vocabularyListsTable)..where((t) => t.id.equals(listId))).write(
        VocabularyListsTableCompanion(
          wordCount: Value(newCount),
          updatedAt: Value(DateTime.now()),
          isSynced: const Value(false),
        ),
      );

  Future<int> setShareToken(
    String listId,
    String token, {
    bool publish = false,
  }) => (update(vocabularyListsTable)..where((t) => t.id.equals(listId))).write(
    VocabularyListsTableCompanion(
      shareToken: Value(token),
      visibility: publish ? const Value('public') : const Value.absent(),
      isSynced: const Value(false),
      updatedAt: Value(DateTime.now()),
    ),
  );

  /// Sharing requires the complete list payload, not merely an acknowledged
  /// token. Unrelated pending rows from other lists must not block sharing.
  Future<bool> hasPendingContents(String listId) async {
    final row = await customSelect(
      'SELECT EXISTS(SELECT 1 FROM concepts WHERE list_id = ? AND is_synced = 0) '
      'OR EXISTS(SELECT 1 FROM word_variants w JOIN concepts c ON c.id = w.concept_id '
      'WHERE c.list_id = ? AND w.is_synced = 0) AS pending',
      variables: [Variable<String>(listId), Variable<String>(listId)],
    ).getSingle();
    return row.read<int>('pending') != 0;
  }

  /// Refresh a derived count after pull without manufacturing a local edit.
  Future<int> refreshWordCount(String listId, int count) =>
      (update(vocabularyListsTable)..where(
            (t) => t.id.equals(listId) & t.wordCount.equals(count).not(),
          ))
          .write(VocabularyListsTableCompanion(wordCount: Value(count)));

  /// Retro-tags a pre-catalog starter list with its stable seed identity
  /// (legacy adoption — see StarterSeeder).
  Future<int> stampSeedIdentity(
    String listId,
    String seedId,
    String langA,
    String langB,
  ) => (update(vocabularyListsTable)..where((t) => t.id.equals(listId))).write(
    VocabularyListsTableCompanion(
      seedId: Value(seedId),
      langA: Value(langA),
      langB: Value(langB),
      isSynced: const Value(false),
      updatedAt: Value(DateTime.now()),
    ),
  );

  Future<int> markListsSynced(List<String> ids) =>
      (update(vocabularyListsTable)..where((t) => t.id.isIn(ids))).write(
        const VocabularyListsTableCompanion(isSynced: Value(true)),
      );

  Future<int> acknowledge(VocabularyListsTableData row) =>
      acknowledgeSyncSnapshot(this, vocabularyListsTable, row);
}
