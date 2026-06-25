import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/concepts_table.dart';
import '../tables/word_variants_table.dart';

part 'concept_dao.g.dart';

@DriftAccessor(tables: [ConceptsTable, WordVariantsTable])
class ConceptDao extends DatabaseAccessor<AppDatabase>
    with _$ConceptDaoMixin {
  ConceptDao(super.db);

  Stream<List<ConceptsTableData>> watchByList(String listId) =>
      (select(conceptsTable)
            ..where((t) => t.listId.equals(listId) & t.isDeleted.equals(false))
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .watch();

  Future<ConceptsTableData?> getById(String id) =>
      (select(conceptsTable)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> upsert(ConceptsTableCompanion companion) =>
      into(conceptsTable).insertOnConflictUpdate(companion);

  Future<int> softDelete(String id) => (update(conceptsTable)
        ..where((t) => t.id.equals(id)))
      .write(ConceptsTableCompanion(
        isDeleted: const Value(true),
        isSynced: const Value(false),
        updatedAt: Value(DateTime.now()),
      ));

  Future<List<ConceptsTableData>> getConceptsByList(String listId) =>
      (select(conceptsTable)
            ..where((t) =>
                t.listId.equals(listId) & t.isDeleted.equals(false)))
          .get();

  Future<List<WordVariantsTableData>> getVariantsByConcept(String conceptId) =>
      (select(wordVariantsTable)
            ..where((t) =>
                t.conceptId.equals(conceptId) & t.isDeleted.equals(false))
            ..orderBy([(t) => OrderingTerm.asc(t.position)]))
          .get();

  Future<List<WordVariantsTableData>> getVariantsByConceptIds(
      List<String> conceptIds, String langCode) =>
      (select(wordVariantsTable)
            ..where((t) =>
                t.conceptId.isIn(conceptIds) &
                t.langCode.equals(langCode) &
                t.isDeleted.equals(false)))
          .get();

  Future<WordVariantsTableData?> getVariantById(String id) =>
      (select(wordVariantsTable)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  Future<int> upsertVariant(WordVariantsTableCompanion companion) =>
      into(wordVariantsTable).insertOnConflictUpdate(companion);

  Future<int> softDeleteVariant(String id) => (update(wordVariantsTable)
        ..where((t) => t.id.equals(id)))
      .write(WordVariantsTableCompanion(
        isDeleted: const Value(true),
        isSynced: const Value(false),
        updatedAt: Value(DateTime.now()),
      ));

  Future<int> countByList(String listId) async {
    final count = countAll();
    final query = selectOnly(conceptsTable)
      ..addColumns([count])
      ..where(conceptsTable.listId.equals(listId) &
          conceptsTable.isDeleted.equals(false));
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }
}
