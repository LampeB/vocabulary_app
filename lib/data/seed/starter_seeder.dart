import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/services.dart' show AssetBundle;
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/repositories/vocabulary_repository.dart';
import '../../core/errors/failure.dart';
import '../datasources/local/app_database.dart';
import '../datasources/local/daos/concept_dao.dart';
import '../datasources/local/daos/vocabulary_list_dao.dart';
import '../sync/vocabulary_sync_ids.dart';
import 'seed_catalog.dart';
import 'starter_identity.dart';
import '../../services/audio/audio_asset_path.dart';

/// Seeds the starter curriculum for one ordered language pair, composing the
/// content from the per-language catalog layers (see [SeedCatalog]).
///
/// Idempotent at three levels:
/// - a per-user+pair SharedPreferences flag makes the whole run once-ever
///   (deleting a starter list later does NOT bring it back);
/// - lists are deduped by seed_id, never by their (localized, editable) name;
/// - within an existing list, concepts/variants are topped up per registry
///   concept id, so rows that carry FSRS progress are never touched. This is
///   also what heals installs seeded by the pre-v3 pipeline, which dropped
///   every variant (snake_case/camelCase key mismatch).
class StarterSeeder {
  StarterSeeder({
    required this._bundle,
    required this._repo,
    required this._listDao,
    required this._conceptDao,
    required this._userId,
    this._uiLocale,
  });

  final AssetBundle _bundle;
  final VocabularyRepository _repo;
  final VocabularyListDao _listDao;
  final ConceptDao _conceptDao;
  final String _userId;
  final String? _uiLocale;
  static final _executions = Expando<Map<String, Future<void>>>();

  /// Canonical French names of the pre-catalog fr→ko starter lists, for
  /// adopting rows created before seed ids existed.
  static const legacyFrKoNames = {
    'Salutations & politesse': 'starter-greetings',
    'Les nombres & le temps': 'starter-numbers-time',
    'La nourriture': 'starter-food',
    'La vie quotidienne': 'starter-daily-life',
    'Se déplacer': 'starter-getting-around',
    'Les particules essentielles': 'starter-ko-particles',
  };

  static String flagKeyFor(String userId, String source, String target) =>
      'seeded_starter_v3_${userId}_$source>$target';

  Future<void> ensureSeededForPair(String source, String target) {
    final runs = _executions[_listDao] ??= <String, Future<void>>{};
    final key = flagKeyFor(_userId, source, target);
    final running = runs[key];
    if (running != null) return running;
    final run = _seedPair(source, target);
    runs[key] = run;
    return run.whenComplete(() => runs.remove(key));
  }

