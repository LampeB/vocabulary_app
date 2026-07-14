import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/review_events_table.dart';

part 'review_event_dao.g.dart';

@DriftAccessor(tables: [ReviewEventsTable])
class ReviewEventDao extends DatabaseAccessor<AppDatabase>
    with _$ReviewEventDaoMixin {
  ReviewEventDao(super.db);

  Future<void> insertEvent(ReviewEventsTableCompanion companion) =>
      into(reviewEventsTable).insert(companion);

  Future<List<ReviewEventsTableData>> getUnsynced() =>
      (select(reviewEventsTable)..where((t) => t.isSynced.equals(false)))
          .get();

  Future<int> markSynced(List<String> ids) =>
      (update(reviewEventsTable)..where((t) => t.id.isIn(ids)))
          .write(const ReviewEventsTableCompanion(isSynced: Value(true)));

  /// All events for a user, newest first — the stats dashboard's raw feed.
  Future<List<ReviewEventsTableData>> getByUser(String userId) =>
      (select(reviewEventsTable)
            ..where((t) => t.userId.equals(userId))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();
}
