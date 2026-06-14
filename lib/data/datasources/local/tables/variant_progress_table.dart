import 'package:drift/drift.dart';
import 'word_variants_table.dart';

class VariantProgressTable extends Table {
  @override
  String get tableName => 'variant_progress';

  TextColumn get id => text()();
  TextColumn get userId => text().named('user_id')();
  TextColumn get variantId => text().named('variant_id').references(WordVariantsTable, #id)();
  TextColumn get direction => text()();
  RealColumn get stability => real().withDefault(const Constant(0.0))();
  RealColumn get difficulty => real().withDefault(const Constant(5.0))();
  IntColumn get elapsedDays => integer().named('elapsed_days').withDefault(const Constant(0))();
  IntColumn get scheduledDays => integer().named('scheduled_days').withDefault(const Constant(0))();
  IntColumn get reps => integer().withDefault(const Constant(0))();
  IntColumn get lapses => integer().withDefault(const Constant(0))();
  TextColumn get state => text().withDefault(const Constant('newCard'))();
  DateTimeColumn get lastReview => dateTime().named('last_review').nullable()();
  DateTimeColumn get nextReview => dateTime().named('next_review').nullable()();
  IntColumn get timesShown => integer().named('times_shown').withDefault(const Constant(0))();
  IntColumn get timesCorrect => integer().named('times_correct').withDefault(const Constant(0))();
  RealColumn get masteryLevel => real().named('mastery_level').withDefault(const Constant(0.0))();
  BoolColumn get isSynced => boolean().named('is_synced').withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  @override
  Set<Column> get primaryKey => {id};
}
