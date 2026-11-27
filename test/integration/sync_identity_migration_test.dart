import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/data/datasources/local/app_database.dart';

void main() {
  test(
    'v10 migration repairs imported token provenance and pending progress duplicates',
    () async {
      // Freeze the v10 columns touched by this migration, before either repair
      // existed. No production or user database is opened by this fixture.
      final db = AppDatabase.forTesting(
        NativeDatabase.memory(
          setup: (sqlite) {
            sqlite.execute(
              'CREATE TABLE vocabulary_lists(id TEXT PRIMARY KEY, visibility TEXT, share_token TEXT, is_synced INTEGER)',
            );
            sqlite.execute(
              "INSERT INTO vocabulary_lists VALUES('copy','private','source-token',1)",
            );
            sqlite.execute(
              'CREATE TABLE variant_progress(id TEXT PRIMARY KEY, user_id TEXT, variant_id TEXT, direction TEXT, is_synced INTEGER, updated_at INTEGER, reps INTEGER)',
            );
            sqlite.execute(
              "INSERT INTO variant_progress VALUES('server','u','word','fr>ko',1,300,3),('pending-old','u','word','fr>ko',0,100,1),('pending-new','u','word','fr>ko',0,200,2)",
            );
            sqlite.execute('PRAGMA user_version = 10');
          },
        ),
      );
      addTearDown(db.close);
      final copy = await db
          .customSelect('SELECT * FROM vocabulary_lists')
          .getSingle();
      expect(copy.readNullable<String>('share_token'), isNull);
      expect(copy.read<String>('imported_from_share_token'), 'source-token');
      expect(copy.read<int>('is_synced'), 0);
      final progress = await db
          .customSelect('SELECT id,reps FROM variant_progress')
          .get();
      expect(progress, hasLength(1));
      expect(progress.single.read<String>('id'), 'pending-new');
      expect(progress.single.read<int>('reps'), 2);
      await expectLater(
        db.customStatement(
          "INSERT INTO variant_progress VALUES('duplicate','u','word','fr>ko',0,400,4)",
        ),
        throwsA(
          predicate(
            (error) => error.toString().contains('UNIQUE constraint failed'),
          ),
        ),
      );
    },
  );
}
