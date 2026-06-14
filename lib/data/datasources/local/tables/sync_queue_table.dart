import 'package:drift/drift.dart';

class SyncQueueTable extends Table {
  @override
  String get tableName => 'sync_queue';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get tableName_ => text().named('table_name')();
  TextColumn get rowId => text().named('row_id')();
  TextColumn get operation => text()(); // 'insert' | 'update' | 'delete'
  TextColumn get payload => text()();   // JSON
  IntColumn get retryCount => integer().named('retry_count').withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().named('created_at')();
}
