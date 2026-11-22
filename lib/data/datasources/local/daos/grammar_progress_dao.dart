import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/grammar_progress_table.dart';

part 'grammar_progress_dao.g.dart';

@DriftAccessor(tables: [GrammarProgressTable])
class GrammarProgressDao extends DatabaseAccessor<AppDatabase>
    with _$GrammarProgressDaoMixin {
  GrammarProgressDao(super.db);

  Stream<List<GrammarProgressTableData>> watchByUser(String userId) =>
      (select(grammarProgressTable)..where((t) => t.userId.equals(userId)))
          .watch();

  Future<GrammarProgressTableData?> get(String userId, String ruleId) =>
      (select(grammarProgressTable)
            ..where((t) =>
                t.userId.equals(userId) & t.ruleId.equals(ruleId)))
          .getSingleOrNull();

  /// Records one mastery-counting answer (callers must NOT record cartes).
  /// Sets [masteredAt] the first time [masteredWhenCorrectReaches] is hit.
  Future<GrammarProgressTableData> recordAnswer({
    required String userId,
    required String ruleId,
    required bool correct,
    required int masteredWhenCorrectReaches,
  }) async {
    final now = DateTime.now();
    final existing = await get(userId, ruleId);
    final shown = (existing?.shown ?? 0) + 1;
    final correctCount = (existing?.correct ?? 0) + (correct ? 1 : 0);
    final masteredAt = existing?.masteredAt ??
        (correctCount >= masteredWhenCorrectReaches ? now : null);
    await into(grammarProgressTable)
        .insertOnConflictUpdate(GrammarProgressTableCompanion(
      id: Value('$userId|$ruleId'),
      userId: Value(userId),
      ruleId: Value(ruleId),
      shown: Value(shown),
      correct: Value(correctCount),
      masteredAt: Value(masteredAt),
      isSynced: const Value(false),
      createdAt: Value(existing?.createdAt ?? now),
      updatedAt: Value(now),
    ));
    return (await get(userId, ruleId))!;
  }
}
