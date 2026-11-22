import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/data/datasources/local/app_database.dart';

import '../../patrol_test/helpers/reset_account.dart';

void main() {
  late AppDatabase db;
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    // Force schema creation before enabling FK checks.
    await db.customSelect('SELECT 1').get();
    await db.customStatement('PRAGMA foreign_keys = ON');
    await db.customStatement(
        "INSERT INTO vocabulary_lists (id, owner_id, name, created_at, updated_at) VALUES ('list','test','fixture',0,0)");
    await db.customStatement(
        "INSERT INTO concepts (id,list_id,created_at,updated_at) VALUES ('concept','list',0,0)");
    await db.customStatement(
        "INSERT INTO word_variants (id,concept_id,word,lang_code,created_at,updated_at) VALUES ('variant','concept','bonjour','fr',0,0)");
    await db.customStatement(
        "INSERT INTO variant_progress (id,user_id,variant_id,direction,created_at,updated_at) VALUES ('progress','test','variant','fr>ko',0,0)");
    await db.customStatement(
        "INSERT INTO grammar_progress (id,user_id,rule_id,created_at,updated_at) VALUES ('grammar','test','rule',0,0)");
    await db.customStatement(
        "INSERT INTO quiz_sessions (id,user_id,list_name,mode,direction,card_count,correct_count,duration_seconds,mastered_word_count,completed_at) VALUES ('session','test','fixture','typing','frToKo',1,1,1,1,0)");
    await db.customStatement(
        "INSERT INTO review_events (id,user_id,variant_id,direction,mode,correct,rating,created_at) VALUES ('event','test','variant','fr>ko','typing',1,'good',0)");
  });
  tearDown(() => db.close());

  test('reset empties vocabulary, progress and local history with FK checks',
      () async {
    await resetLocalDatabase(db);
    await resetLocalDatabase(db);
    for (final table in db.allTables) {
      expect(await db.select(table).get(), isEmpty,
          reason: table.actualTableName);
    }
  });

  test('a failed delete rolls back the entire local reset', () async {
    await db.customStatement(
        "CREATE TRIGGER deny_reset BEFORE DELETE ON vocabulary_lists BEGIN SELECT RAISE(ABORT, 'injected reset failure'); END");
    await expectLater(resetLocalDatabase(db), throwsA(isA<Exception>()));
    for (final table in db.allTables) {
      expect(await db.select(table).get(), hasLength(1),
          reason: table.actualTableName);
    }
  });
}
