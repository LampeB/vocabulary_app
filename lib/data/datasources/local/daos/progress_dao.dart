import 'dart:async';
import 'package:drift/drift.dart';
import '../app_database.dart';
import '../sync_snapshot.dart';
import '../tables/variant_progress_table.dart';
import '../tables/word_variants_table.dart';

part 'progress_dao.g.dart';

@DriftAccessor(tables: [VariantProgressTable, WordVariantsTable])
class ProgressDao extends DatabaseAccessor<AppDatabase>
    with _$ProgressDaoMixin {
  ProgressDao(super.db);

  /// Emits after any of [userId]'s FSRS rows changes. Consumers that derive
  /// aggregate vocabulary state (for example lesson prerequisites) need this
  /// invalidation signal even when a list's metadata itself did not change.
  Stream<void> watchChanges(String userId) => customSelect(
    "SELECT COALESCE(GROUP_CONCAT(id || ':' || variant_id || ':' || state || ':' || reps || ':' || scheduled_days || ':' || times_shown || ':' || times_correct), '') AS signature FROM (SELECT * FROM variant_progress WHERE user_id = ? ORDER BY id)",
    variables: [Variable<String>(userId)],
    readsFrom: {variantProgressTable},
  ).watchSingle().map((row) => row.read<String>('signature')).distinct().map((_) {});

  Stream<int> watchDueCount(String userId) {
    return _watchLiveDueCount(userId);
  }

  /// List IDs the user has STUDIED — i.e. has at least one progress row on any
  /// variant of any concept in the list (a card reviewed at least once). Powers
  /// the "currently studying" vs "not yet studied" split in quiz setup. One
  /// query across all lists instead of per-list stats.
  ///
  /// A WATCH, not a one-shot get: on a fresh device the login sync inserts the
  /// progress rows AFTER the quiz-setup screen first computes, and a future
  /// would stay empty until an app restart (field report 2026-07-19).
  Stream<Set<String>> watchStudiedListIds(String userId) {
    return customSelect(
      'SELECT DISTINCT c.list_id AS list_id '
      'FROM variant_progress vp '
      'JOIN word_variants wv ON wv.id = vp.variant_id '
      'JOIN concepts c ON c.id = wv.concept_id '
      'WHERE vp.user_id = ?',
      variables: [Variable<String>(userId)],
      readsFrom: {variantProgressTable, wordVariantsTable, db.conceptsTable},
    ).watch().map((rows) => rows.map((r) => r.read<String>('list_id')).toSet());
  }

  /// Due-card count for a single language pair (both directions), so the quiz
  /// setup's "to study now" badge reflects the CHOSEN language instead of every
  /// language's due cards (generic-language-pairs epic). A watch so the badge
  /// fills in live when the login sync lands on a fresh device.
  Stream<int> watchDueCountForPair(
    String userId,
    String langA,
    String langB, {
    Duration refreshEvery = const Duration(minutes: 1),
  }) {
    return _watchLiveDueCount(
      userId,
      langA: langA,
      langB: langB,
      refreshEvery: refreshEvery,
    );
  }

  Stream<int> _watchLiveDueCount(
    String userId, {
    String? langA,
    String? langB,
    Duration refreshEvery = const Duration(minutes: 1),
  }) {
    final query = customSelect(
      'SELECT COUNT(*) AS due FROM variant_progress p '
      'JOIN word_variants w ON w.id=p.variant_id '
      'JOIN concepts c ON c.id=w.concept_id '
      'JOIN vocabulary_lists l ON l.id=c.list_id '
      'WHERE p.user_id=? AND l.owner_id=? AND w.is_deleted=0 '
      'AND c.is_deleted=0 AND l.is_deleted=0 '
      "AND (p.next_review IS NULL OR p.next_review <= CAST(strftime('%s','now') AS INTEGER)) "
      '${langA == null ? '' : 'AND l.lang_a=? AND l.lang_b=? AND p.direction IN (?,?)'}',
      variables: [
        Variable<String>(userId),
        Variable<String>(userId),
        if (langA != null) ...[
          Variable<String>(langA),
          Variable<String>(langB!),
          Variable<String>('$langA>$langB'),
          Variable<String>('$langB>$langA'),
        ],
      ],
      readsFrom: {
        variantProgressTable,
        wordVariantsTable,
        db.conceptsTable,
        db.vocabularyListsTable,
      },
    );
    late StreamController<int> controller;
    StreamSubscription<QueryRow>? subscription;
    Timer? refresh;
    void emit(QueryRow row) {
      if (!controller.isClosed) controller.add(row.read<int>('due'));
    }

    controller = StreamController<int>(
      onListen: () {
        subscription = query.watchSingle().listen(
          emit,
          onError: controller.addError,
        );
        refresh = Timer.periodic(refreshEvery, (_) async {
          try {
            emit(await query.getSingle());
          } catch (error, stack) {
            if (!controller.isClosed) controller.addError(error, stack);
          }
        });
      },
      onCancel: () async {
        refresh?.cancel();
        await subscription?.cancel();
      },
    );
    return controller.stream.distinct();
  }

  Future<List<VariantProgressTableData>> getDue({
    required String userId,
    required String direction,
    required List<String> variantIds,
    int limit = 20,
  }) {
    final now = DateTime.now();
    return (select(variantProgressTable)
          ..where(
            (t) =>
                t.userId.equals(userId) &
                t.direction.equals(direction) &
                t.variantId.isIn(variantIds) &
                (t.nextReview.isNull() |
                    t.nextReview.isSmallerOrEqualValue(now)),
          )
          ..orderBy([
            (t) => OrderingTerm.asc(t.nextReview),
            (t) => OrderingTerm.asc(t.reps),
          ])
          ..limit(limit))
        .get();
  }

  /// Due rows for [userId]+[direction] across ALL lists (the "À réviser
  /// maintenant" smart list). "Due" = an existing progress row scheduled at or
  /// before now — never-studied words are not due. Soft-deleted variants are
  /// excluded via the join.
  Future<List<VariantProgressTableData>> getDueAcrossLists({
    required String userId,
    required String direction,
    String? langA,
    String? langB,
    int limit = 20,
  }) {
    final now = DateTime.now();
    final query =
        select(variantProgressTable).join([
            innerJoin(
              wordVariantsTable,
              wordVariantsTable.id.equalsExp(variantProgressTable.variantId),
            ),
            innerJoin(
              db.conceptsTable,
              db.conceptsTable.id.equalsExp(wordVariantsTable.conceptId),
            ),
            innerJoin(
              db.vocabularyListsTable,
              db.vocabularyListsTable.id.equalsExp(db.conceptsTable.listId),
            ),
          ])
          ..where(
            variantProgressTable.userId.equals(userId) &
                variantProgressTable.direction.equals(direction) &
                db.conceptsTable.isDeleted.equals(false) &
                db.vocabularyListsTable.isDeleted.equals(false) &
                db.vocabularyListsTable.ownerId.equals(userId) &
                (langA == null
                    ? const Constant(true)
                    : db.vocabularyListsTable.langA.equals(langA)) &
                (langB == null
                    ? const Constant(true)
                    : db.vocabularyListsTable.langB.equals(langB)) &
                wordVariantsTable.isDeleted.equals(false) &
                (variantProgressTable.nextReview.isNull() |
                    variantProgressTable.nextReview.isSmallerOrEqualValue(now)),
          )
          ..orderBy([
            OrderingTerm.asc(variantProgressTable.nextReview),
            OrderingTerm.asc(variantProgressTable.reps),
          ])
          ..limit(limit);
    return query.map((row) => row.readTable(variantProgressTable)).get();
  }

  /// Started rows (FSRS state ≠ newCard) for [userId]+[direction] across ALL
  /// lists (the "En cours d'apprentissage" smart list), due or not.
  Future<List<VariantProgressTableData>> getInProgressAcrossLists({
    required String userId,
    required String direction,
    String? langA,
    String? langB,
    int limit = 20,
  }) {
    final query =
        select(variantProgressTable).join([
            innerJoin(
              wordVariantsTable,
              wordVariantsTable.id.equalsExp(variantProgressTable.variantId),
            ),
            innerJoin(
              db.conceptsTable,
              db.conceptsTable.id.equalsExp(wordVariantsTable.conceptId),
            ),
            innerJoin(
              db.vocabularyListsTable,
              db.vocabularyListsTable.id.equalsExp(db.conceptsTable.listId),
            ),
          ])
          ..where(
            variantProgressTable.userId.equals(userId) &
                variantProgressTable.direction.equals(direction) &
                db.conceptsTable.isDeleted.equals(false) &
                db.vocabularyListsTable.isDeleted.equals(false) &
                db.vocabularyListsTable.ownerId.equals(userId) &
                (langA == null
                    ? const Constant(true)
                    : db.vocabularyListsTable.langA.equals(langA)) &
                (langB == null
                    ? const Constant(true)
                    : db.vocabularyListsTable.langB.equals(langB)) &
                wordVariantsTable.isDeleted.equals(false) &
                variantProgressTable.state.equals('newCard').not(),
          )
          ..orderBy([
            OrderingTerm.asc(variantProgressTable.nextReview),
            OrderingTerm.asc(variantProgressTable.reps),
          ])
          ..limit(limit);
    return query.map((row) => row.readTable(variantProgressTable)).get();
  }

  Future<VariantProgressTableData?> getByVariantAndDirection(
    String variantId,
    String direction, {
    String? userId,
  }) =>
      (select(variantProgressTable)..where(
            (t) =>
                t.variantId.equals(variantId) &
                t.direction.equals(direction) &
                (userId == null
                    ? const Constant(true)
                    : t.userId.equals(userId)),
          ))
          .getSingleOrNull();

  Future<int> upsert(VariantProgressTableCompanion companion) => transaction(
    () async {
      // Remote legacy UUIDs and deterministic new UUIDs identify the same card.
      // Reconcile by the business key before inserting its canonical snapshot.
      if (companion.userId.present &&
          companion.variantId.present &&
          companion.direction.present) {
        await (delete(variantProgressTable)..where(
              (t) =>
                  t.userId.equals(companion.userId.value) &
                  t.variantId.equals(companion.variantId.value) &
                  t.direction.equals(companion.direction.value) &
                  t.id.equals(companion.id.value).not(),
            ))
            .go();
      }
      return into(variantProgressTable).insertOnConflictUpdate(companion);
    },
  );

  Future<int> upsertLocal(VariantProgressTableCompanion companion) =>
      db.writeOutbound(companion.userId.value, () => upsert(companion));

  Future<Set<String>> getLiveVariantIds(String userId) async =>
      (await _liveVariantIds(userId).get()).toSet();

  Future<bool> isLiveVariant(String userId, String variantId) async =>
      (await _liveVariantIds(userId, variantId: variantId).getSingleOrNull()) !=
      null;

  Selectable<String> _liveVariantIds(String userId, {String? variantId}) {
    final variants = wordVariantsTable;
    final concepts = db.conceptsTable;
    final lists = db.vocabularyListsTable;
    final query = selectOnly(variants)..addColumns([variants.id]);
    final joined =
        query.join([
          innerJoin(
            concepts,
            concepts.id.equalsExp(variants.conceptId),
            useColumns: false,
          ),
          innerJoin(
            lists,
            lists.id.equalsExp(concepts.listId),
            useColumns: false,
          ),
        ])..where(
          lists.ownerId.equals(userId) &
              lists.isDeleted.equals(false) &
              concepts.isDeleted.equals(false) &
              variants.isDeleted.equals(false),
        );
    if (variantId != null) joined.where(variants.id.equals(variantId));
    return joined.map((row) => row.read(variants.id)!);
  }

  Future<void> applyPulledProgress(List<VariantProgressTableData> rows) async {
    if (rows.isEmpty) return;
    final progress = variantProgressTable;
    await batch((batch) {
      for (final row in rows) {
        batch.insert(
          progress,
          row,
          onConflict: DoUpdate(
            (_) => row,
            target: [progress.userId, progress.variantId, progress.direction],
          ),
        );
      }
    });
  }

  Future<VariantProgressTableData?> getById(String id) => (select(
    variantProgressTable,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<String>> getExistingVariantIds({
    required String userId,
    required String direction,
    required List<String> variantIds,
  }) {
    return (selectOnly(variantProgressTable)
          ..addColumns([variantProgressTable.variantId])
          ..where(
            variantProgressTable.userId.equals(userId) &
                variantProgressTable.direction.equals(direction) &
                variantProgressTable.variantId.isIn(variantIds),
          ))
        .map((row) => row.read(variantProgressTable.variantId)!)
        .get();
  }

  /// Returns ALL progress rows for the given variants (ignores nextReview date).
  /// Used as fallback when no cards are currently due — enables early review.
  Future<List<VariantProgressTableData>> getScheduledByVariants({
    required String userId,
    required String direction,
    required List<String> variantIds,
  }) {
    return (select(variantProgressTable)
          ..where(
            (t) =>
                t.userId.equals(userId) &
                t.direction.equals(direction) &
                t.variantId.isIn(variantIds),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.nextReview)]))
        .get();
  }

  /// Progress rows (paired with their concept id) for every live variant of
  /// the given concepts — the raw material for per-list stats. Aggregation
  /// happens in the repository (lists are small; no SQL group-by needed).
  Future<List<({String conceptId, VariantProgressTableData progress})>>
  getProgressForConcepts({
    required String userId,
    required List<String> conceptIds,
  }) {
    final query =
        select(variantProgressTable).join([
          innerJoin(
            wordVariantsTable,
            wordVariantsTable.id.equalsExp(variantProgressTable.variantId),
          ),
        ])..where(
          variantProgressTable.userId.equals(userId) &
              wordVariantsTable.isDeleted.equals(false) &
              wordVariantsTable.conceptId.isIn(conceptIds),
        );
    return query
        .map(
          (row) => (
            conceptId: row.readTable(wordVariantsTable).conceptId,
            progress: row.readTable(variantProgressTable),
          ),
        )
        .get();
  }

  /// All live variant ids belonging to the given concepts (any language).
  Future<List<String>> getVariantIdsForConcepts(List<String> conceptIds) =>
      (selectOnly(wordVariantsTable)
            ..addColumns([wordVariantsTable.id])
            ..where(
              wordVariantsTable.conceptId.isIn(conceptIds) &
                  wordVariantsTable.isDeleted.equals(false),
            ))
          .map((row) => row.read(wordVariantsTable.id)!)
          .get();

  /// Deletes this user's progress for the given variants — the "reset list
  /// progress" action. Rows are deleted (not zeroed) so the words become
  /// genuinely NEW cards again for the due/new quiz logic.
  Future<int> deleteProgressForVariants({
    required String userId,
    required List<String> variantIds,
  }) => (delete(
    variantProgressTable,
  )..where((t) => t.userId.equals(userId) & t.variantId.isIn(variantIds))).go();

  Future<List<VariantProgressTableData>> getUnsyncedProgress({
    String? userId,
  }) =>
      (select(variantProgressTable)..where(
            (t) =>
                t.isSynced.equals(false) &
                (userId == null
                    ? const Constant(true)
                    : t.userId.equals(userId)),
          ))
          .get();

  /// Returns all rows the user has mastered: FSRS review state with
  /// scheduledDays ≥ [minScheduledDays]. Ordered by scheduledDays descending
  /// so the most confidently-known words come first.
  Future<List<VariantProgressTableData>> getMasteredProgress({
    required String userId,
    int minScheduledDays = 21,
  }) =>
      (select(variantProgressTable)
            ..where(
              (t) =>
                  t.userId.equals(userId) &
                  t.state.equals('review') &
                  t.scheduledDays.isBiggerOrEqualValue(minScheduledDays),
            )
            ..orderBy([(t) => OrderingTerm.desc(t.scheduledDays)]))
          .get();

  /// Rows whose FSRS card graduated from the learning phase (review or
  /// relearning — a lapsed word was still learned once). The "known" bar
  /// that gates grammar; lighter than [getMasteredProgress].
  Future<List<VariantProgressTableData>> getGraduatedProgress({
    required String userId,
  }) =>
      (select(variantProgressTable)
            ..where(
              (t) =>
                  t.userId.equals(userId) &
                  t.state.isIn(['review', 'relearning']),
            )
            ..orderBy([(t) => OrderingTerm.desc(t.scheduledDays)]))
          .get();

  Future<int> markProgressSynced(List<String> ids) =>
      (update(variantProgressTable)..where((t) => t.id.isIn(ids))).write(
        const VariantProgressTableCompanion(isSynced: Value(true)),
      );

  Future<int> acknowledge(VariantProgressTableData row) =>
      acknowledgeSyncSnapshot(this, variantProgressTable, row);
}
