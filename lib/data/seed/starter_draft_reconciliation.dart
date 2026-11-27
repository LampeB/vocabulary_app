import 'dart:convert' show jsonEncode;

import 'package:drift/drift.dart';

import '../../domain/entities/vocabulary_list.dart';
import '../../services/audio/audio_asset_path.dart';
import '../datasources/local/app_database.dart';
import '../datasources/local/daos/vocabulary_list_dao.dart';

/// Adopts a server list's established IDs after offline starter creation.
/// Called after a complete pull, inside the same SQLite transaction.
class StarterDraftReconciliation {
  StarterDraftReconciliation(this._db);

  final AppDatabase _db;

  Future<void> reconcile(String userId, List<VocabularyList> remote) async {
    final lists = _db.vocabularyListDao;
    final drafts = await lists.heldStarterDrafts(ownerId: userId);
    for (final draft in drafts) {
      final identities = remote
          .where(
            (list) =>
                list.origin == 'starter' &&
                list.seedId == draft.seedId &&
                list.langA == draft.langA &&
                list.langB == draft.langB,
          )
          .toList();
      if (identities.isEmpty || identities.any((list) => list.id == draft.id)) {
        await lists.releaseStarterDraft(draft.id);
      } else if (identities.length == 1) {
        final canonical = await lists.getById(identities.single.id);
        if (canonical != null) await _adopt(draft, canonical);
      }
      // Ambiguous legacy identities remain available locally and held from
      // publication. Choosing one would overwrite or discard user data.
    }
  }

  Future<List<ConceptsTableData>> _concepts(String listId) => (_db.select(
    _db.conceptsTable,
  )..where((t) => t.listId.equals(listId))).get();

  Future<List<WordVariantsTableData>> _variants(String conceptId) =>
      (_db.select(
        _db.wordVariantsTable,
      )..where((t) => t.conceptId.equals(conceptId))).get();

  Future<void> _adopt(
    VocabularyListsTableData draft,
    VocabularyListsTableData canonical,
  ) async {
    final base = await _db.vocabularyListDao.getSharedImportBase(draft.id);
    // Previous versions did not track a draft's baseline, so a second copy
    // cannot be reconciled without guessing which of its fields were edited.
    if (base == null) return;
    final deleted = draft.isDeleted || canonical.isDeleted;
    final draftConcepts = await _concepts(draft.id);
    final establishedConcepts = await _concepts(canonical.id);
    final conceptMatches = <ConceptsTableData, ConceptsTableData?>{};
    final variantMatches = <WordVariantsTableData, WordVariantsTableData?>{};
    final removedConcepts = <String>{};
    final removedVariants = <String>{};

    for (final draftConcept in draftConcepts) {
      final seedId = draftConcept.seedId;
      final candidates = establishedConcepts
          .where((row) => seedId != null && row.seedId == seedId)
          .toList();
      if (candidates.length > 1) return;
      final establishedConcept = candidates.firstOrNull;
      conceptMatches[draftConcept] = establishedConcept;
      final oldVariants = await _variants(draftConcept.id);
      if (deleted || establishedConcept?.isDeleted == true) {
        removedConcepts.add(draftConcept.id);
        removedVariants.addAll(oldVariants.map((row) => row.id));
        continue;
      }
      if (establishedConcept == null) continue;
      final existingVariants = await _variants(establishedConcept.id);
      final used = <String>{};
      for (final variant in oldVariants) {
        final base = await _db.vocabularyListDao.getSharedImportBase(
          variant.id,
        );
        if (base == null) {
          variantMatches[variant] = null;
          continue;
        }
        final original = WordVariantsTableData.fromJson(base);
        final slot = existingVariants
            .where(
              (row) =>
                  row.langCode == original.langCode &&
                  row.position == original.position,
            )
            .toList();
        final sameWord = slot
            .where((row) => row.word == original.word)
            .toList();
        final matches = sameWord.isEmpty ? slot : sameWord;
        if (matches.length > 1) return;
        final target = matches.firstOrNull;
        if (target != null && !used.add(target.id)) return;
        variantMatches[variant] = target;
        if (target?.isDeleted == true) removedVariants.add(variant.id);
      }
    }

    // FSRS schedules cannot be combined without both chronological histories.
    // Keep both originals intact if the same card already has two histories.
    final targetIds = variantMatches.values
        .whereType<WordVariantsTableData>()
        .map((row) => row.id)
        .toSet();
    final progress =
        await (_db.select(_db.variantProgressTable)..where(
              (t) =>
                  t.userId.equals(draft.ownerId) &
                  t.variantId.isIn({
                    ...variantMatches.keys.map((row) => row.id),
                    ...targetIds,
                  }),
            ))
            .get();
    final progressKeys = {
      for (final row in progress) (row.variantId, row.direction),
    };
    for (final entry in variantMatches.entries) {
      final target = entry.value;
      if (target == null || removedVariants.contains(entry.key.id)) continue;
      if (progress.any(
        (row) =>
            row.variantId == entry.key.id &&
            progressKeys.contains((target.id, row.direction)),
      )) {
        return;
      }
    }

    final lists = _db.vocabularyListDao;
    final edits = await _edits(
      draft.id,
      draft,
      ignored: {'ownerId', 'wordCount', 'seedId', 'langA', 'langB', 'origin'},
    );
    if (!canonical.isDeleted && edits.isNotEmpty) {
      await lists.upsert(
        VocabularyListsTableData.fromJson({
          ...canonical.toJson(),
          ...edits,
        }).toCompanion(false),
      );
    }

    await (_db.update(_db.reviewEventsTable)..where(
          (t) => t.userId.equals(draft.ownerId) & t.listId.equals(draft.id),
        ))
        .write(ReviewEventsTableCompanion(listId: Value(canonical.id)));
    await (_db.update(_db.quizSessionsTable)..where(
          (t) => t.userId.equals(draft.ownerId) & t.listId.equals(draft.id),
        ))
        .write(QuizSessionsTableCompanion(listId: Value(canonical.id)));
    await lists.rememberStarterAlias(
      StarterAliasKind.list,
      draft.ownerId,
      draft.id,
      canonical.id,
    );

    for (final entry in conceptMatches.entries) {
      final source = entry.key;
      final target = entry.value;
      if (removedConcepts.contains(source.id)) continue;
      if (target == null) {
        await _db.conceptDao.upsert(
          source.copyWith(listId: canonical.id).toCompanion(false),
        );
        continue;
      }
      final edits = await _edits(
        source.id,
        source,
        ignored: {'listId', 'seedId'},
      );
      if (edits.isNotEmpty) {
        await _db.conceptDao.upsert(
          ConceptsTableData.fromJson({
            ...target.toJson(),
            ...edits,
          }).toCompanion(false),
        );
      }
      removedConcepts.add(source.id);
    }

    for (final entry in variantMatches.entries) {
      final source = entry.key;
      final target = entry.value;
      if (target == null) {
        final targetConcept = conceptMatches.entries
            .firstWhere((row) => row.key.id == source.conceptId)
            .value!;
        await _db.conceptDao.upsertVariant(
          source.copyWith(conceptId: targetConcept.id).toCompanion(false),
        );
        continue;
      }
      await _remapVariant(draft.ownerId, source, target);
      removedVariants.add(source.id);
    }

    await _db.progressDao.deleteProgressForVariants(
      userId: draft.ownerId,
      variantIds: removedVariants.toList(),
    );
    await (_db.delete(
      _db.wordVariantsTable,
    )..where((t) => t.id.isIn(removedVariants))).go();
    await (_db.delete(
      _db.conceptsTable,
    )..where((t) => t.id.isIn(removedConcepts))).go();
    await (_db.delete(
      _db.vocabularyListsTable,
    )..where((t) => t.id.equals(draft.id))).go();
    await lists.forgetSharedImportBases([
      draft.id,
      ...removedConcepts,
      ...removedVariants,
    ]);
    await lists.releaseStarterDraft(draft.id);
    if (draft.isDeleted && !canonical.isDeleted) {
      await _db.conceptDao.tombstoneListContents(canonical.id, draft.ownerId);
    } else if (!deleted) {
      await _db.conceptDao.refreshListWordCount(canonical.id);
    }
  }

