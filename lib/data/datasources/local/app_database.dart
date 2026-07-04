import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'tables/vocabulary_lists_table.dart';
import 'tables/concepts_table.dart';
import 'tables/word_variants_table.dart';
import 'tables/variant_progress_table.dart';
import 'tables/grammar_progress_table.dart';
import 'tables/quiz_sessions_table.dart';
import 'daos/vocabulary_list_dao.dart';
import 'daos/concept_dao.dart';
import 'daos/progress_dao.dart';
import 'daos/grammar_progress_dao.dart';
import 'daos/quiz_session_dao.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    VocabularyListsTable,
    ConceptsTable,
    WordVariantsTable,
    VariantProgressTable,
    QuizSessionsTable,
    GrammarProgressTable,
  ],
  daos: [
    VocabularyListDao,
    ConceptDao,
    ProgressDao,
    QuizSessionDao,
    GrammarProgressDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 7;

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
          if (from < 3) {
            // Language pair per list (generic-language-pairs epic); existing
            // lists are all FR/KR.
            await m.addColumn(vocabularyListsTable, vocabularyListsTable.langA);
            await m.addColumn(vocabularyListsTable, vocabularyListsTable.langB);
          }
          if (from < 4) {
            // Generic direction storage ('fr>ko') replaces the legacy enum
            // names. QuizDirection.parse still accepts the old form, but
            // queries compare exact strings — so rewrite in place.
            await customStatement(
                "UPDATE variant_progress SET direction = 'fr>ko' WHERE direction = 'frToKo'");
            await customStatement(
                "UPDATE variant_progress SET direction = 'ko>fr' WHERE direction = 'koToFr'");
          }
          if (from < 5) {
            // The sync_queue table never got a consumer — the isSynced flags
            // won as the outbound-queue mechanism (see data/sync/push_sync).
            await customStatement('DROP TABLE IF EXISTS sync_queue');
          }
          if (from < 6) {
            // List origin: user-created vs seeded starter vs premium packs.
            // Only 'user' lists count against the free quota.
            await m.addColumn(
                vocabularyListsTable, vocabularyListsTable.origin);
          }
          if (from < 7) {
            // Per-rule grammar mastery (the grammar feature's stage-2 gate).
            await m.createTable(grammarProgressTable);
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
