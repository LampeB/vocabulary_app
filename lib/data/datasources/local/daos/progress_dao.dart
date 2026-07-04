import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/variant_progress_table.dart';
import '../tables/word_variants_table.dart';

part 'progress_dao.g.dart';

@DriftAccessor(tables: [VariantProgressTable, WordVariantsTable])
class ProgressDao extends DatabaseAccessor<AppDatabase>
    with _$ProgressDaoMixin {
  ProgressDao(super.db);

  Stream<int> watchDueCount(String userId) {
    final now = DateTime.now();
    return (selectOnly(variantProgressTable)
          ..addColumns([variantProgressTable.id.count()])
          ..where(variantProgressTable.userId.equals(userId) &
              (variantProgressTable.nextReview.isNull() |
                  variantProgressTable.nextReview.isSmallerOrEqualValue(now))))
        .map((row) => row.read(variantProgressTable.id.count()) ?? 0)
        .watchSingle();
  }

  Future<List<VariantProgressTableData>> getDue({
    required String userId,
    required String direction,
    required List<String> variantIds,
    int limit = 20,
  }) {
    final now = DateTime.now();
    return (select(variantProgressTable)
          ..where((t) =>
              t.userId.equals(userId) &
              t.direction.equals(direction) &
              t.variantId.isIn(variantIds) &
              (t.nextReview.isNull() | t.nextReview.isSmallerOrEqualValue(now)))
          ..orderBy([
            (t) => OrderingTerm.asc(t.nextReview),
            (t) => OrderingTerm.asc(t.reps),
          ])
          ..limit(limit))
        .get();
  }

  /// Due rows for [userId]+[direction] across ALL lists (the "À réviser
  /// maintenant" smart list). "Due" = an existing progress row scheduled at or
  /// before now — never-studied words are not due. Soft-deleted variants are
  /// excluded via the join.
  Future<List<VariantProgressTableData>> getDueAcrossLists({
    required String userId,
    required String direction,
    int limit = 20,
  }) {
    final now = DateTime.now();
    final query = select(variantProgressTable).join([
      innerJoin(wordVariantsTable,
          wordVariantsTable.id.equalsExp(variantProgressTable.variantId)),
    ])
      ..where(variantProgressTable.userId.equals(userId) &
          variantProgressTable.direction.equals(direction) &
          wordVariantsTable.isDeleted.equals(false) &
          (variantProgressTable.nextReview.isNull() |
              variantProgressTable.nextReview.isSmallerOrEqualValue(now)))
      ..orderBy([
        OrderingTerm.asc(variantProgressTable.nextReview),
        OrderingTerm.asc(variantProgressTable.reps),
      ])
      ..limit(limit);
    return query.map((row) => row.readTable(variantProgressTable)).get();
  }

  /// Started rows (FSRS state ≠ newCard) for [userId]+[direction] across ALL
  /// lists (the "En cours d'apprentissage" smart list), due or not.
  Future<List<VariantProgressTableData>> getInProgressAcrossLists({
    required String userId,
    required String direction,
    int limit = 20,
  }) {
    final query = select(variantProgressTable).join([
      innerJoin(wordVariantsTable,
          wordVariantsTable.id.equalsExp(variantProgressTable.variantId)),
    ])
      ..where(variantProgressTable.userId.equals(userId) &
          variantProgressTable.direction.equals(direction) &
          wordVariantsTable.isDeleted.equals(false) &
          variantProgressTable.state.equals('newCard').not())
      ..orderBy([
        OrderingTerm.asc(variantProgressTable.nextReview),
        OrderingTerm.asc(variantProgressTable.reps),
      ])
      ..limit(limit);
    return query.map((row) => row.readTable(variantProgressTable)).get();
  }

  Future<VariantProgressTableData?> getByVariantAndDirection(
          String variantId, String direction) =>
      (select(variantProgressTable)
            ..where((t) =>
                t.variantId.equals(variantId) & t.direction.equals(direction)))
          .getSingleOrNull();

  Future<int> upsert(VariantProgressTableCompanion companion) =>
      into(variantProgressTable).insertOnConflictUpdate(companion);

  Future<List<String>> getExistingVariantIds({
    required String userId,
    required String direction,
    required List<String> variantIds,
  }) {
    return (selectOnly(variantProgressTable)
          ..addColumns([variantProgressTable.variantId])
          ..where(variantProgressTable.userId.equals(userId) &
              variantProgressTable.direction.equals(direction) &
              variantProgressTable.variantId.isIn(variantIds)))
        .map((row) => row.read(variantProgressTable.variantId)!)
        .get();
  }

  /// Returns ALL progress rows for the given variants (ignores nextReview date).
  /// Used as fallback when no cards are currently due — enables early review.
  Future<List<VariantProgressTableData>> getScheduledByVariants({
    required String userId,
    required String direction,
    required List<String> variantIds,
  }) {
    return (select(variantProgressTable)
          ..where((t) =>
              t.userId.equals(userId) &
              t.direction.equals(direction) &
              t.variantId.isIn(variantIds))
          ..orderBy([(t) => OrderingTerm.asc(t.nextReview)]))
        .get();
  }

  /// Progress rows (paired with their concept id) for every live variant of
  /// the given concepts — the raw material for per-list stats. Aggregation
  /// happens in the repository (lists are small; no SQL group-by needed).
  Future<List<({String conceptId, VariantProgressTableData progress})>>
      getProgressForConcepts({
    required String userId,
    required List<String> conceptIds,
  }) {
    final query = select(variantProgressTable).join([
      innerJoin(wordVariantsTable,
          wordVariantsTable.id.equalsExp(variantProgressTable.variantId)),
    ])
      ..where(variantProgressTable.userId.equals(userId) &
          wordVariantsTable.isDeleted.equals(false) &
          wordVariantsTable.conceptId.isIn(conceptIds));
    return query
        .map((row) => (
              conceptId: row.readTable(wordVariantsTable).conceptId,
              progress: row.readTable(variantProgressTable),
            ))
        .get();
  }

  /// All live variant ids belonging to the given concepts (any language).
  Future<List<String>> getVariantIdsForConcepts(List<String> conceptIds) =>
      (selectOnly(wordVariantsTable)
            ..addColumns([wordVariantsTable.id])
            ..where(wordVariantsTable.conceptId.isIn(conceptIds) &
                wordVariantsTable.isDeleted.equals(false)))
          .map((row) => row.read(wordVariantsTable.id)!)
          .get();

  /// Deletes this user's progress for the given variants — the "reset list
  /// progress" action. Rows are deleted (not zeroed) so the words become
  /// genuinely NEW cards again for the due/new quiz logic.
  Future<int> deleteProgressForVariants({
    required String userId,
    required List<String> variantIds,
  }) =>
      (delete(variantProgressTable)
            ..where((t) =>
                t.userId.equals(userId) & t.variantId.isIn(variantIds)))
          .go();

  Future<List<VariantProgressTableData>> getUnsyncedProgress() =>
      (select(variantProgressTable)
            ..where((t) => t.isSynced.equals(false)))
          .get();

  /// Returns all rows the user has mastered: FSRS review state with
  /// scheduledDays ≥ [minScheduledDays]. Ordered by scheduledDays descending
  /// so the most confidently-known words come first.
  Future<List<VariantProgressTableData>> getMasteredProgress({
    required String userId,
    int minScheduledDays = 21,
  }) =>
      (select(variantProgressTable)
            ..where((t) =>
                t.userId.equals(userId) &
                t.state.equals('review') &
                t.scheduledDays.isBiggerOrEqualValue(minScheduledDays))
            ..orderBy([(t) => OrderingTerm.desc(t.scheduledDays)]))
          .get();

  Future<int> markProgressSynced(List<String> ids) =>
      (update(variantProgressTable)..where((t) => t.id.isIn(ids)))
          .write(const VariantProgressTableCompanion(isSynced: Value(true)));
}