  Future<void> _seedPair(String source, String target) async {
    if (source == target || _userId.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final flagKey = flagKeyFor(_userId, source, target);
    if (prefs.getBool(flagKey) ?? false) return;

    final catalog = await SeedCatalog.load(_bundle);
    final SeedLanguageLayer sourceLayer;
    final SeedLanguageLayer targetLayer;
    try {
      sourceLayer = await SeedLanguageLayer.load(_bundle, source);
      targetLayer = await SeedLanguageLayer.load(_bundle, target);
    } catch (_) {
      // No catalog layer for one of the languages — nothing to seed. Do NOT
      // set the flag: a later release shipping the layer should seed then.
      return;
    }
    final uiLocale = _uiLocale;
    final names = await SeedTranslations.load(_bundle, [
      ?uiLocale,
      source,
      'en',
      'fr',
    ]);

    if (source == 'fr' && target == 'ko') {
      await _adoptLegacyFrKoLists(catalog, sourceLayer, targetLayer);
    }

    final bySeedId = <String, VocabularyListsTableData>{};
    for (final list in await _listDao.getStarterLists(_userId)) {
      if (list.langA == source && list.langB == target) {
        bySeedId.putIfAbsent(list.seedId!, () => list);
      }
    }

    var complete = true;
    for (final seedList in catalog.listsForTarget(target)) {
      final seedId = seedList.seedIdFor(source, target);
      final existing = bySeedId[seedId];
      if (existing == null) {
        final imported = await _repo.importFromJson(
          _composeListJson(
            seedList,
            seedId,
            catalog,
            sourceLayer,
            targetLayer,
            names,
          ),
          origin: 'starter',
        );
        if (imported.isFailure) {
          throw StateError(
            'Starter import failed: ${imported.exceptionOrNull?.message}',
          );
        }
      } else if (!existing.isDeleted) {
        final ready = await _topUp(
          existing.id,
          seedList,
          catalog,
          sourceLayer,
          targetLayer,
        );
        if (!ready) complete = false;
      }
    }

    if (complete) await prefs.setBool(flagKey, true);
  }

  /// Stamps seed identities onto starter lists created before the catalog
  /// existed (matched by their canonical French names) and clears out their
  /// variant-less concepts — those were produced by the broken pre-v3 import
  /// and, having no variants, can carry no progress, so deleting them and
  /// re-seeding via top-up is lossless.
  Future<void> _adoptLegacyFrKoLists(
    SeedCatalog catalog,
    SeedLanguageLayer frLayer,
    SeedLanguageLayer koLayer,
  ) async {
    final myLists = await _listDao.watchByOwner(_userId).first;
    for (final list in myLists) {
      if (list.seedId != null || list.origin != 'starter') continue;
      final curriculumId = legacyFrKoNames[list.name];
      if (curriculumId == null) continue;
      await _listDao.attachedDatabase.writeOutbound(_userId, () async {
        await _listDao.stampSeedIdentity(
          list.id,
          '$curriculumId:fr>ko',
          'fr',
          'ko',
        );

        final seedList = catalog.lists
            .where((l) => l.id == curriculumId)
            .firstOrNull;
        if (seedList == null) return;
        // Registry id → every known word for that concept in either language.
        final wordIndex = {
          for (final id in seedList.conceptIds)
            id: {
              ...?frLayer.entries[id]?.words.map((w) => w.word),
              ...?koLayer.entries[id]?.words.map((w) => w.word),
            },
        };

        final concepts = await _conceptDao.getConceptsByList(
          list.id,
          includeDeleted: true,
        );
        for (final concept in concepts) {
          if (concept.seedId != null) continue;
          final variants = await _conceptDao.getVariantsByConcept(
            concept.id,
            includeDeleted: true,
          );
          if (variants.isEmpty) {
            if (!concept.isDeleted) await _conceptDao.softDelete(concept.id);
          } else {
            // Healthy pre-catalog concept: recover its registry id by matching
            // any of its words in either language so top-up won't duplicate it.
            final registryId = wordIndex.entries
                .where((e) => variants.any((v) => e.value.contains(v.word)))
                .map((e) => e.key)
                .firstOrNull;
            if (registryId != null) {
              await _conceptDao.stampSeedId(concept.id, registryId);
            }
          }
        }
      });
    }
  }

  /// Canonical snake_case import payload (the same shape the repository's
  /// importFromJson reads for seed/remote data).
  Map<String, dynamic> _composeListJson(
    SeedList seedList,
    String seedId,
    SeedCatalog catalog,
    SeedLanguageLayer sourceLayer,
    SeedLanguageLayer targetLayer,
    SeedTranslations names,
  ) => {
    'list': {
      'name': names.resolve(seedList.nameKey),
      'description': names.resolve(seedList.descKey),
      'lang_a': sourceLayer.lang,
      'lang_b': targetLayer.lang,
      'seed_id': seedId,
      'concepts': [
        for (final conceptId in seedList.conceptIds)
          if (sourceLayer.entries[conceptId] != null &&
              targetLayer.entries[conceptId] != null)
            _composeConceptJson(
              conceptId,
              catalog,
              sourceLayer.entries[conceptId]!,
              sourceLayer.lang,
              targetLayer.entries[conceptId]!,
              targetLayer.lang,
            ),
      ],
    },
  };

  Map<String, dynamic> _composeConceptJson(
    String conceptId,
    SeedCatalog catalog,
    SeedEntry sourceEntry,
    String sourceLang,
    SeedEntry targetEntry,
    String targetLang,
  ) => {
    'category': catalog.conceptCategories[conceptId],
    'seed_id': conceptId,
    'notes': targetEntry.noteFor(sourceLang),
    'word_variants': [
      ..._variantJsons(sourceEntry, sourceLang),
      ..._variantJsons(targetEntry, targetLang),
    ],
  };

  List<Map<String, dynamic>> _variantJsons(SeedEntry entry, String lang) => [
    for (final w in entry.words)
      {
        'word': w.word,
        'lang_code': lang,
        'is_primary': w.isPrimary,
        'position': w.position,
        if (w.tags.isNotEmpty) 'context_tags': w.tags,
        // The example sentence belongs to the primary word.
        if (w.isPrimary && entry.example != null) 'example': entry.example,
      },
  ];

  /// Adds whatever an existing seeded list is missing — new registry concepts,
  /// or a missing language variant on an existing concept (the healing path
  /// for pre-v3 installs). Never modifies existing variants.
  Future<bool> _topUp(
    String listId,
    SeedList seedList,
    SeedCatalog catalog,
    SeedLanguageLayer sourceLayer,
    SeedLanguageLayer targetLayer,
  ) => _listDao.transaction(() async {
    final resolved = await _listDao.resolveStarterId(
      StarterAliasKind.list,
      _userId,
      listId,
    );
    final list = await _listDao.getById(resolved);
    if (list == null || list.isDeleted || list.ownerId != _userId) return true;
    if (await _listDao.isStarterContentsPending(list.id)) return false;
    final ids = await VocabularySyncIds.load(
      _listDao.attachedDatabase,
      _userId,
    );
    final now = DateTime.now();
    final concepts = await _conceptDao.getConceptsByList(
      list.id,
      includeDeleted: true,
    );
    final bySeedId = <String, ConceptsTableData>{};
    for (final concept in concepts) {
      final seedId = concept.seedId;
      if (seedId == null) continue;
      if (bySeedId[seedId]?.isDeleted != false) bySeedId[seedId] = concept;
    }

    var added = false;
    for (final conceptId in seedList.conceptIds) {
      final sourceEntry = sourceLayer.entries[conceptId];
      final targetEntry = targetLayer.entries[conceptId];
      if (sourceEntry == null || targetEntry == null) continue;

      final existing = bySeedId[conceptId];
      if (existing?.isDeleted == true) continue;
      if (existing == null) {
        added = true;
        final newConceptId = await ids.reserve(
          SyncedVocabularyRow.concept,
          starterConceptId(
            ids.wireId(SyncedVocabularyRow.list, list.id),
            conceptId,
          ),
        );
        await _conceptDao.upsert(
          ConceptsTableCompanion(
            id: Value(newConceptId),
            listId: Value(list.id),
            category: Value(catalog.conceptCategories[conceptId]),
            notes: Value(targetEntry.noteFor(sourceLayer.lang)),
            seedId: Value(conceptId),
            isDeleted: const Value(false),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
        await _listDao.rememberSharedImport(
          newConceptId,
          (await _conceptDao.getById(newConceptId))!,
        );
        for (final entry in [
          (sourceEntry, sourceLayer.lang),
          (targetEntry, targetLayer.lang),
        ]) {
          await _insertVariants(ids, newConceptId, entry.$1, entry.$2, now);
        }
      } else {
        final variants = await _conceptDao.getVariantsByConcept(
          existing.id,
          includeDeleted: true,
        );
        final presentLangs = variants.map((v) => v.langCode).toSet();
        if (!presentLangs.contains(sourceLayer.lang)) {
          added = true;
          await _insertVariants(
            ids,
            existing.id,
            sourceEntry,
            sourceLayer.lang,
            now,
          );
        }
        if (!presentLangs.contains(targetLayer.lang)) {
          added = true;
          await _insertVariants(
            ids,
            existing.id,
            targetEntry,
            targetLayer.lang,
            now,
          );
        }
      }
    }

    if (added) {
      await ids.save();
      final count = await _conceptDao.countByList(list.id);
      await _listDao.updateWordCount(list.id, count);
      _listDao.attachedDatabase.notifyOutboundMutation(_userId);
    }
    return true;
  });

  Future<void> _insertVariants(
    VocabularySyncIds ids,
    String conceptId,
    SeedEntry entry,
    String lang,
    DateTime now,
  ) async {
    final seenSlots = <int, int>{};
    for (final w in entry.words) {
      final occurrence = seenSlots.update(
        w.position,
        (n) => n + 1,
        ifAbsent: () => 0,
      );
      final id = await ids.reserve(
        SyncedVocabularyRow.variant,
        starterVariantId(
          ids.wireId(SyncedVocabularyRow.concept, conceptId),
          lang,
          w.position,
          occurrence,
        ),
      );
      await _conceptDao.upsertVariant(
        WordVariantsTableCompanion(
          id: Value(id),
          conceptId: Value(conceptId),
          word: Value(w.word),
          langCode: Value(lang),
          contextTags: Value(jsonEncode(w.tags)),
          isPrimary: Value(w.isPrimary),
          position: Value(w.position),
          example: Value(w.isPrimary ? entry.example : null),
          audioPath: Value(AudioAssetPath.seed(text: w.word, langCode: lang)),
          isDeleted: const Value(false),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      await _listDao.rememberSharedImport(
        id,
        (await _conceptDao.getVariantById(id))!,
      );
    }
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
