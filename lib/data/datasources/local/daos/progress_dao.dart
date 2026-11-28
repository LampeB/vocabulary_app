import 'dart:async';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show listEquals;
import '../../../../domain/entities/variant_progress.dart';
import '../app_database.dart';
import '../sync_snapshot.dart';
import '../tables/variant_progress_table.dart';
import '../tables/word_variants_table.dart';
import 'vocabulary_list_dao.dart';

part 'progress_dao.g.dart';

enum SmartQuizPool { due, inProgress }

typedef GrammarDrillRow = ({
  String word,
  String contextTags,
  String category,
  String listId,
});
typedef GrammarPrerequisiteRow = ({
  String listId,
  String token,
  String name,
  int known,
  int total,
});

@DriftAccessor(tables: [VariantProgressTable, WordVariantsTable])
class ProgressDao extends DatabaseAccessor<AppDatabase>
    with _$ProgressDaoMixin {
  ProgressDao(super.db);

  Set<ResultSetImplementation> get _grammarTables => {
    variantProgressTable,
    wordVariantsTable,
    db.conceptsTable,
    db.vocabularyListsTable,
  };

  /// One target word per graduated concept, ordered by FSRS confidence.
  /// Any active variant can establish that the concept was learned.
  /// Resolve alternate forms in their existing storage order.
  Stream<List<GrammarDrillRow>> watchGrammarDrillWords(
    String userId,
    String targetLang,
  ) =>
      customSelect(
            '''
    SELECT target.word, target.context_tags, c.category, c.list_id
    FROM variant_progress p
    JOIN word_variants source ON source.id = p.variant_id
    JOIN concepts c ON c.id = source.concept_id
    JOIN vocabulary_lists l ON l.id = c.list_id
    JOIN word_variants target ON target.id = (
      SELECT w.id FROM word_variants w
      WHERE w.concept_id = c.id AND w.lang_code = ? AND w.is_deleted = 0
      ORDER BY w.rowid LIMIT 1
    )
    WHERE p.user_id = ? AND p.state IN ('review', 'relearning')
      AND l.owner_id = p.user_id AND l.is_deleted = 0 AND c.is_deleted = 0
      AND source.is_deleted = 0
      AND c.category IS NOT NULL
    GROUP BY c.id
    ORDER BY MAX(p.scheduled_days) DESC, c.id
    ''',
            variables: [Variable(targetLang), Variable(userId)],
            readsFrom: _grammarTables,
          )
          .map(
            (row) => (
              word: row.read<String>('word'),
              contextTags: row.read<String>('context_tags'),
              category: row.read<String>('category'),
              listId: row.read<String>('list_id'),
            ),
          )
          .watch()
          .distinct(listEquals);

  /// Counts each live concept once, for the account's exact catalog copies.
  /// Content changes can change the denominator even before a card is reviewed.
  Stream<List<GrammarPrerequisiteRow>> watchGrammarPrerequisites({
    required String userId,
    required String targetLang,
    required Set<String> tokens,
  }) {
    if (tokens.isEmpty) return Stream.value(const []);
    final tokenValues = tokens.map((_) => '(?)').join(', ');
    return customSelect(
          '''
      WITH tokens(value) AS (VALUES $tokenValues)
      SELECT l.id, tokens.value AS token, l.name, COUNT(c.id) AS total,
        COUNT(CASE WHEN EXISTS (
          SELECT 1 FROM word_variants w
          WHERE w.concept_id = c.id AND w.is_deleted = 0
            AND EXISTS (
              SELECT 1 FROM variant_progress p
              WHERE p.user_id = l.owner_id AND p.variant_id = w.id
                AND p.state IN ('review', 'relearning')
            )
        ) THEN 1 END) AS known
      FROM vocabulary_lists l
      JOIN tokens ON l.seed_id = tokens.value || ':' || l.lang_a || '>' || l.lang_b
      LEFT JOIN concepts c ON c.list_id = l.id AND c.is_deleted = 0
      WHERE l.owner_id = ? AND l.lang_b = ? AND l.is_deleted = 0
      GROUP BY l.id
      ORDER BY l.updated_at DESC, l.rowid
      ''',
          variables: [
            ...tokens.map(Variable<String>.new),
            Variable(userId),
            Variable(targetLang),
          ],
          readsFrom: _grammarTables,
        )
        .map(
          (row) => (
            listId: row.read<String>('id'),
            token: row.read<String>('token'),
            name: row.read<String>('name'),
            known: row.read<int>('known'),
            total: row.read<int>('total'),
          ),
        )
        .watch()
        .distinct(listEquals);
  }

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
    final forward = QuizDirection(questionLang: langA, answerLang: langB);
    return watchSmartQuizCardCount(
      userId: userId,
      directions: [forward, forward.reversed],
      pool: SmartQuizPool.due,
      langA: langA,
      langB: langB,
      refreshEvery: refreshEvery,
    );
  }

  Stream<int> _watchLiveDueCount(
    String userId, {
    Duration refreshEvery = const Duration(minutes: 1),
  }) {
    final query = customSelect(
      'SELECT COUNT(*) AS due FROM variant_progress p '
      'JOIN word_variants w ON w.id=p.variant_id '
      'JOIN concepts c ON c.id=w.concept_id '
      'JOIN vocabulary_lists l ON l.id=c.list_id '
      'WHERE p.user_id=? AND l.owner_id=? AND w.is_deleted=0 '
      'AND c.is_deleted=0 AND l.is_deleted=0 '
      "AND (p.next_review IS NULL OR p.next_review <= CAST(strftime('%s','now') AS INTEGER))",
      variables: [Variable<String>(userId), Variable<String>(userId)],
      readsFrom: {
        variantProgressTable,
        wordVariantsTable,
        db.conceptsTable,
        db.vocabularyListsTable,
      },
    );
    return _watchCount(
      query.map((row) => row.read<int>('due')),
      refreshEvery: refreshEvery,
    );
  }

  Stream<int> _watchCount(Selectable<int> query, {Duration? refreshEvery}) {
    if (refreshEvery == null) return query.watchSingle().distinct();
    late StreamController<int> controller;
    StreamSubscription<int>? subscription;
    Timer? refresh;
    void emit(int count) {
      if (!controller.isClosed) controller.add(count);
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

  Future<List<VariantProgressTableData>> getDueAcrossLists({
    required String userId,
    required QuizDirection direction,
    String? langA,
    String? langB,
    int limit = 20,
  }) => _loadSmartCards(
    userId: userId,
    direction: direction,
    pool: SmartQuizPool.due,
    langA: langA,
    langB: langB,
    limit: limit,
  );

  Future<List<VariantProgressTableData>> getInProgressAcrossLists({
    required String userId,
    required QuizDirection direction,
    String? langA,
    String? langB,
    int limit = 20,
  }) => _loadSmartCards(
    userId: userId,
    direction: direction,
    pool: SmartQuizPool.inProgress,
    langA: langA,
    langB: langB,
    limit: limit,
  );

  Future<List<VariantProgressTableData>> _loadSmartCards({
    required String userId,
    required QuizDirection direction,
    required SmartQuizPool pool,
    required String? langA,
    required String? langB,
    required int limit,
  }) {
    final progress = variantProgressTable;
    final query =
        _smartCards(
            userId: userId,
            directions: [direction],
            pool: pool,
            langA: langA,
            langB: langB,
            countOnly: false,
          )
          ..orderBy([
            OrderingTerm.asc(progress.nextReview),
            OrderingTerm.asc(progress.reps),
          ])
          ..limit(limit);
    return query.map((row) => row.readTable(progress)).get();
  }

  Stream<int> watchSmartQuizCardCount({
    required String userId,
    required List<QuizDirection> directions,
    required SmartQuizPool pool,
    required String langA,
    required String langB,
    Duration refreshEvery = const Duration(minutes: 1),
  }) {
    final count = countAll();
    final query = _smartCards(
      userId: userId,
      directions: directions,
      pool: pool,
      langA: langA,
      langB: langB,
      countOnly: true,
    )..addColumns([count]);
    return _watchCount(
      query.map((row) => row.read(count)!),
      refreshEvery: pool == SmartQuizPool.due ? refreshEvery : null,
    );
  }

  JoinedSelectStatement _smartCards({
    required String userId,
    required List<QuizDirection> directions,
    required SmartQuizPool pool,
    required String? langA,
    required String? langB,
    required bool countOnly,
  }) {
    final progress = variantProgressTable;
    final variants = wordVariantsTable;
    final joins = [
      innerJoin(
        variants,
        variants.id.equalsExp(progress.variantId),
        useColumns: false,
      ),
      ..._contentJoins(),
    ];
    final query = countOnly
        ? selectOnly(progress).join(joins)
        : select(progress).join(joins);
    final poolFilter = switch (pool) {
      SmartQuizPool.due =>
        progress.nextReview.isNull() |
            progress.nextReview.isSmallerOrEqual(currentDateAndTime),
      SmartQuizPool.inProgress => progress.state.equals('newCard').not(),
    };
    final playable = directions.fold<Expression<bool>>(
      const Constant(false),
      (any, direction) =>
          any |
          (progress.direction.equals(direction.name) &
              _playableDirection(direction)),
    );
    return query..where(
      progress.userId.equals(userId) &
          _liveContent(userId, langA: langA, langB: langB) &
          poolFilter &
          playable,
    );
  }

  Future<List<String>> getPlayableListVariantIds({
    required String userId,
    required String listId,
    required QuizDirection direction,
  }) {
    final id = wordVariantsTable.id;
    final query = _listCards(
      userId: userId,
      listId: listId,
      directions: [direction],
    )..addColumns([id]);
    return query.map((row) => row.read(id)!).get();
  }

  Stream<int> watchListQuizCardCount({
    required String userId,
    required String listId,
    required List<QuizDirection> directions,
    required String langA,
    required String langB,
  }) {
    final count = countAll();
    final query = _listCards(
      userId: userId,
      listId: listId,
      directions: directions,
      langA: langA,
      langB: langB,
    )..addColumns([count]);
    return query.map((row) => row.read(count)!).watchSingle().distinct();
  }

  JoinedSelectStatement _listCards({
    required String userId,
    required String listId,
    required List<QuizDirection> directions,
    String? langA,
    String? langB,
  }) {
    final resolved = db.vocabularyListDao.starterIdExpression(
      StarterAliasKind.list,
      userId,
      listId,
    );
    final playable = directions.fold<Expression<bool>>(
      const Constant(false),
      (any, direction) => any | _playableDirection(direction),
    );
    return selectOnly(wordVariantsTable).join(_contentJoins())..where(
      db.vocabularyListsTable.id.equalsExp(resolved) &
          _liveContent(userId, langA: langA, langB: langB) &
          playable,
    );
  }

  List<Join> _contentJoins() => [
    innerJoin(
      db.conceptsTable,
      db.conceptsTable.id.equalsExp(wordVariantsTable.conceptId),
      useColumns: false,
    ),
    innerJoin(
      db.vocabularyListsTable,
      db.vocabularyListsTable.id.equalsExp(db.conceptsTable.listId),
      useColumns: false,
    ),
  ];

  Expression<bool> _liveContent(
    String ownerId, {
    String? langA,
    String? langB,
  }) {
    final lists = db.vocabularyListsTable;
    return lists.ownerId.equals(ownerId) &
        lists.isDeleted.equals(false) &
        db.conceptsTable.isDeleted.equals(false) &
        wordVariantsTable.isDeleted.equals(false) &
        (langA == null ? const Constant(true) : lists.langA.equals(langA)) &
        (langB == null ? const Constant(true) : lists.langB.equals(langB));
  }

  Expression<bool> _playableDirection(QuizDirection direction) {
    final answer = alias(wordVariantsTable, 'answer_variant');
    final alternatives = selectOnly(answer)
      ..addColumns([answer.id])
      ..where(
        answer.conceptId.equalsExp(wordVariantsTable.conceptId) &
            answer.langCode.equals(direction.answerLang) &
            answer.isDeleted.equals(false),
      );
    return wordVariantsTable.langCode.equals(direction.questionLang) &
        existsQuery(alternatives);
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
    required int limit,
  }) {
    return (select(variantProgressTable)
          ..where(
            (t) =>
                t.userId.equals(userId) &
                t.direction.equals(direction) &
                t.variantId.isIn(variantIds),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.nextReview)])
          ..limit(limit))
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

  Future<int> deleteProgressForConcept({
    required String userId,
    required String conceptId,
  }) {
    final variants = selectOnly(wordVariantsTable)
      ..addColumns([wordVariantsTable.id])
      ..where(wordVariantsTable.conceptId.equals(conceptId));
    return (delete(variantProgressTable)..where(
          (t) => t.userId.equals(userId) & t.variantId.isInQuery(variants),
        ))
        .go();
  }

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

  Future<int> markProgressSynced(List<String> ids) =>
      (update(variantProgressTable)..where((t) => t.id.isIn(ids))).write(
        const VariantProgressTableCompanion(isSynced: Value(true)),
      );

  Future<int> acknowledge(VariantProgressTableData row) =>
      acknowledgeSyncSnapshot(this, variantProgressTable, row);
}
