import 'package:drift/drift.dart';
import 'vocabulary_lists_table.dart';

class ConceptsTable extends Table {
  @override
  String get tableName => 'concepts';

  TextColumn get id => text()();
  TextColumn get listId => text().named('list_id').references(VocabularyListsTable, #id)();
  TextColumn get category => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get imageUrl => text().named('image_url').nullable()();
  TextColumn get exampleFr => text().named('example_fr').nullable()();
  TextColumn get exampleKo => text().named('example_ko').nullable()();
  // Registry concept id from the seed catalog (e.g. 'hello'). Null for
  // user-created concepts. Lets re-seeding top up missing concepts/variants
  // without touching rows that carry progress.
  TextColumn get seedId => text().named('seed_id').nullable()();
  BoolColumn get isSynced => boolean().named('is_synced').withDefault(const Constant(false))();
  BoolColumn get isDeleted => boolean().named('is_deleted').withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  @override
  Set<Column> get primaryKey => {id};
}
