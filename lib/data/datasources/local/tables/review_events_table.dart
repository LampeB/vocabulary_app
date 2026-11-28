import 'package:drift/drift.dart';

/// One row per graded answer — the observability log behind the stats
/// dashboard (Notion: review-event log). Strictly additive: never feeds FSRS
/// scheduling, which stays driven by variant_progress. Synced to Supabase
/// (isSynced flag is the outbound queue, like the other tables).
class ReviewEventsTable extends Table {
  @override
  String get tableName => 'review_events';

  TextColumn get id => text()();
  TextColumn get userId => text().named('user_id')();
  TextColumn get variantId => text().named('variant_id')();
  TextColumn get direction => text()(); // 'fr>ko' / 'ko>fr'
  TextColumn get listId => text().named('list_id').nullable()();
  TextColumn get mode => text()(); // flashcard / typing / voice / handsFree
  BoolColumn get correct => boolean()();
  TextColumn get rating => text()(); // FSRS rating: again/hard/good/easy
  IntColumn get responseTimeMs =>
      integer().named('response_time_ms').nullable()();
  IntColumn get retryCount => integer().named('retry_count').nullable()();
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  BoolColumn get isSynced =>
      boolean().named('is_synced').withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
