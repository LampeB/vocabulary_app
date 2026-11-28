import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/quiz_sessions_table.dart';
import '../tables/quiz_study_days_table.dart';
import 'vocabulary_list_dao.dart';

part 'quiz_session_dao.g.dart';

@DriftAccessor(tables: [QuizSessionsTable, QuizStudyDaysTable])
class QuizSessionDao extends DatabaseAccessor<AppDatabase>
    with _$QuizSessionDaoMixin {
  QuizSessionDao(super.db);

  Future<void> insertSession(
    QuizSessionsTableCompanion companion, {
    required DateTime studyDate,
  }) => db.transaction(() async {
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
    await into(quizStudyDaysTable).insert(
      QuizStudyDaysTableCompanion.insert(
        userId: session.userId.value,
        studyDate: studyDate.toIso8601String().split('T').first,
      ),
      onConflict: DoNothing(),
    );
  });

  Future<List<String>> pendingStudyDays(String userId) async {
    final rows =
        await (select(quizStudyDaysTable)
              ..where((t) => t.userId.equals(userId) & t.isSynced.equals(false))
              ..orderBy([(t) => OrderingTerm.asc(t.studyDate)]))
            .get();
    return rows.map((row) => row.studyDate).toList();
  }

  Future<void> acknowledgeStudyDay(String userId, String studyDate) =>
      (update(quizStudyDaysTable)..where(
            (t) => t.userId.equals(userId) & t.studyDate.equals(studyDate),
          ))
          .write(const QuizStudyDaysTableCompanion(isSynced: Value(true)));

  /// Includes acknowledged dates. A timestamp from legacy history cannot
  /// reconstruct the civil date captured in the device's original time zone.
  Future<bool> hasStudyDay(String userId, DateTime day) async =>
      await (select(quizStudyDaysTable)..where(
            (t) =>
                t.userId.equals(userId) &
                t.studyDate.equals(day.toIso8601String().split('T').first),
          ))
          .getSingleOrNull() !=
      null;

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
