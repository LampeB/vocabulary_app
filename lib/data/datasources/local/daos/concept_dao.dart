import 'package:drift/drift.dart';
import '../app_database.dart';
import '../sync_snapshot.dart';
import '../tables/concepts_table.dart';
import '../tables/word_variants_table.dart';
import 'vocabulary_list_dao.dart';

part 'concept_dao.g.dart';

@DriftAccessor(tables: [ConceptsTable, WordVariantsTable])
class ConceptDao extends DatabaseAccessor<AppDatabase> with _$ConceptDaoMixin {
  ConceptDao(super.db);

  SimpleSelectStatement<$ConceptsTableTable, ConceptsTableData> _conceptsByList(
    String listId, {
    String? ownerId,
    bool includeDeleted = false,
  }) {
    final query = select(conceptsTable)
      ..orderBy([
        (t) => OrderingTerm.asc(t.createdAt),
        (t) => OrderingTerm.asc(t.rowId),
      ]);
    if (!includeDeleted) query.where((t) => t.isDeleted.equals(false));
    if (ownerId == null) {
      query.where((t) => t.listId.equals(listId));
    } else {
      final lists = db.vocabularyListsTable;
      final resolved = db.vocabularyListDao.starterIdExpression(
        StarterAliasKind.list,
        ownerId,
        listId,
      );
      final ownedList = selectOnly(lists)
        ..addColumns([lists.id])
        ..where(
          lists.id.equalsExp(resolved) &
              lists.ownerId.equals(ownerId) &
              lists.isDeleted.equals(false),
        );
      query.where((t) => t.listId.isInQuery(ownedList));
    }
    return query;
  }

  Stream<List<ConceptsTableData>> watchByList(
    String listId, {
    String? ownerId,
  }) => _conceptsByList(listId, ownerId: ownerId).watch();

