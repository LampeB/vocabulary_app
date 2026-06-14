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

  Future<VariantProgressTableData?> getByVariantAndDirection(
          String variantId, String direction) =>
      (select(variantProgressTable)
            ..where((t) =>
                t.variantId.equals(variantId) & t.direction.equals(direction)))
          .getSingleOrNull();

  Future<int> upsert(VariantProgressTableCompanion companion) =>
      into(variantProgressTable).insertOnConflictUpdate(companion);

  Future<List<VariantProgressTableData>> getUnsyncedProgress() =>
      (select(variantProgressTable)
            ..where((t) => t.isSynced.equals(false)))
          .get();
}
