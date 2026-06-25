import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'tables/vocabulary_lists_table.dart';
import 'tables/concepts_table.dart';
import 'tables/word_variants_table.dart';
import 'tables/variant_progress_table.dart';
import 'tables/sync_queue_table.dart';
import 'tables/quiz_sessions_table.dart';
import 'daos/vocabulary_list_dao.dart';
import 'daos/concept_dao.dart';
import 'daos/progress_dao.dart';
import 'daos/quiz_session_dao.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    VocabularyListsTable,
    ConceptsTable,
    WordVariantsTable,
    VariantProgressTable,
    SyncQueueTable,
    QuizSessionsTable,
  ],
  daos: [
    VocabularyListDao,
    ConceptDao,
    ProgressDao,
    QuizSessionDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _createIndexes();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(quizSessionsTable);
            await customStatement(
                'CREATE INDEX IF NOT EXISTS idx_sessions_user '
                'ON quiz_sessions(user_id, completed_at)');
          }
        },
      );

  Future<void> _createIndexes() async {
    await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_concepts_list_id ON concepts(list_id)');
    await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_variants_concept_id ON word_variants(concept_id, lang_code)');
    await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_progress_user_next ON variant_progress(user_id, next_review)');
    await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_progress_unsynced ON variant_progress(is_synced)');
    await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_sessions_user '
        'ON quiz_sessions(user_id, completed_at)');
  }

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'vocab_kr_db');
  }
}
