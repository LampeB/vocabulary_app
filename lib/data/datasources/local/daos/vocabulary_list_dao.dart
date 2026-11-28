import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:drift/drift.dart';
import '../../../sync/vocabulary_sync_ids.dart';
import '../app_database.dart';
import '../sync_snapshot.dart';
import '../tables/vocabulary_lists_table.dart';
import '../tables/concepts_table.dart';
import '../tables/word_variants_table.dart';

part 'vocabulary_list_dao.g.dart';

enum StarterAliasKind { list, concept, variant }

@DriftAccessor(tables: [VocabularyListsTable, ConceptsTable, WordVariantsTable])
class VocabularyListDao extends DatabaseAccessor<AppDatabase>
    with _$VocabularyListDaoMixin {
  VocabularyListDao(super.db);

  Stream<List<VocabularyListsTableData>> watchByOwner(String ownerId) =>
      (select(vocabularyListsTable)
            ..where(
              (t) => t.ownerId.equals(ownerId) & t.isDeleted.equals(false),
            )
            ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
          .watch();

  Future<VocabularyListsTableData?> getById(String id) => (select(
    vocabularyListsTable,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Stream<VocabularyListsTableData?> watchById(String id, {String? ownerId}) {
    final query = select(vocabularyListsTable);
    if (ownerId == null) {
      query.where((t) => t.id.equals(id));
    } else {
      query.where(
        (t) =>
            t.ownerId.equals(ownerId) &
            t.id.equalsExp(
              starterIdExpression(StarterAliasKind.list, ownerId, id),
            ),
      );
    }
    return query.watchSingleOrNull();
  }

  Future<VocabularyListsTableData?> getByShareToken(
    String token, {
    String? ownerId,
  }) =>
      (select(vocabularyListsTable)..where(
            (t) =>
                t.shareToken.equals(token) &
                (ownerId == null
                    ? const Constant(true)
                    : t.ownerId.equals(ownerId)) &
                t.isDeleted.equals(false),
          ))
          .getSingleOrNull();

  Future<int> upsert(VocabularyListsTableCompanion companion) =>
      into(vocabularyListsTable).insertOnConflictUpdate(companion);

  Future<VocabularyListsTableData?> getImportedCopy(
    String token,
    String ownerId,
  ) =>
      (select(vocabularyListsTable)
            ..where(
              (t) =>
                  t.ownerId.equals(ownerId) &
                  t.importedFromShareToken.equals(token) &
                  t.isDeleted.equals(false),
            )
            ..orderBy([
              (t) => OrderingTerm.asc(t.createdAt),
              (t) => OrderingTerm.asc(t.id),
            ])
            ..limit(1))
          .getSingleOrNull();

  Future<List<String>> getPendingListIds({String? ownerId}) => customSelect(
    'SELECT l.id FROM vocabulary_lists l '
    'WHERE (? IS NULL OR l.owner_id = ?) AND (l.is_synced = 0 '
    'OR EXISTS(SELECT 1 FROM shared_import_bootstrap b WHERE b.id = \'$_legacySharePrefix\' || l.id) '
    'OR EXISTS(SELECT 1 FROM concepts c WHERE c.list_id = l.id AND c.is_synced = 0) '
    'OR EXISTS(SELECT 1 FROM concepts c JOIN word_variants w ON w.concept_id = c.id '
    'WHERE c.list_id = l.id AND w.is_synced = 0))',
    variables: [Variable<String>(ownerId), Variable<String>(ownerId)],
  ).map((row) => row.read<String>('id')).get();

  /// The common base for a shared import until all of its edits are acknowledged.
  Future<void> rememberSharedImport(String id, DataClass row) =>
      into(db.sharedImportBootstrapTable).insertOnConflictUpdate(
        SharedImportBootstrapTableCompanion.insert(
          id: id,
          snapshot: jsonEncode(row.toJson()),
        ),
      );

  Future<Map<String, dynamic>?> getSharedImportBase(String id) async {
    final initial = await (select(
      db.sharedImportBootstrapTable,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return initial == null
        ? null
        : jsonDecode(initial.snapshot) as Map<String, dynamic>;
  }

  Future<void> forgetSharedImportBases(Iterable<String> ids) => (delete(
    db.sharedImportBootstrapTable,
  )..where((t) => t.id.isIn(ids))).go();

  static const _legacySharePrefix = 'legacy-share:';
  static const _legacyMetadataPrefix = 'legacy-share-metadata:';

  // Every legacy producer used UUIDv4. Modern import generations use UUIDv5
  // on the wire, including when the SQLite UUID is a cross-account alias.
  static final _version5 = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  static bool isLegacyShareWireId(String id) => !_version5.hasMatch(id);

  Future<void> quarantineLegacyShares({required bool previouslyRewritten}) =>
      transaction(() async {
        final rows =
            await (select(vocabularyListsTable)..where(
                  (row) => previouslyRewritten
                      ? row.importedFromShareToken.isNotNull()
                      : row.visibility.equals('private') &
                            row.shareToken.isNotNull(),
                ))
                .get();
        final idsByOwner = <String, Future<VocabularySyncIds>>{};
        for (final row in rows) {
          if (previouslyRewritten) {
            final ids = await idsByOwner.putIfAbsent(
              row.ownerId,
              () => VocabularySyncIds.load(db, row.ownerId),
            );
            if (!isLegacyShareWireId(
              ids.wireId(SyncedVocabularyRow.list, row.id),
            )) {
              continue;
            }
          }
          final token = previouslyRewritten
              ? row.importedFromShareToken!
              : row.shareToken!;
          await rememberLegacyShare(row.id, (
            token: token,
            edited:
                previouslyRewritten &&
                (row.visibility != 'private' || row.shareToken != null),
          ));
          final normalized = previouslyRewritten
              ? row.copyWith(importedFromShareToken: const Value(null))
              : row.copyWith(shareToken: const Value(null));
          await upsert(normalized.toCompanion(false));
          if (row.isDeleted &&
              !row.isSynced &&
              await getSharedImportBase(row.id) == null) {
            await rememberSharedImport(
              row.id,
              normalized.copyWith(isDeleted: false),
            );
          }
        }
      });

  Future<LegacyShare?> getLegacyShare(String listId) async {
    final row =
        await (select(db.sharedImportBootstrapTable)
              ..where((t) => t.id.equals('$_legacySharePrefix$listId')))
            .getSingleOrNull();
    return row == null ? null : _decodeLegacyShare(row.snapshot);
  }

  LegacyShare _decodeLegacyShare(String snapshot) {
    final data = jsonDecode(snapshot) as Map<String, dynamic>;
    return (token: data['token'] as String, edited: data['edited'] as bool);
  }

  Future<void> rememberLegacyShare(String listId, LegacyShare share) =>
      into(db.sharedImportBootstrapTable).insertOnConflictUpdate(
        SharedImportBootstrapTableCompanion.insert(
          id: '$_legacySharePrefix$listId',
          snapshot: jsonEncode({'token': share.token, 'edited': share.edited}),
        ),
      );

  Future<void> forgetLegacyShare(String listId) =>
      forgetSharedImportBases(['$_legacySharePrefix$listId']);

  /// The first edit uses the local pre-edit row, even when its old differences
  /// were never acknowledged. The hold distinguishes those unverified fields
  /// from changes made after this base was captured.
  Future<VocabularyListsTableData?> captureLegacyListBase(
    VocabularyListsTableData row, {
    String? wireId,
  }) async {
    final bootstrap = db.sharedImportBootstrapTable;
    final holdId = '$_legacyMetadataPrefix${row.id}';
    final tokenId = '$_legacySharePrefix${row.id}';
    final snapshots = {
      for (final stored in await (select(
        bootstrap,
      )..where((t) => t.id.isIn([row.id, holdId, tokenId]))).get())
        stored.id: stored.snapshot,
    };
    final tracked = snapshots.containsKey(holdId);
    final token = snapshots[tokenId];
    final pending = token == null ? null : _decodeLegacyShare(token);
    final storedBase = snapshots[row.id];
    if (!tracked && pending == null) {
      if (storedBase == null || !isLegacyShareWireId(wireId ?? row.id)) {
        return null;
      }
      wireId ??= (await VocabularySyncIds.load(
        db,
        row.ownerId,
      )).wireId(SyncedVocabularyRow.list, row.id);
      if (!isLegacyShareWireId(wireId)) return null;
    }
    final base = storedBase == null
        ? null
        : VocabularyListsTableData.fromJson(
            jsonDecode(storedBase) as Map<String, dynamic>,
          );

    // An older v13 reconciliation stored the server row as an apparent edit
    // base, even when there was no local edit history to justify that delta.
    final inferredBase =
        !tracked &&
        base != null &&
        (pending == null || base.importedFromShareToken == pending.token);
    if (!tracked) {
      final unknownHistory = inferredBase || !(base ?? row).isSynced;
      await _rememberHeldLegacyMetadata(row.id, {
        if (unknownHistory) ...{
          'name',
          'description',
          'word_count',
          'lang_a',
          'lang_b',
          'origin',
          'seed_id',
          if (pending?.edited != false) ...{'visibility', 'share_token'},
        },
      });
    }
    if (base != null && !inferredBase) return base;
    final captured = row.copyWith(
      isDeleted: false,
      // A resolved v13 row already had separate evidence for provenance.
      importedFromShareToken: pending == null && inferredBase
          ? Value(base.importedFromShareToken)
          : const Value.absent(),
    );
    await rememberSharedImport(row.id, captured);
    return captured;
  }

  Future<Set<String>?> _heldLegacyMetadata(String listId) async {
    final row =
        await (select(db.sharedImportBootstrapTable)
              ..where((t) => t.id.equals('$_legacyMetadataPrefix$listId')))
            .getSingleOrNull();
    if (row == null) return null;
    return (jsonDecode(row.snapshot) as List).cast<String>().toSet();
  }

  Future<void> _rememberHeldLegacyMetadata(String listId, Set<String> fields) =>
      into(db.sharedImportBootstrapTable).insertOnConflictUpdate(
        SharedImportBootstrapTableCompanion.insert(
          id: '$_legacyMetadataPrefix$listId',
          snapshot: jsonEncode(fields.toList()),
        ),
      );

  Future<void> forgetLegacyMetadata(String listId) =>
      forgetSharedImportBases(['$_legacyMetadataPrefix$listId']);

  /// Keep unresolved local values visible through pull and acknowledgement.
  /// Confirmed edits leave the hold only when they are explicitly applied.
  Future<Map<String, dynamic>> retainLegacyMetadata(
    String listId,
    Map<String, dynamic> canonical,
    Map<String, dynamic> local, {
    Iterable<String> edited = const [],
    bool canonicalExists = true,
  }) async {
    final held = await _heldLegacyMetadata(listId);
    if (held == null || held.isEmpty) return canonical;
    final keep = held.difference(edited.toSet());
    if (canonicalExists) {
      keep.removeWhere((key) => local[key] == canonical[key]);
    }
    if (keep.length != held.length) {
      await _rememberHeldLegacyMetadata(listId, keep);
    }
    return {...canonical, for (final key in keep) key: local[key]};
  }

  Future<List<({VocabularyListsTableData list, LegacyShare pending})>>
  legacyShareLists({String? ownerId, String? token}) {
    final lists = vocabularyListsTable;
    final bootstrap = db.sharedImportBootstrapTable;
    final query = select(lists).join([
      innerJoin(
        bootstrap,
        bootstrap.id.equalsExp(const Constant(_legacySharePrefix) + lists.id),
      ),
    ]);
    if (ownerId != null) query.where(lists.ownerId.equals(ownerId));
    return query
        .map(
          (row) => (
            list: row.readTable(lists),
            pending: _decodeLegacyShare(row.readTable(bootstrap).snapshot),
          ),
        )
        .get()
        .then(
          (rows) => token == null
              ? rows
              : rows.where((row) => row.pending.token == token).toList(),
        );
  }

  static const _starterDraftPrefix = 'starter-draft:';
  static const _starterEstablishedPrefix = 'starter-established:';
  static const _starterContentsPendingPrefix = 'starter-contents-pending:';

  String _starterAliasKey(StarterAliasKind kind, String ownerId, String id) =>
      'starter-alias:${kind.name}:$ownerId:$id';

  /// Used in watched queries so the alias and its target are read together.
  Expression<String> starterIdExpression(
    StarterAliasKind kind,
    String ownerId,
    String id,
  ) {
    final table = db.sharedImportBootstrapTable;
    final alias = selectOnly(table)
      ..addColumns([table.snapshot])
      ..where(table.id.equals(_starterAliasKey(kind, ownerId, id)));
    return ifNull(subqueryExpression<String>(alias), Variable(id));
  }

  Future<void> rememberStarterAlias(
    StarterAliasKind kind,
    String ownerId,
    String oldId,
    String canonicalId,
  ) => into(db.sharedImportBootstrapTable).insertOnConflictUpdate(
    SharedImportBootstrapTableCompanion.insert(
      id: _starterAliasKey(kind, ownerId, oldId),
      snapshot: canonicalId,
    ),
  );

  Future<String> resolveStarterId(
    StarterAliasKind kind,
    String ownerId,
    String id,
  ) async {
    final alias =
        await (select(db.sharedImportBootstrapTable)
              ..where((t) => t.id.equals(_starterAliasKey(kind, ownerId, id))))
            .getSingleOrNull();
    return alias?.snapshot ?? id;
  }

  Future<void> holdStarterDraft(String listId) =>
      into(db.sharedImportBootstrapTable).insert(
        SharedImportBootstrapTableCompanion.insert(
          id: '$_starterDraftPrefix$listId',
          snapshot: '{}',
        ),
        mode: InsertMode.insertOrIgnore,
      );

  Future<void> releaseStarterDraft(String listId) =>
      forgetSharedImportBases(['$_starterDraftPrefix$listId']);

  Future<bool> isStarterDraftHeld(String listId) async =>
      (await (select(db.sharedImportBootstrapTable)
            ..where((t) => t.id.equals('$_starterDraftPrefix$listId')))
          .getSingleOrNull()) !=
      null;

  Future<bool> isStarterEstablished(String listId) async =>
      (await (select(db.sharedImportBootstrapTable)
            ..where((t) => t.id.equals('$_starterEstablishedPrefix$listId')))
          .getSingleOrNull()) !=
      null;

  Future<void> establishStarterIdentity(String listId) async {
    if (await isStarterEstablished(listId)) return;
    await into(db.sharedImportBootstrapTable).insert(
      SharedImportBootstrapTableCompanion.insert(
        id: '$_starterEstablishedPrefix$listId',
        snapshot: '{}',
      ),
      mode: InsertMode.insertOrIgnore,
    );
    await releaseStarterDraft(listId);
  }

  Future<bool> isStarterContentsPending(String listId) async =>
      (await (select(
            db.sharedImportBootstrapTable,
          )..where((t) => t.id.equals('$_starterContentsPendingPrefix$listId')))
          .getSingleOrNull()) !=
      null;

  Future<void> setStarterContentsPending(String listId, bool pending) async {
    final id = '$_starterContentsPendingPrefix$listId';
    if (pending) {
      await into(db.sharedImportBootstrapTable).insert(
        SharedImportBootstrapTableCompanion.insert(id: id, snapshot: '{}'),
        mode: InsertMode.insertOrIgnore,
      );
    } else {
      await forgetSharedImportBases([id]);
    }
  }

  Future<List<VocabularyListsTableData>> heldStarterDrafts({String? ownerId}) {
    final bootstrap = db.sharedImportBootstrapTable;
    final lists = vocabularyListsTable;
    final query = select(lists).join([
      innerJoin(
        bootstrap,
        bootstrap.id.equalsExp(const Constant(_starterDraftPrefix) + lists.id),
      ),
    ])..where(lists.origin.equals('starter') & lists.seedId.isNotNull());
    if (ownerId != null) query.where(lists.ownerId.equals(ownerId));
    return query.map((row) => row.readTable(lists)).get();
  }

  Future<List<VocabularyListsTableData>> getStarterLists(String ownerId) =>
      (select(vocabularyListsTable)
            ..where(
              (t) =>
                  t.ownerId.equals(ownerId) &
                  t.origin.equals('starter') &
                  t.seedId.isNotNull(),
            )
            ..orderBy([
              (t) => OrderingTerm.asc(t.isDeleted),
              (t) => OrderingTerm.asc(t.createdAt),
              (t) => OrderingTerm.asc(t.id),
            ]))
          .get();

  Future<int> softDelete(String id) =>
      (update(vocabularyListsTable)..where((t) => t.id.equals(id))).write(
        VocabularyListsTableCompanion(
          isDeleted: const Value(true),
          isSynced: const Value(false),
          updatedAt: Value(DateTime.now()),
        ),
      );

  Future<List<VocabularyListsTableData>> getUnsyncedLists({String? ownerId}) =>
      (select(vocabularyListsTable)..where(
            (t) =>
                t.isSynced.equals(false) &
                (ownerId == null
                    ? const Constant(true)
                    : t.ownerId.equals(ownerId)),
          ))
          .get();

  Future<int> updateWordCount(String listId, int newCount) =>
      transaction(() async {
        final row = await getById(listId);
        if (row == null) return 0;
        await captureLegacyListBase(row);
        return (update(
          vocabularyListsTable,
        )..where((t) => t.id.equals(listId))).write(
          VocabularyListsTableCompanion(
            wordCount: Value(newCount),
            updatedAt: Value(DateTime.now()),
            isSynced: const Value(false),
          ),
        );
      });

  Future<int> setShareToken(
    String listId,
    String token, {
    bool publish = false,
  }) => (update(vocabularyListsTable)..where((t) => t.id.equals(listId))).write(
    VocabularyListsTableCompanion(
      shareToken: Value(token),
      visibility: publish ? const Value('public') : const Value.absent(),
      isSynced: const Value(false),
      updatedAt: Value(DateTime.now()),
    ),
  );

  /// Sharing requires the complete list payload, not merely an acknowledged
  /// token. Unrelated pending rows from other lists must not block sharing.
  Future<bool> hasPendingContents(String listId) async {
    final row = await customSelect(
      'SELECT EXISTS(SELECT 1 FROM concepts WHERE list_id = ? AND is_synced = 0) '
      'OR EXISTS(SELECT 1 FROM word_variants w JOIN concepts c ON c.id = w.concept_id '
      'WHERE c.list_id = ? AND w.is_synced = 0) AS pending',
      variables: [Variable<String>(listId), Variable<String>(listId)],
    ).getSingle();
    return row.read<int>('pending') != 0;
  }

  /// Refresh a derived count after pull without manufacturing a local edit.
  Future<int> refreshWordCount(String listId, int count) =>
      transaction(() async {
        final row = await getById(listId);
        if (row == null || row.wordCount == count) return 0;
        if (!row.isSynced) {
          final base = await captureLegacyListBase(row);
          if (base != null && base.wordCount == row.wordCount) {
            await rememberSharedImport(listId, base.copyWith(wordCount: count));
          }
        }
        return (update(vocabularyListsTable)..where((t) => t.id.equals(listId)))
            .write(VocabularyListsTableCompanion(wordCount: Value(count)));
      });

  /// Retro-tags a pre-catalog starter list with its stable seed identity
  /// (legacy adoption — see StarterSeeder).
  Future<int> stampSeedIdentity(
    String listId,
    String seedId,
    String langA,
    String langB,
  ) => transaction(() async {
    final row = await getById(listId);
    if (row == null) return 0;
    await captureLegacyListBase(row);
    return (update(
      vocabularyListsTable,
    )..where((t) => t.id.equals(listId))).write(
      VocabularyListsTableCompanion(
        seedId: Value(seedId),
        langA: Value(langA),
        langB: Value(langB),
        isSynced: const Value(false),
        updatedAt: Value(DateTime.now()),
      ),
    );
  });

  Future<int> markListsSynced(List<String> ids) =>
      (update(vocabularyListsTable)..where((t) => t.id.isIn(ids))).write(
        const VocabularyListsTableCompanion(isSynced: Value(true)),
      );

  Future<int> acknowledge(VocabularyListsTableData row) =>
      acknowledgeSyncSnapshot(this, vocabularyListsTable, row);
}

typedef LegacyShare = ({String token, bool edited});
