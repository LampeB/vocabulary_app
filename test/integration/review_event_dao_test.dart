import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/data/datasources/local/app_database.dart';

/// The review-event log (stats observability): insert → drain-by-unsynced →
/// mark-synced is the outbound queue the PushSync drain relies on.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  ReviewEventsTableCompanion evt(String id, {bool synced = false}) =>
      ReviewEventsTableCompanion.insert(
        id: id,
        userId: 'u1',
        variantId: 'v1',
        direction: 'fr>ko',
        mode: 'voice',
        correct: true,
        rating: 'good',
        createdAt: DateTime(2026, 7, 14),
        isSynced: Value(synced),
        responseTimeMs: const Value(1200),
      );

  test('insert → getUnsynced returns only unsynced → markSynced clears them',
      () async {
    await db.reviewEventDao.insertEvent(evt('a'));
    await db.reviewEventDao.insertEvent(evt('b'));
    await db.reviewEventDao.insertEvent(evt('c', synced: true));

    final unsynced = await db.reviewEventDao.getUnsynced();
    expect(unsynced.map((e) => e.id).toSet(), {'a', 'b'});

    await db.reviewEventDao.markSynced(['a', 'b']);
    expect(await db.reviewEventDao.getUnsynced(), isEmpty);
  });

  test('getByUser returns the user rows, newest first', () async {
    await db.reviewEventDao.insertEvent(evt('a'));
    final rows = await db.reviewEventDao.getByUser('u1');
    expect(rows, hasLength(1));
    expect(rows.first.responseTimeMs, 1200);
    expect(rows.first.correct, isTrue);
    expect(await db.reviewEventDao.getByUser('other'), isEmpty);
  });
}
