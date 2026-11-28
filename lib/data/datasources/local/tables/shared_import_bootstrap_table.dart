import 'package:drift/drift.dart';

/// Original row content for a shared import waiting for its first upload.
class SharedImportBootstrapTable extends Table {
  @override
  String get tableName => 'shared_import_bootstrap';

  TextColumn get id => text()();
  TextColumn get snapshot => text()();

  @override
  Set<Column> get primaryKey => {id};
}
