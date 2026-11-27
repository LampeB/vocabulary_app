import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/quiz_sessions_table.dart';
import 'vocabulary_list_dao.dart';

part 'quiz_session_dao.g.dart';

@DriftAccessor(tables: [QuizSessionsTable])
class QuizSessionDao extends DatabaseAccessor<AppDatabase>
    with _$QuizSessionDaoMixin {
  QuizSessionDao(super.db);

  Future<void> insertSession(QuizSessionsTableCompanion companion) =>
      db.transaction(() async {
        final listId = companion.listId.value;
        var session = companion;
        if (listId != null) {
          final lists = db.vocabularyListDao;
          final canonicalId = await lists.resolveStarterId(
            StarterAliasKind.list,
            companion.userId.value,
            listId,
          );
          if (canonicalId != listId) {
            final canonical = await lists.getById(canonicalId);
            session = companion.copyWith(
              listId: Value(canonicalId),
              listName: canonical == null ? null : Value(canonical.name),
            );
          }
        }
        await into(quizSessionsTable).insert(session);
      });

  Future<List<QuizSessionsTableData>> getSessionsByUser(
    String userId, {
    int limit = 100,
  }) =>
      (select(quizSessionsTable)
            ..where((t) => t.userId.equals(userId))
            ..orderBy([(t) => OrderingTerm.desc(t.completedAt)])
            ..limit(limit))
          .get();

  /// All sessions that have a mastered-word count > 0, ascending by date —
  /// used to build the "mastered over time" line chart.
  Future<List<QuizSessionsTableData>> getMasteredOverTime(String userId) =>
      (select(quizSessionsTable)
            ..where((t) => t.userId.equals(userId))
            ..orderBy([(t) => OrderingTerm.asc(t.completedAt)]))
          .get();
}
