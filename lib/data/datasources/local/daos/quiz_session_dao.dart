import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/quiz_sessions_table.dart';

part 'quiz_session_dao.g.dart';

@DriftAccessor(tables: [QuizSessionsTable])
class QuizSessionDao extends DatabaseAccessor<AppDatabase>
    with _$QuizSessionDaoMixin {
  QuizSessionDao(super.db);

  Future<void> insertSession(QuizSessionsTableCompanion companion) =>
      into(quizSessionsTable).insert(companion);

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
  Future<List<QuizSessionsTableData>> getMasteredOverTime(
      String userId) =>
      (select(quizSessionsTable)
            ..where((t) => t.userId.equals(userId))
            ..orderBy([(t) => OrderingTerm.asc(t.completedAt)]))
          .get();
}
