import 'package:drift/drift.dart';

class QuizStudyDaysTable extends Table {
  @override
  String get tableName => 'quiz_study_days';

  TextColumn get userId => text()();

  /// The civil date captured at completion, in YYYY-MM-DD form. Replays
  /// must never reinterpret the history timestamp in the device's new zone.
  TextColumn get studyDate => text()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {userId, studyDate};
}
