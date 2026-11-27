import 'package:drift/drift.dart';
import '../app_database.dart';
import '../sync_snapshot.dart';
import '../tables/review_events_table.dart';
import 'vocabulary_list_dao.dart';

part 'review_event_dao.g.dart';

@DriftAccessor(tables: [ReviewEventsTable])
class ReviewEventDao extends DatabaseAccessor<AppDatabase>
    with _$ReviewEventDaoMixin {
  ReviewEventDao(super.db);

  Future<void> insertEvent(ReviewEventsTableCompanion companion) {
    final userId = companion.userId.value;
    return db.writeOutbound(userId, () async {
      final lists = db.vocabularyListDao;
      final variantId = await lists.resolveStarterId(
        StarterAliasKind.variant,
        userId,
        companion.variantId.value,
      );
      final listId = companion.listId.value;
      await into(reviewEventsTable).insert(
        companion.copyWith(
          variantId: Value(variantId),
          listId: listId == null
              ? companion.listId
              : Value(
                  await lists.resolveStarterId(
                    StarterAliasKind.list,
                    userId,
                    listId,
                  ),
                ),
        ),
      );
    });
  }

  Future<List<ReviewEventsTableData>> getUnsynced({String? userId}) =>
      (select(reviewEventsTable)..where(
            (t) =>
                t.isSynced.equals(false) &
                (userId == null
                    ? const Constant(true)
                    : t.userId.equals(userId)),
          ))
          .get();

  Future<int> acknowledge(ReviewEventsTableData row) =>
      acknowledgeSyncSnapshot(this, reviewEventsTable, row);

  Future<ReviewEventsTableData?> getById(String id) => (select(
    reviewEventsTable,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  /// All events for a user, newest first — the stats dashboard's raw feed.
  Future<List<ReviewEventsTableData>> getByUser(String userId) =>
      (select(reviewEventsTable)
            ..where((t) => t.userId.equals(userId))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();
}
