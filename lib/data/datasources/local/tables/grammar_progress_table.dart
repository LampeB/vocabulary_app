import 'package:drift/drift.dart';

/// Per-rule grammar mastery. Language-agnostic by design: rows key on the
/// rule id (rules are per-language content), so new languages add rows, not
/// columns. Only mastery-counting answers land here — cartes never writes
/// (product decision 2026-07-04).
class GrammarProgressTable extends Table {
  @override
  String get tableName => 'grammar_progress';

  TextColumn get id => text()(); // '<userId>|<ruleId>'
  TextColumn get userId => text().named('user_id')();
  TextColumn get ruleId => text().named('rule_id')();
  IntColumn get shown => integer().withDefault(const Constant(0))();
  IntColumn get correct => integer().withDefault(const Constant(0))();
  DateTimeColumn get masteredAt => dateTime().named('mastered_at').nullable()();
  BoolColumn get isSynced =>
      boolean().named('is_synced').withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  @override
  Set<Column> get primaryKey => {id};
}
