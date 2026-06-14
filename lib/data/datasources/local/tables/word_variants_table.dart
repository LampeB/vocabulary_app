import 'package:drift/drift.dart';
import 'concepts_table.dart';

class WordVariantsTable extends Table {
  @override
  String get tableName => 'word_variants';

  TextColumn get id => text()();
  TextColumn get conceptId => text().named('concept_id').references(ConceptsTable, #id)();
  TextColumn get word => text()();
  TextColumn get langCode => text().named('lang_code')();
  TextColumn get registerTag => text().named('register_tag').withDefault(const Constant('neutral'))();
  TextColumn get contextTags => text().named('context_tags').withDefault(const Constant('[]'))();
  BoolColumn get isPrimary => boolean().named('is_primary').withDefault(const Constant(false))();
  TextColumn get audioHash => text().named('audio_hash').nullable()();
  TextColumn get audioVoiceId => text().named('audio_voice_id').nullable()();
  IntColumn get position => integer().withDefault(const Constant(0))();
  BoolColumn get isSynced => boolean().named('is_synced').withDefault(const Constant(false))();
  BoolColumn get isDeleted => boolean().named('is_deleted').withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  @override
  Set<Column> get primaryKey => {id};
}
