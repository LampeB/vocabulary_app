import 'package:drift/drift.dart';

class VocabularyListsTable extends Table {
  @override
  String get tableName => 'vocabulary_lists';

  TextColumn get id => text()();
  TextColumn get ownerId => text().named('owner_id')();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get visibility => text().withDefault(const Constant('private'))();
  IntColumn get wordCount => integer().named('word_count').withDefault(const Constant(0))();
  TextColumn get shareToken => text().named('share_token').nullable()();
  // The list's studied language pair (generic-language-pairs epic). Existing
  // lists predate the columns, hence the fr/ko defaults.
  TextColumn get langA => text().named('lang_a').withDefault(const Constant('fr'))();
  TextColumn get langB => text().named('lang_b').withDefault(const Constant('ko'))();
  BoolColumn get isSynced => boolean().named('is_synced').withDefault(const Constant(false))();
  BoolColumn get isDeleted => boolean().named('is_deleted').withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  @override
  Set<Column> get primaryKey => {id};
}
