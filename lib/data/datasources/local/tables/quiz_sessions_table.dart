import 'package:drift/drift.dart';

class QuizSessionsTable extends Table {
  @override
  String get tableName => 'quiz_sessions';

  TextColumn get id => text()();
  TextColumn get userId => text().named('user_id')();
  /// Nullable: list may be deleted, but we keep the history.
  TextColumn get listId => text().named('list_id').nullable()();
  /// Snapshot of the list name at the time of the session.
  TextColumn get listName => text().named('list_name')();
  /// QuizMode name (voice / flashcard / typing / handsFree).
  TextColumn get mode => text()();
  /// QuizDirectionChoice name (frToKo / koToFr / both).
  TextColumn get direction => text()();
  IntColumn get cardCount => integer().named('card_count')();
  IntColumn get correctCount => integer().named('correct_count')();
  IntColumn get durationSeconds => integer().named('duration_seconds')();
  /// Total mastered words across ALL lists at the moment the session ended.
  IntColumn get masteredWordCount => integer().named('mastered_word_count')();
  DateTimeColumn get completedAt => dateTime().named('completed_at')();

  @override
  Set<Column> get primaryKey => {id};
}
