import 'package:drift/drift.dart';

/// Compare every stored field, including nulls, rather than trusting SQLite's
/// second-precision timestamps. Acknowledging only flips a queue flag and
/// leaves display and learning projections asleep. Values are SQL parameters.
Future<int> acknowledgeSyncSnapshot(
  DatabaseConnectionUser database,
  TableInfo table,
  Insertable row,
) {
  final columns = row.toColumns(false);
  final matches = columns.keys.map((name) => '"$name" IS ?').join(' AND ');
  return database.customUpdate(
    'UPDATE "${table.actualTableName}" SET is_synced = 1 WHERE $matches',
    variables: columns.values.cast<Variable>().toList(),
  );
}
