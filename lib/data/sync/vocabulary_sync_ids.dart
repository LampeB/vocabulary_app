import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../datasources/local/app_database.dart';
import '../datasources/remote/vocabulary_remote_datasource.dart';

enum SyncedVocabularyRow { list, concept, variant, progress }

/// PostgreSQL qualifies the wire UUID with an owner. SQLite can have several
/// signed-in accounts' cached rows in the same file, where IDs remain primary
/// keys by themselves. Keep a local UUID only when a wire ID already belongs
/// to a different account in this file.
class VocabularySyncIds {
  VocabularySyncIds._(this._db, this._owner, this._localByWire) {
    for (final entry in _localByWire.entries) {
      _wireByLocal[entry.key] = {
        for (final alias in entry.value.entries) alias.value: alias.key,
      };
    }
  }

  static const _uuid = Uuid();
  final AppDatabase _db;
  final String _owner;
  final Map<SyncedVocabularyRow, Map<String, String>> _localByWire;
  final _wireByLocal = <SyncedVocabularyRow, Map<String, String>>{};
  final _foreignIds = <SyncedVocabularyRow, Future<Set<String>>>{};

  static String _keyFor(String owner) => 'vocabulary-wire-ids:$owner';

  static Future<VocabularySyncIds> load(AppDatabase db, String owner) async {
    final table = db.sharedImportBootstrapTable;
    final stored = await (db.select(
      table,
    )..where((row) => row.id.equals(_keyFor(owner)))).getSingleOrNull();
    final decoded = stored == null
        ? const <String, dynamic>{}
        : jsonDecode(stored.snapshot) as Map<String, dynamic>;
    return VocabularySyncIds._(db, owner, {
      for (final kind in SyncedVocabularyRow.values)
        if (decoded[kind.name] case final Map<String, dynamic> values)
          kind: values.cast<String, String>(),
    });
  }

  String localId(SyncedVocabularyRow kind, String wireId) =>
      _localByWire[kind]?[wireId] ?? wireId;

  String wireId(SyncedVocabularyRow kind, String localId) =>
      _wireByLocal[kind]?[localId] ?? localId;

  /// Allocate in the transaction that inserts a row using this ID.
  Future<String> reserve(SyncedVocabularyRow kind, String wireId) =>
      _reserve(kind, wireId, () async {
        final foreign = await _foreignIds.putIfAbsent(
          kind,
          () => _ownedElsewhere(kind),
        );
        return foreign.contains(wireId);
      });

  /// One new review only needs the owner of its candidate primary key.
  Future<String> reserveProgress(String wireId) =>
      _reserve(SyncedVocabularyRow.progress, wireId, () async {
        final progress = _db.variantProgressTable;
        final row =
            await (_db.selectOnly(progress)
                  ..addColumns([progress.userId])
                  ..where(progress.id.equals(wireId)))
                .getSingleOrNull();
        return row != null && row.read(progress.userId) != _owner;
      });

  Future<String> _reserve(
    SyncedVocabularyRow kind,
    String wireId,
    Future<bool> Function() ownedElsewhere,
  ) async {
    final known = _localByWire[kind]?[wireId];
    if (known != null) return known;
    if (_wireByLocal[kind]?.containsKey(wireId) != true &&
        !await ownedElsewhere()) {
      return wireId;
    }
    final local = _uuid.v4();
    (_localByWire[kind] ??= {})[wireId] = local;
    (_wireByLocal[kind] ??= {})[local] = wireId;
    _dirty = true;
    return local;
  }

  bool _dirty = false;

  Future<void> save() async {
    if (!_dirty) return;
    await _db
        .into(_db.sharedImportBootstrapTable)
        .insertOnConflictUpdate(
          SharedImportBootstrapTableCompanion.insert(
            id: _keyFor(_owner),
            snapshot: jsonEncode({
              for (final entry in _localByWire.entries)
                entry.key.name: entry.value,
            }),
          ),
        );
    _dirty = false;
  }

  Future<Set<String>> _ownedElsewhere(SyncedVocabularyRow kind) async {
    if (kind == SyncedVocabularyRow.concept ||
        kind == SyncedVocabularyRow.variant) {
      final otherLists = await _foreignIds.putIfAbsent(
        SyncedVocabularyRow.list,
        () => _ownedElsewhere(SyncedVocabularyRow.list),
      );
      if (otherLists.isEmpty) return {};
    }
    final sql = switch (kind) {
      SyncedVocabularyRow.list =>
        'SELECT id FROM vocabulary_lists WHERE owner_id <> ?',
      SyncedVocabularyRow.concept =>
        'SELECT c.id FROM vocabulary_lists l CROSS JOIN concepts c ON c.list_id = l.id '
            'WHERE l.owner_id <> ?',
      SyncedVocabularyRow.variant =>
        'SELECT w.id FROM vocabulary_lists l CROSS JOIN concepts c ON c.list_id = l.id '
            'CROSS JOIN word_variants w ON w.concept_id = c.id WHERE l.owner_id <> ?',
      SyncedVocabularyRow.progress =>
        'SELECT id FROM variant_progress WHERE user_id <> ?',
    };
    final rows = await _db
        .customSelect(sql, variables: [Variable(_owner)])
        .get();
    return {for (final row in rows) row.read<String>('id')};
  }

  Map<String, dynamic> encode(
    SyncedVocabularyRow kind,
    Map<String, dynamic> row,
  ) => _mapRow(kind, row, wireId);

  Map<String, dynamic> decode(
    SyncedVocabularyRow kind,
    Map<String, dynamic> row,
  ) => _mapRow(kind, row, localId);

  Map<String, dynamic> _mapRow(
    SyncedVocabularyRow kind,
    Map<String, dynamic> row,
    String Function(SyncedVocabularyRow, String) transform,
  ) => {
    ...row,
    'id': transform(kind, row['id'] as String),
    if (kind == SyncedVocabularyRow.concept)
      'list_id': transform(SyncedVocabularyRow.list, row['list_id'] as String),
    if (kind == SyncedVocabularyRow.variant)
      'concept_id': transform(
        SyncedVocabularyRow.concept,
        row['concept_id'] as String,
      ),
    if (kind == SyncedVocabularyRow.progress)
      'variant_id': transform(
        SyncedVocabularyRow.variant,
        row['variant_id'] as String,
      ),
    if (row[VocabularyRemoteDataSource.deletedListKey]
        case final Map<String, dynamic> list)
      VocabularyRemoteDataSource.deletedListKey: _mapRow(
        SyncedVocabularyRow.list,
        list,
        transform,
      ),
    if (row[VocabularyRemoteDataSource.deletedConceptKey]
        case final Map<String, dynamic> concept)
      VocabularyRemoteDataSource.deletedConceptKey: _mapRow(
        SyncedVocabularyRow.concept,
        concept,
        transform,
      ),
  };
}