  Future<ConceptsTableData?> getById(String id) =>
      (select(conceptsTable)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<ConceptsTableData>> getConceptsByIds(List<String> ids) => (select(
    conceptsTable,
  )..where((t) => t.id.isIn(ids) & t.isDeleted.equals(false))).get();

  Future<List<WordVariantsTableData>> getVariantsByIds(List<String> ids) =>
      (select(
        wordVariantsTable,
      )..where((t) => t.id.isIn(ids) & t.isDeleted.equals(false))).get();

  Future<int> upsert(ConceptsTableCompanion companion) =>
      into(conceptsTable).insertOnConflictUpdate(companion);

  Future<int> softDelete(String id) =>
      (update(conceptsTable)..where((t) => t.id.equals(id))).write(
        ConceptsTableCompanion(
          isDeleted: const Value(true),
          isSynced: const Value(false),
          updatedAt: Value(DateTime.now()),
        ),
      );

  Future<List<ConceptsTableData>> getConceptsByList(
    String listId, {
    int? limit,
    bool includeDeleted = false,
  }) {
    final query = _conceptsByList(listId, includeDeleted: includeDeleted);
    if (limit != null) query.limit(limit);
    return query.get();
  }

  SimpleSelectStatement<$WordVariantsTableTable, WordVariantsTableData>
  _variantsByConcept(
    String conceptId, {
    String? ownerId,
    bool includeDeleted = false,
  }) {
    final query = select(wordVariantsTable)
      ..orderBy([(t) => OrderingTerm.asc(t.position)]);
    if (!includeDeleted) query.where((t) => t.isDeleted.equals(false));
    if (ownerId == null) {
      query.where((t) => t.conceptId.equals(conceptId));
    } else {
      final lists = db.vocabularyListsTable;
      final concepts = conceptsTable;
      final resolved = db.vocabularyListDao.starterIdExpression(
        StarterAliasKind.concept,
        ownerId,
        conceptId,
      );
      final ownedConcept =
          (selectOnly(concepts)..addColumns([concepts.id])).join([
            innerJoin(
              lists,
              lists.id.equalsExp(concepts.listId),
              useColumns: false,
            ),
          ])..where(
            concepts.id.equalsExp(resolved) &
                concepts.isDeleted.equals(false) &
                lists.ownerId.equals(ownerId) &
                lists.isDeleted.equals(false),
          );
      query.where((t) => t.conceptId.isInQuery(ownedConcept));
    }
    return query;
  }

  Future<List<WordVariantsTableData>> getVariantsByConcept(
    String conceptId, {
    String? ownerId,
    bool includeDeleted = false,
  }) => _variantsByConcept(
    conceptId,
    ownerId: ownerId,
    includeDeleted: includeDeleted,
  ).get();

  Stream<List<WordVariantsTableData>> watchVariantsByConcept(
    String conceptId, {
    String? ownerId,
  }) => _variantsByConcept(conceptId, ownerId: ownerId).watch();

  Future<List<WordVariantsTableData>> getVariantsByConceptIds(
    List<String> conceptIds,
    String langCode, {
    bool firstPerConcept = false,
  }) {
    final variants = wordVariantsTable;
    final query = select(variants)
      ..where(
        (t) =>
            t.conceptId.isIn(conceptIds) &
            t.langCode.equals(langCode) &
            t.isDeleted.equals(false),
      );
    if (firstPerConcept) {
      final preferred = alias(variants, 'preferred_variant');
      final preferredIds = selectOnly(preferred)
        ..addColumns([preferred.id])
        ..where(
          preferred.conceptId.equalsExp(variants.conceptId) &
              preferred.langCode.equals(langCode) &
              preferred.isDeleted.equals(false),
        )
        ..orderBy([
          OrderingTerm.asc(preferred.position),
          OrderingTerm.asc(preferred.rowId),
        ])
        ..limit(1);
      query.where(
        (t) => t.id.equalsExp(subqueryExpression<String>(preferredIds)),
      );
    }
    return query.get();
  }

  Future<WordVariantsTableData?> getVariantById(String id) => (select(
    wordVariantsTable,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Apply the rendered content's path without creating an outbound edit.
  /// The comparison and ancestor liveness check belong to the same write.
  Future<int> applyProvisionedAudio({
    required String variantId,
    required String? ownerId,
    required String word,
    required String langCode,
    required String path,
  }) {
    final lists = db.vocabularyListsTable;
    final liveConcepts = selectOnly(conceptsTable)
      ..addColumns([conceptsTable.id]);
    final live =
        liveConcepts.join([
          innerJoin(
            lists,
            lists.id.equalsExp(conceptsTable.listId),
            useColumns: false,
          ),
        ])..where(
          conceptsTable.isDeleted.equals(false) & lists.isDeleted.equals(false),
        );
    if (ownerId != null) live.where(lists.ownerId.equals(ownerId));

    return (update(wordVariantsTable)..where(
          (t) =>
              t.id.equals(variantId) &
              t.word.equals(word) &
              t.langCode.equals(langCode) &
              t.isDeleted.equals(false) &
              t.conceptId.isInQuery(live) &
              (t.audioPath.isNull() | t.audioPath.equals(path).not()),
        ))
        .write(WordVariantsTableCompanion(audioPath: Value(path)));
  }

  Future<int> upsertVariant(WordVariantsTableCompanion companion) =>
      into(wordVariantsTable).insertOnConflictUpdate(companion);

  Future<int> softDeleteVariant(String id) =>
      (update(wordVariantsTable)..where((t) => t.id.equals(id))).write(
        WordVariantsTableCompanion(
          isDeleted: const Value(true),
          isSynced: const Value(false),
          updatedAt: Value(DateTime.now()),
        ),
      );

  /// Retro-tags a pre-catalog concept with its registry seed id
  /// (legacy adoption — see StarterSeeder).
  Future<int> stampSeedId(String conceptId, String seedId) =>
      (update(conceptsTable)..where((t) => t.id.equals(conceptId))).write(
        ConceptsTableCompanion(
          seedId: Value(seedId),
          isSynced: const Value(false),
          updatedAt: Value(DateTime.now()),
        ),
      );

  Future<int> countByList(String listId) async {
    final count = countAll();
    final query = selectOnly(conceptsTable)
      ..addColumns([count])
      ..where(
        conceptsTable.listId.equals(listId) &
            conceptsTable.isDeleted.equals(false),
      );
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  // Acknowledged descendants are evidence for lists persisted by an older app
  // version which had not yet recorded established starter identities.
  Future<bool> hasSyncedContents(String listId) => customSelect(
    'SELECT EXISTS (SELECT 1 FROM concepts c WHERE c.list_id = ? '
    'AND (c.is_synced = 1 OR EXISTS (SELECT 1 FROM word_variants w '
    'WHERE w.concept_id = c.id AND w.is_synced = 1))) AS synced',
    variables: [Variable(listId)],
  ).map((row) => row.read<bool>('synced')).getSingle();

  Future<Set<String>> getVariantIdsByLists(Set<String> listIds) async {
    if (listIds.isEmpty) return {};
    final variants = selectOnly(wordVariantsTable)
      ..addColumns([wordVariantsTable.id]);
    final joined = variants.join([
      innerJoin(
        conceptsTable,
        conceptsTable.id.equalsExp(wordVariantsTable.conceptId),
        useColumns: false,
      ),
    ])..where(conceptsTable.listId.isIn(listIds));
    return (await joined.map((row) => row.read(wordVariantsTable.id)!).get())
        .toSet();
  }

  Future<void> refreshListWordCount(String listId) async {
    await db.vocabularyListDao.refreshWordCount(
      listId,
      await countByList(listId),
    );
  }

  // ── Push-sync support (the isSynced flags are the outbound queue) ──────────

  Future<List<ConceptsTableData>> getUnsyncedConcepts({
    String? ownerId,
    String? listId,
  }) {
    final pending =
        conceptsTable.isSynced.equals(false) &
        (listId == null
            ? const Constant(true)
            : conceptsTable.listId.equals(listId));
    if (ownerId == null) {
      return (select(conceptsTable)..where((_) => pending)).get();
    }
    final query = select(conceptsTable).join([
      innerJoin(
        db.vocabularyListsTable,
        db.vocabularyListsTable.id.equalsExp(conceptsTable.listId),
      ),
    ])..where(pending);
    query.where(db.vocabularyListsTable.ownerId.equals(ownerId));
    return query.map((row) => row.readTable(conceptsTable)).get();
  }

  Future<List<WordVariantsTableData>> getUnsyncedVariants({
    String? ownerId,
    String? listId,
  }) {
    if (ownerId == null && listId == null) {
      return (select(
        wordVariantsTable,
      )..where((t) => t.isSynced.equals(false))).get();
    }
    final query = select(wordVariantsTable).join([
      innerJoin(
        conceptsTable,
        conceptsTable.id.equalsExp(wordVariantsTable.conceptId),
      ),
      innerJoin(
        db.vocabularyListsTable,
        db.vocabularyListsTable.id.equalsExp(conceptsTable.listId),
      ),
    ])..where(wordVariantsTable.isSynced.equals(false));
    if (ownerId != null) {
      query.where(db.vocabularyListsTable.ownerId.equals(ownerId));
    }
    if (listId != null) query.where(conceptsTable.listId.equals(listId));
    return query.map((row) => row.readTable(wordVariantsTable)).get();
  }

  Future<int> markConceptsSynced(List<String> ids) =>
      (update(conceptsTable)..where((t) => t.id.isIn(ids))).write(
        const ConceptsTableCompanion(isSynced: Value(true)),
      );

  Future<int> markVariantsSynced(List<String> ids) =>
      (update(wordVariantsTable)..where((t) => t.id.isIn(ids))).write(
        const WordVariantsTableCompanion(isSynced: Value(true)),
      );

  Future<int> acknowledgeConcept(ConceptsTableData row) =>
      acknowledgeSyncSnapshot(this, conceptsTable, row);

  Future<int> acknowledgeVariant(WordVariantsTableData row) =>
      acknowledgeSyncSnapshot(this, wordVariantsTable, row);

  /// The caller applies the parent tombstone in the same transaction.
  Future<void> tombstoneListContents(String listId, String userId) async {
    final ids =
        await (selectOnly(conceptsTable)
              ..addColumns([conceptsTable.id])
              ..where(conceptsTable.listId.equals(listId)))
            .map((row) => row.read(conceptsTable.id)!)
            .get();
    if (ids.isEmpty) return;
    await (update(conceptsTable)..where((t) => t.id.isIn(ids))).write(
      const ConceptsTableCompanion(
        isDeleted: Value(true),
        isSynced: Value(true),
      ),
    );
    await db.vocabularyListDao.forgetSharedImportBases(ids);
    await tombstoneConceptContents(ids, userId);
  }

  Future<void> tombstoneConceptContents(
    List<String> conceptIds,
    String userId,
  ) async {
    final ids =
        await (selectOnly(wordVariantsTable)
              ..addColumns([wordVariantsTable.id])
              ..where(wordVariantsTable.conceptId.isIn(conceptIds)))
            .map((row) => row.read(wordVariantsTable.id)!)
            .get();
    if (ids.isEmpty) return;
    await (update(wordVariantsTable)..where((t) => t.id.isIn(ids))).write(
      const WordVariantsTableCompanion(
        isDeleted: Value(true),
        isSynced: Value(true),
      ),
    );
    await db.vocabularyListDao.forgetSharedImportBases(ids);
    await db.progressDao.deleteProgressForVariants(
      userId: userId,
      variantIds: ids,
    );
  }
}