  Future<void> _remapVariant(
    String userId,
    WordVariantsTableData source,
    WordVariantsTableData target,
  ) async {
    if (!target.isDeleted) {
      final edits = await _edits(
        source.id,
        source,
        ignored: {'conceptId', 'audioPath', 'audioHash', 'audioVoiceId'},
      );
      if (edits.isNotEmpty) {
        var merged = WordVariantsTableData.fromJson({
          ...target.toJson(),
          ...edits,
        });
        if (merged.word != target.word || merged.langCode != target.langCode) {
          merged = merged.copyWith(
            audioPath: Value(
              AudioAssetPath.user(
                userId: userId,
                variantId: target.id,
                text: merged.word,
                langCode: merged.langCode,
              ),
            ),
            audioHash: const Value(null),
            audioVoiceId: const Value(null),
          );
        }
        await _db.conceptDao.upsertVariant(merged.toCompanion(false));
      }
      await (_db.update(_db.variantProgressTable)..where(
            (t) => t.userId.equals(userId) & t.variantId.equals(source.id),
          ))
          .write(
            VariantProgressTableCompanion(
              variantId: Value(target.id),
              isSynced: const Value(false),
            ),
          );
    }
    await (_db.update(_db.reviewEventsTable)..where(
          (t) => t.userId.equals(userId) & t.variantId.equals(source.id),
        ))
        .write(ReviewEventsTableCompanion(variantId: Value(target.id)));
    await _db.vocabularyListDao.rememberStarterAlias(
      StarterAliasKind.variant,
      userId,
      source.id,
      target.id,
    );
  }

  Future<Map<String, dynamic>> _edits(
    String id,
    DataClass current, {
    required Set<String> ignored,
  }) async {
    final base = await _db.vocabularyListDao.getSharedImportBase(id);
    if (base == null) return {};
    final snapshot = current.toJson();
    final excluded = {'id', 'createdAt', 'updatedAt', 'isSynced', ...ignored};
    final edits = {
      for (final entry in snapshot.entries)
        if (!excluded.contains(entry.key) &&
            jsonEncode(base[entry.key]) != jsonEncode(entry.value))
          entry.key: entry.value,
    };
    if (edits.isNotEmpty) {
      edits['updatedAt'] = snapshot['updatedAt'];
      edits['isSynced'] = false;
    }
    return edits;
  }
}
