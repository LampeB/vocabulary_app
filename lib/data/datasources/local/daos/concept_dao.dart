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

  Future<List<WordVariantsTableData>> getVariantsByConcept(String conceptId) =>
      (select(wordVariantsTable)
            ..where((t) =>
                t.conceptId.equals(conceptId) & t.isDeleted.equals(false))
            ..orderBy([(t) => OrderingTerm.asc(t.position)]))
          .get();

  Future<int> upsertVariant(WordVariantsTableCompanion companion) =>
      into(wordVariantsTable).insertOnConflictUpdate(companion);

  Future<int> softDeleteVariant(String id) => (update(wordVariantsTable)
        ..where((t) => t.id.equals(id)))
      .write(WordVariantsTableCompanion(
        isDeleted: const Value(true),
        isSynced: const Value(false),
        updatedAt: Value(DateTime.now()),
      ));
}
