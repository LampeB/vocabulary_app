import 'package:drift/drift.dart';

/// SQLite timestamps use seconds in this schema. Comparing only updatedAt
/// can therefore acknowledge a different edit made in the same second.
/// Compare every stored field atomically, including nullable values via IS.
Expression<bool> matchesSyncSnapshot(TableInfo table, Insertable row) => row
    .toColumns(false)
    .entries
    .map((entry) => table.columnsByName[entry.key]!.isExp(entry.value))
    .reduce((left, right) => left & right);
