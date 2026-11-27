import 'dart:convert' show jsonDecode, jsonEncode;
import 'package:flutter/foundation.dart' show listEquals;
import 'package:uuid/uuid.dart';
import '../../domain/entities/concept.dart';
import '../../domain/entities/vocabulary_list.dart';
import '../../domain/entities/word_variant.dart';
import '../../domain/repositories/vocabulary_repository.dart';
import '../../core/errors/failure.dart';
import '../../core/errors/app_exception.dart';
import '../datasources/local/daos/vocabulary_list_dao.dart';
import '../datasources/local/daos/concept_dao.dart';
import '../datasources/local/app_database.dart';
import '../datasources/remote/vocabulary_remote_datasource.dart';
import '../models/concept_dto.dart';
import '../models/variant_progress_dto.dart';
import '../models/vocabulary_list_dto.dart';
import '../models/word_variant_dto.dart';
import '../seed/starter_draft_reconciliation.dart';
import '../seed/starter_identity.dart';
import '../sync/vocabulary_sync_ids.dart';
import '../../services/audio/audio_asset_path.dart';
import 'package:drift/drift.dart' show Value, Variable, innerJoin;

const _uuid = Uuid();
const _accountRequired = AuthException('Sign in to save vocabulary');
const _deferredDeletion = StorageException(
  'A remote deletion needs another pull',
);

class VocabularyRepositoryImpl implements VocabularyRepository {
  VocabularyRepositoryImpl(
    this._listDao,
    this._conceptDao,
    this._remote,
    this._userId,
    this._database, {
    this._restoreTimeout = const Duration(seconds: 15),
  });

  final VocabularyListDao _listDao;
  final ConceptDao _conceptDao;
  final VocabularyRemoteDataSource _remote;
  final String _userId;
  final AppDatabase _database;
  final Duration _restoreTimeout;
  Future<void>? _activeRestoration;
  bool _starterIdentityReady = false;

  @override
  Stream<List<VocabularyList>> watchMyLists() => _listDao
      .watchByOwner(_userId)
      .map((rows) => rows.map((r) => r.toDomain()).toList());

  @override
  Future<Result<VocabularyList>> createList({
    required String name,
    String? description,
    String langA = 'fr',
    String langB = 'ko',
  }) async {
    if (_userId.isEmpty) return const Failure(_accountRequired);
    final now = DateTime.now();
    final list = VocabularyList(
      id: _uuid.v4(),
      ownerId: _userId,
      name: name,
      description: description,
      langA: langA,
      langB: langB,
      createdAt: now,
      updatedAt: now,
    );
    try {
      await _database.writeOutbound(
        _userId,
        () => _listDao.upsert(list.toLocalCompanion()),
      );
      return Success(list);
    } catch (e) {
      return Failure(StorageException(e.toString()));
    }
  }

  @override
  Future<Result<VocabularyList>> updateList(VocabularyList list) =>
      _write(() async {
        final current = await _requireList(list.id);
        return _updateList(
          list.copyWith(
            id: current.id,
            ownerId: current.ownerId,
            wordCount: current.wordCount,
            origin: current.origin,
            seedId: current.seedId,
            createdAt: current.createdAt,
            isDeleted: false,
          ),
        );
      });

  @override
  Future<Result<VocabularyList>> renameList(String listId, String name) =>
      _write(() async {
        final list = await _requireList(listId);
        return _updateList(list.toDomain().copyWith(name: name));
      });

  Future<VocabularyList> _updateList(VocabularyList list) async {
    final updated = list.copyWith(updatedAt: DateTime.now(), isSynced: false);
    await _listDao.upsert(updated.toLocalCompanion());
    return updated;
  }

  @override
  Future<Result<void>> deleteList(String listId) => _write(() async {
    final list = await _requireList(listId);
    // Deleting a list frees a quota slot but the user LOSES its mastery
    // (product decision 2026-07-04): soft-delete the words so they vanish
    // from smart lists, and delete their progress rows outright.
    final concepts = await _conceptDao.getConceptsByList(list.id);
    final conceptIds = concepts.map((c) => c.id).toList();
    final variantIds = await _database.progressDao.getVariantIdsForConcepts(
      conceptIds,
    );
    await _listDao.softDelete(list.id);
    for (final id in conceptIds) {
      await _conceptDao.softDelete(id);
    }
    for (final id in variantIds) {
      await _conceptDao.softDeleteVariant(id);
    }
    await _database.progressDao.deleteProgressForVariants(
      userId: _userId,
      variantIds: variantIds,
    );
  });

  @override
  Future<Result<VocabularyList>> getListById(String listId) async {
    final row = await _database.transaction(() => _findList(listId));
    if (row == null) return const Failure(NotFoundException('List not found'));
    return Success(row.toDomain());
  }

  @override
  Stream<VocabularyList?> watchListById(String listId) => _listDao
      .watchById(listId, ownerId: _userId)
      .map((row) => row?.isDeleted == false ? row!.toDomain() : null)
      .distinct(
        (previous, next) =>
            previous?.copyWith(isSynced: false) ==
            next?.copyWith(isSynced: false),
      );

  @override
  Future<Result<VocabularyList?>> getListByShareToken(String token) async {
    final row = await _listDao.getByShareToken(token, ownerId: _userId);
    return Success(row?.toDomain());
  }

  @override
  Stream<List<Concept>> watchConcepts(String listId) => _conceptDao
      .watchByList(listId, ownerId: _userId)
      .map(
        (rows) => rows
            .map(
              (r) => Concept(
                id: r.id,
                listId: r.listId,
                category: r.category,
                notes: r.notes,
                imageUrl: r.imageUrl,
                exampleFr: r.exampleFr,
                exampleKo: r.exampleKo,
                seedId: r.seedId,
                createdAt: r.createdAt,
                updatedAt: r.updatedAt,
              ),
            )
            .toList(),
      )
      .distinct(listEquals);

  @override
  Future<Result<Concept>> createConcept({
    required String listId,
    String? category,
    String? notes,
    String? exampleFr,
    String? exampleKo,
  }) => _write(() async {
    final list = await _requireList(listId);
    final now = DateTime.now();
    final concept = Concept(
      id: _uuid.v4(),
      listId: list.id,
      category: category,
      notes: notes,
      exampleFr: exampleFr,
      exampleKo: exampleKo,
      createdAt: now,
      updatedAt: now,
    );
    await _saveConcept(concept);
    await _updateWordCount(list.id, 1);
    return concept;
  });

  @override
  Future<Result<Concept>> addConceptWithVariants({
    required String listId,
    required String wordA,
    required String wordB,
    String langA = 'fr',
    String langB = 'ko',
    String? notes,
    String? category,
  }) => _write(() async {
    final list = await _requireList(listId);
    final now = DateTime.now();
    final concept = Concept(
      id: _uuid.v4(),
      listId: list.id,
      category: category,
      notes: notes,
      createdAt: now,
      updatedAt: now,
    );
    final frVariantId = _uuid.v4();
    final frVariant = WordVariant(
      id: frVariantId,
      conceptId: concept.id,
      word: wordA,
      langCode: langA,
      isPrimary: true,
      audioPath: AudioAssetPath.user(
        userId: _userId,
        variantId: frVariantId,
        text: wordA,
        langCode: langA,
      ),
      createdAt: now,
      updatedAt: now,
    );
    final koVariantId = _uuid.v4();
    final koVariant = WordVariant(
      id: koVariantId,
      conceptId: concept.id,
      word: wordB,
      langCode: langB,
      isPrimary: true,
      audioPath: AudioAssetPath.user(
        userId: _userId,
        variantId: koVariantId,
        text: wordB,
        langCode: langB,
      ),
      createdAt: now,
      updatedAt: now,
    );
    await _saveConcept(concept);
    await _conceptDao.upsertVariant(frVariant.toLocalCompanion());
    await _conceptDao.upsertVariant(koVariant.toLocalCompanion());
    await _updateWordCount(list.id, 1);
    return concept;
  });

  @override
  Future<Result<Concept>> updateConcept(Concept concept) => _write(() async {
    final current = await _requireConcept(concept.id);
    final updated = concept.copyWith(
      id: current.id,
      listId: current.listId,
      seedId: current.seedId,
      createdAt: current.createdAt,
      updatedAt: DateTime.now(),
      isSynced: false,
      isDeleted: false,
    );
    await _saveConcept(updated);
    return updated;
  });

  Future<void> _saveConcept(Concept concept) => _conceptDao.upsert(
    ConceptsTableCompanion(
      id: Value(concept.id),
      listId: Value(concept.listId),
      category: Value(concept.category),
      notes: Value(concept.notes),
      imageUrl: Value(concept.imageUrl),
      exampleFr: Value(concept.exampleFr),
      exampleKo: Value(concept.exampleKo),
      seedId: Value(concept.seedId),
      isSynced: const Value(false),
      createdAt: Value(concept.createdAt),
      updatedAt: Value(concept.updatedAt),
    ),
  );

  @override
  Future<Result<void>> deleteConcept(String conceptId) => _write(() async {
    final row = await _requireConcept(conceptId);
    await _conceptDao.softDelete(row.id);
    await _database.progressDao.deleteProgressForConcept(
      userId: _userId,
      conceptId: row.id,
    );
    await _conceptDao.refreshListWordCount(row.listId);
  });

  @override
  Future<Result<List<WordVariant>>> getVariants(String conceptId) async {
    try {
      final rows = await _conceptDao.getVariantsByConcept(
        conceptId,
        ownerId: _userId,
      );
      return Success(rows.map((r) => r.toDomain()).toList());
    } catch (e) {
      return Failure(StorageException(e.toString()));
    }
  }

  @override
  Stream<List<WordVariant>> watchVariants(String conceptId) => _conceptDao
      .watchVariantsByConcept(conceptId, ownerId: _userId)
      .map(
        (rows) =>
            rows.map((r) => r.toDomain().copyWith(isSynced: false)).toList(),
      )
      .distinct(listEquals);

  @override
  Future<List<({String source, String target})>> getWordPairSample(
    String listId, {
    required int limit,
  }) => _database.transaction(() async {
    final list = await _findList(listId);
    if (list == null) return [];
    final concepts = await _conceptDao.getConceptsByList(list.id, limit: limit);
    if (concepts.isEmpty) return [];
    final ids = concepts.map((concept) => concept.id).toList();
    final sourceVariants = await _conceptDao.getVariantsByConceptIds(
      ids,
      list.langA,
      firstPerConcept: true,
    );
    final targetVariants = await _conceptDao.getVariantsByConceptIds(
      ids,
      list.langB,
      firstPerConcept: true,
    );
    final sources = {for (final row in sourceVariants) row.conceptId: row.word};
    final targets = {for (final row in targetVariants) row.conceptId: row.word};
    return [
      for (final id in ids)
        if ((sources[id], targets[id]) case (final source?, final target?))
          (source: source, target: target),
    ];
  });

  @override
  Future<Result<WordVariant>> createVariant({
    required String conceptId,
    required String word,
    required String langCode,
    String registerTag = 'neutral',
    bool isPrimary = false,
  }) => _write(() async {
    final concept = await _requireConcept(conceptId);
    final now = DateTime.now();
    final variantId = _uuid.v4();
    final variant = WordVariant(
      id: variantId,
      conceptId: concept.id,
      word: word,
      langCode: langCode,
      registerTag: registerTag,
      isPrimary: isPrimary,
      audioPath: AudioAssetPath.user(
        userId: _userId,
        variantId: variantId,
        text: word,
        langCode: langCode,
      ),
      createdAt: now,
      updatedAt: now,
    );
    await _conceptDao.upsertVariant(variant.toLocalCompanion());
    return variant;
  });

  @override
  Future<Result<WordVariant>> updateVariant(WordVariant variant) =>
      _write(() async {
        final current = await _requireVariant(variant.id);
        return _updateVariant(current, variant);
      });

  @override
  Future<Result<WordVariant>> updateVariantWord(
    String variantId,
    String word,
  ) => _write(() async {
    final current = await _requireVariant(variantId);
    return _updateVariant(current, current.toDomain().copyWith(word: word));
  });

  Future<WordVariant> _updateVariant(
    WordVariantsTableData current,
    WordVariant variant,
  ) async {
    final changedAudio =
        current.word != variant.word || current.langCode != variant.langCode;
    final updated = variant.copyWith(
      id: current.id,
      conceptId: current.conceptId,
      createdAt: current.createdAt,
      audioPath: changedAudio
          ? AudioAssetPath.user(
              userId: _userId,
              variantId: current.id,
              text: variant.word,
              langCode: variant.langCode,
            )
          : current.audioPath,
      audioHash: changedAudio ? null : current.audioHash,
      audioVoiceId: changedAudio ? null : current.audioVoiceId,
      updatedAt: DateTime.now(),
      isSynced: false,
      isDeleted: false,
    );
    await _conceptDao.upsertVariant(updated.toLocalCompanion());
    return updated;
  }

  @override
  Future<Result<void>> deleteVariant(String variantId) => _write(() async {
    final variant = await _requireVariant(variantId);
    await _conceptDao.softDeleteVariant(variant.id);
    await _database.progressDao.deleteProgressForVariants(
      userId: _userId,
      variantIds: [variant.id],
    );
  });

  @override
  Future<Result<Map<String, dynamic>>> exportToJson(String listId) async {
    try {
      return await _database.transaction(() async {
        final listRow = await _requireList(listId);
        final concepts = await _conceptDao.getConceptsByList(listRow.id);
        final conceptsJson = <Map<String, dynamic>>[];

        for (final c in concepts) {
          final variants = await _conceptDao.getVariantsByConcept(c.id);
          conceptsJson.add({
            'category': c.category,
            'notes': c.notes,
            'exampleFr': c.exampleFr,
            'exampleKo': c.exampleKo,
            'variants': variants
                .map(
                  (v) => {
                    'word': v.word,
                    'langCode': v.langCode,
                    'registerTag': v.registerTag,
                    'contextTags': jsonDecode(v.contextTags),
                    'isPrimary': v.isPrimary,
                    'position': v.position,
                    'example': v.example,
                  },
                )
                .toList(),
          });
        }

        return Success({
          'version': 1,
          'exportedAt': DateTime.now().toIso8601String(),
          'list': {
            'name': listRow.name,
            'description': listRow.description,
            'langA': listRow.langA,
            'langB': listRow.langB,
            'seedId': listRow.seedId,
            'concepts': conceptsJson,
          },
        });
      });
    } on AppException catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(StorageException(e.toString()));
    }
  }

  /// Reads [camel] from [map], falling back to its snake_case alias.
  /// Import payloads come in two shapes: app exports (camelCase) and
  /// seed/remote rows (snake_case).
  static T? _field<T>(Map<String, dynamic> map, String camel, String snake) =>
      (map[camel] ?? map[snake]) as T?;

  @override
  Future<Result<VocabularyList>> importFromJson(
    Map<String, dynamic> json, {
    String origin = 'user',
  }) => _importFromJson(json, origin: origin);

  Future<Result<VocabularyList>> _importFromJson(
    Map<String, dynamic> json, {
    String origin = 'user',
    String? sharedListId,
    String? shareToken,
  }) async {
    if (_userId.isEmpty) return const Failure(_accountRequired);
    try {
      final listData = json['list'] as Map<String, dynamic>?;
      if (listData == null) {
        return const Failure(ValidationException('Invalid export format'));
      }

      final now = DateTime.now();
      final name = listData['name'] as String? ?? 'Imported List';
      final description = listData['description'] as String?;
      final langA = _field<String>(listData, 'langA', 'lang_a') ?? 'fr';
      final langB = _field<String>(listData, 'langB', 'lang_b') ?? 'ko';
      final listSeedId = _field<String>(listData, 'seedId', 'seed_id');
      final starter = origin == 'starter' && listSeedId != null;
      final wireListId =
          sharedListId ??
          (starter
              ? _uuid.v5(
                  Namespace.url.value,
                  jsonEncode([
                    'ponderin',
                    'starter',
                    _userId,
                    langA,
                    langB,
                    listSeedId,
                  ]),
                )
              : _uuid.v4());
      final rememberBase = sharedListId != null || starter;
      final concepts =
          (listData['concepts'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      // Atomic: if any concept/variant insert fails the whole import rolls back.
      final listId = await _database.writeOutbound(_userId, () async {
        final ids = await VocabularySyncIds.load(_database, _userId);
        final listId = await ids.reserve(SyncedVocabularyRow.list, wireListId);
        await _listDao.upsert(
          VocabularyListsTableCompanion(
            id: Value(listId),
            ownerId: Value(_userId),
            name: Value(name),
            description: Value(description),
            wordCount: Value(concepts.length),
            langA: Value(langA),
            langB: Value(langB),
            origin: Value(origin),
            seedId: Value(listSeedId),
            importedFromShareToken: Value(shareToken),
            isSynced: const Value(false),
            isDeleted: const Value(false),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
        if (starter && !_starterIdentityReady) {
          await _listDao.holdStarterDraft(listId);
        }
        if (rememberBase) {
          await _listDao.rememberSharedImport(
            listId,
            (await _listDao.getById(listId))!,
          );
        }

        for (final (index, cData) in concepts.indexed) {
          final seedId = _field<String>(cData, 'seedId', 'seed_id');
          final wireConceptId = starter
              ? starterConceptId(wireListId, seedId ?? index)
              : sharedListId != null
              ? _uuid.v5(
                  wireListId,
                  jsonEncode(['concept', cData['id'] ?? index]),
                )
              : _uuid.v4();
          final conceptId = await ids.reserve(
            SyncedVocabularyRow.concept,
            wireConceptId,
          );
          await _conceptDao.upsert(
            ConceptsTableCompanion(
              id: Value(conceptId),
              listId: Value(listId),
              category: Value(cData['category'] as String?),
              notes: Value(cData['notes'] as String?),
              exampleFr: Value(
                _field<String>(cData, 'exampleFr', 'example_fr'),
              ),
              exampleKo: Value(
                _field<String>(cData, 'exampleKo', 'example_ko'),
              ),
              seedId: Value(seedId),
              isDeleted: const Value(false),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
          if (rememberBase) {
            await _listDao.rememberSharedImport(
              conceptId,
              (await _conceptDao.getById(conceptId))!,
            );
          }

          final variants =
              (_field<List>(
                cData,
                'variants',
                'word_variants',
              ))?.cast<Map<String, dynamic>>() ??
              [];
          final seenSlots = <(String, int), int>{};
          for (final (index, vData) in variants.indexed) {
            final word = vData['word'] as String? ?? '';
            final langCode =
                _field<String>(vData, 'langCode', 'lang_code') ?? langA;
            final position = vData['position'] as int? ?? 0;
            final slot = (langCode, position);
            final occurrence = seenSlots.update(
              slot,
              (n) => n + 1,
              ifAbsent: () => 0,
            );
            final wireVariantId = starter
                ? starterVariantId(
                    wireConceptId,
                    langCode,
                    position,
                    occurrence,
                  )
                : sharedListId != null
                ? _uuid.v5(
                    wireConceptId,
                    jsonEncode(['variant', vData['id'] ?? index]),
                  )
                : _uuid.v4();
            final variantId = await ids.reserve(
              SyncedVocabularyRow.variant,
              wireVariantId,
            );
            final audioPath = origin == 'starter'
                ? AudioAssetPath.seed(text: word, langCode: langCode)
                : AudioAssetPath.user(
                    userId: _userId,
                    variantId: variantId,
                    text: word,
                    langCode: langCode,
                  );
            await _conceptDao.upsertVariant(
              WordVariantsTableCompanion(
                id: Value(variantId),
                conceptId: Value(conceptId),
                word: Value(word),
                langCode: Value(langCode),
                registerTag: Value(
                  _field<String>(vData, 'registerTag', 'register_tag') ??
                      'neutral',
                ),
                contextTags: Value(
                  jsonEncode(
                    _field<List>(vData, 'contextTags', 'context_tags') ??
                        const [],
                  ),
                ),
                isPrimary: Value(
                  _field<bool>(vData, 'isPrimary', 'is_primary') ?? false,
                ),
                position: Value(position),
                example: Value(vData['example'] as String?),
                audioPath: Value(audioPath),
                isDeleted: const Value(false),
                createdAt: Value(now),
                updatedAt: Value(now),
              ),
            );
            if (rememberBase) {
              await _listDao.rememberSharedImport(
                variantId,
                (await _conceptDao.getVariantById(variantId))!,
              );
            }
          }
        }
        await ids.save();
        return listId;
      });

      final imported = VocabularyList(
        id: listId,
        ownerId: _userId,
        name: name,
        description: description,
        wordCount: concepts.length,
        langA: langA,
        langB: langB,
        origin: origin,
        seedId: listSeedId,
        importedFromShareToken: shareToken,
        createdAt: now,
        updatedAt: now,
      );

      return Success(imported);
    } catch (e) {
      return Failure(StorageException(e.toString()));
    }
  }

  @override
  Future<Result<String>> generateShareLink(String listId) async {
    return _write(() async {
      final list = await _requireList(listId);
      final token = _uuid.v4().replaceAll('-', '');
      await _listDao.setShareToken(list.id, token, publish: true);
      return 'vocabkr://import?token=$token';
    });
  }

  @override
  Future<Result<VocabularyList>> importFromShareToken(String token) async {
    if (_userId.isEmpty) return const Failure(_accountRequired);
    // Return existing local copy if already imported (dedup by share token).
    final existing =
        await _listDao.getImportedCopy(token, _userId) ??
        await _listDao.getByShareToken(token, ownerId: _userId);
    if (existing != null) return Success(existing.toDomain());

    final remoteResult = await _remote.fetchPublicListByToken(token);
    if (remoteResult case Failure(:final exception)) return Failure(exception);
    final data = (remoteResult as Success).value;
    if (data == null) {
      return const Failure(NotFoundException('Shared list not found'));
    }

    final remoteConcepts =
        (data['concepts'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final conceptsJson = remoteConcepts
        .where((c) => c['is_deleted'] != true)
        .map((c) {
          final variants =
              (c['word_variants'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          return {
            'id': c['id'],
            'category': c['category'],
            'notes': c['notes'],
            'exampleFr': c['example_fr'],
            'exampleKo': c['example_ko'],
            'variants': variants
                .where((v) => v['is_deleted'] != true)
                .map(
                  (v) => {
                    'id': v['id'],
                    'word': v['word'],
                    'langCode': v['lang_code'],
                    'registerTag': v['register_tag'],
                    'contextTags': v['context_tags'],
                    'isPrimary': v['is_primary'],
                    'position': v['position'],
                    'example': v['example'],
                  },
                )
                .toList(),
          };
        })
        .toList();

    return _database.transaction(() async {
      final copy =
          await _listDao.getImportedCopy(token, _userId) ??
          await _listDao.getByShareToken(token, ownerId: _userId);
      if (copy != null) return Success(copy.toDomain());

      // A deliberate reimport after deletion gets a fresh deterministic
      // generation, keeping the deleted copy and its children untouched.
      var generation = 0;
      String idForGeneration() => _uuid.v5(
        Namespace.url.value,
        jsonEncode(['ponderin', 'share-import', _userId, token, generation]),
      );
      var listId = idForGeneration();
      final ids = await VocabularySyncIds.load(_database, _userId);
      while ((await _listDao.getById(
            ids.localId(SyncedVocabularyRow.list, listId),
          ))?.ownerId ==
          _userId) {
        generation++;
        listId = idForGeneration();
      }
      return _importFromJson(
        {
          'list': {
            'name': data['name'],
            'description': data['description'],
            'lang_a': data['lang_a'],
            'lang_b': data['lang_b'],
            'seed_id': data['seed_id'],
            'concepts': conceptsJson,
          },
        },
        sharedListId: listId,
        shareToken: token,
      );
    });
  }

  @override
  Future<void> syncFromRemote() {
    if (_userId.isEmpty) return Future.value();
    return _activeRestoration ??= _restore().whenComplete(() {
      _activeRestoration = null;
    });
  }

  Future<void> _restore() async {
    final budget = VocabularyNetworkBudget(_restoreTimeout);
    while (!await _restoreSlice(budget)) {}
    _starterIdentityReady = true;
  }

  /// A full walk and each catch-up window use the same budget in this attempt.
  /// SQLite records completed pages before requesting the next server fence.
  Future<bool> _restoreSlice(VocabularyNetworkBudget budget) async {
    // Capture the whole account before any remote I/O. A push can acknowledge
    // an edit between the request and response, leaving isSynced=true again.
    final (before, traversal) = await _database.transaction(() async {
      if (!_starterIdentityReady) {
        // A previous build may have created a random-ID starter before it
        // could pull. Keep its queued snapshot on the device until we know
        // whether the server already has a copy under another ID.
        for (final list in await _listDao.getStarterLists(_userId)) {
          if (await _listDao.isStarterEstablished(list.id)) continue;
          final held = await _listDao.isStarterDraftHeld(list.id);
          // Keep modern drafts held through real concurrent FSRS conflicts.
          // Older acknowledged starters no longer have a creation baseline.
          if (held && await _listDao.getSharedImportBase(list.id) != null) {
            continue;
          }
          if (list.isSynced || await _conceptDao.hasSyncedContents(list.id)) {
            await _listDao.establishStarterIdentity(list.id);
          } else if (!held) {
            await _listDao.holdStarterDraft(list.id);
          }
        }
      }
      return (
        await _snapshotForPull(),
        await _RestoreTraversal.load(_database, _userId),
      );
    });
    if (traversal.throughRevision == null || traversal.progressComplete) {
      final result = await _remote.fetchPullRevision(_userId, budget: budget);
      if (result.exceptionOrNull case final error?) throw error;
      final revision = result.valueOrNull!;
      final previous = traversal.throughRevision;
      if (previous == null) {
        traversal.throughRevision = revision;
      } else if (revision == previous) {
        await _database.transaction(() async {
          final ids = await VocabularySyncIds.load(_database, _userId);
          await StarterDraftReconciliation(_database).reconcile(
            _userId,
            [
              for (final list in traversal.catalog.values)
                list.copyWith(
                  id: ids.localId(SyncedVocabularyRow.list, list.id),
                ),
            ],
            conflictingProgressVariantIds:
                traversal.conflictingProgressVariantIds,
          );
          await traversal.clear(_database, _userId);
        });
        return true;
      } else if (revision < previous) {
        // An account reset can remove the journal. A new full walk is needed.
        await traversal.clear(_database, _userId);
        return false;
      } else {
        traversal.startCatchup(revision);
      }
    }
    final receivedLists = <String>{};
    final touchedLists = <String>{};
    final contents = <String, List<Map<String, dynamic>>>{};
    final completeContents = <String>{};
    AppException? incomplete;
    if (!traversal.listsComplete) {
      budget.resumeAfter(traversal.afterId, changes: traversal.changeWindow);
      final result = await _remote.fetchLists(_userId, budget: budget);
      final rows = result.valueOrNull ?? budget.takePartialRows();
      for (final map in rows) {
        final list = map.toVocabularyListDomain();
        if (list.ownerId != _userId) continue;
        traversal.recordList(list);
        receivedLists.add(list.id);
        touchedLists.add(list.id);
      }
      incomplete = result.exceptionOrNull;
      traversal.advancePage(rows, complete: incomplete == null);
      traversal.listsComplete = incomplete == null;
    }
    if (incomplete == null) {
      for (final list in traversal.lists.values.skip(traversal.contentsDone)) {
        if (list.isDeleted) {
          traversal.contentsDone++;
          continue;
        }
        budget.resumeAfter(traversal.afterId);
        final fetched = await _remote.fetchConcepts(
          list.id,
          ownerId: _userId,
          budget: budget,
        );
        final rows = fetched.valueOrNull ?? budget.takePartialRows();
        touchedLists.add(list.id);
        contents[list.id] = rows;
        incomplete = fetched.exceptionOrNull;
        traversal.advancePage(rows, complete: incomplete == null);
        if (incomplete != null) break;
        completeContents.add(list.id);
        traversal.contentsDone++;
      }
    }
    var progress = const <Map<String, dynamic>>[];
    if (incomplete == null) {
      budget.resumeAfter(traversal.afterId, changes: traversal.changeWindow);
      final received = await _remote.fetchProgress(_userId, budget: budget);
      incomplete = received.exceptionOrNull;
      progress = received.valueOrNull ?? budget.takePartialRows();
      traversal.advancePage(progress, complete: incomplete == null);
      traversal.progressComplete = incomplete == null;
    }

    await _database.transaction(() async {
      final current = await _snapshotForPull();
      final changed = _PullChanges(before, current);
      final ids = await VocabularySyncIds.load(_database, _userId);
      for (final wireListId in touchedLists) {
        final remoteList = traversal.lists[wireListId]!;
        final list = remoteList.copyWith(
          id: await ids.reserve(SyncedVocabularyRow.list, remoteList.id),
        );
        if (list.origin == 'starter' && list.seedId != null) {
          await _listDao.setStarterContentsPending(
            list.id,
            !list.isDeleted && !completeContents.contains(remoteList.id),
          );
          if (!await _listDao.isStarterDraftHeld(list.id)) {
            await _listDao.establishStarterIdentity(list.id);
          }
        }
        final localList = current.lists[list.id];
        final keepLocalList =
            localList != before.lists[list.id] ||
            (localList != null && !localList.isSynced && !list.isDeleted);
        if (list.isDeleted && changed.lists.contains(list.id)) {
          incomplete ??= _deferredDeletion;
          traversal.deletionDeferred = true;
          continue;
        }
        if (receivedLists.contains(wireListId) && !keepLocalList) {
          final missingContents =
              !list.isDeleted && !completeContents.contains(remoteList.id);
          final metadata = missingContents && localList != null
              ? list.copyWith(wordCount: localList.wordCount)
              : list;
          await _listDao.upsert(metadata.toLocalCompanion());
        } else if (localList == null || localList.isDeleted) {
          continue;
        }
        if (list.isDeleted) {
          await _listDao.forgetSharedImportBases([list.id]);
          await _conceptDao.tombstoneListContents(list.id, _userId);
          continue;
        }

        for (final raw
            in contents[remoteList.id] ?? const <Map<String, dynamic>>[]) {
          final conceptId = await ids.reserve(
            SyncedVocabularyRow.concept,
            raw['id'] as String,
          );
          final c = ids.decode(SyncedVocabularyRow.concept, raw);
          final localConcept = current.concepts[conceptId];
          final remoteConceptDeleted = c['is_deleted'] as bool? ?? false;
          final keepLocalConcept =
              localConcept != before.concepts[conceptId] ||
              (localConcept != null &&
                  !localConcept.isSynced &&
                  !remoteConceptDeleted);
          if (remoteConceptDeleted && changed.concepts.contains(conceptId)) {
            incomplete ??= _deferredDeletion;
            traversal.deletionDeferred = true;
            continue;
          }
          if (keepLocalConcept &&
              (localConcept == null || localConcept.isDeleted)) {
            continue;
          }
          if (!keepLocalConcept) {
            await _conceptDao.upsert(conceptCompanionFromRemote(c));
          }
          if (remoteConceptDeleted) {
            await _listDao.forgetSharedImportBases([conceptId]);
            await _conceptDao.tombstoneConceptContents([conceptId], _userId);
            continue;
          }
          final variants =
              (c['word_variants'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          for (final rawVariant in variants) {
            final variantId = await ids.reserve(
              SyncedVocabularyRow.variant,
              rawVariant['id'] as String,
            );
            final v = ids.decode(SyncedVocabularyRow.variant, rawVariant);
            final localVariant = current.variants[variantId];
            final remoteVariantDeleted = v['is_deleted'] as bool? ?? false;
            if (remoteVariantDeleted && changed.variants.contains(variantId)) {
              incomplete ??= _deferredDeletion;
              traversal.deletionDeferred = true;
              continue;
            }
            if (localVariant != before.variants[variantId] ||
                (localVariant != null &&
                    !localVariant.isSynced &&
                    !remoteVariantDeleted)) {
              continue;
            }
            await _conceptDao.upsertVariant(wordVariantCompanionFromRemote(v));
            if (remoteVariantDeleted) {
              await _listDao.forgetSharedImportBases([variantId]);
              await _database.progressDao.deleteProgressForVariants(
                userId: _userId,
                variantIds: [variantId],
              );
            }
          }
        }
        // The count follows the surviving concepts even when a pending rename
        // or other local edit prevents replacing the list metadata.
        if (completeContents.contains(remoteList.id)) {
          await _conceptDao.refreshListWordCount(list.id);
        }
      }

      // Apply progress after content so parent liveness reflects this pull.
      if (progress.isNotEmpty) {
        final progressDao = _database.progressDao;
        final liveVariantIds = await progressDao.getLiveVariantIds(_userId);
        final changedRows = <(String, String), VariantProgressTableData>{};
        for (final map in progress) {
          try {
            if (map['user_id'] != _userId ||
                !liveVariantIds.contains(
                  ids.localId(
                    SyncedVocabularyRow.variant,
                    map['variant_id'] as String,
                  ),
                )) {
              continue;
            }
            await ids.reserve(
              SyncedVocabularyRow.progress,
              map['id'] as String,
            );
            final row = variantProgressFromRemote(
              ids.decode(SyncedVocabularyRow.progress, map),
            );
            final key = (row.variantId, row.direction);
            final local = current.progress[key];
            if (local != null &&
                !local.isSynced &&
                local.copyWith(id: row.id, isSynced: true) != row) {
              traversal.conflictingProgressVariantIds.add(row.variantId);
            }
            if (local != before.progress[key] ||
                (local != null && !local.isSynced)) {
              continue;
            }
            if (row != local) changedRows[key] = row;
          } catch (_) {
            // Skip malformed rows and continue restoring the other cards.
          }
        }
        await progressDao.applyPulledProgress(changedRows.values.toList());
      }
      if (traversal.deletionDeferred) incomplete ??= _deferredDeletion;
      await ids.save();
      if (traversal.deletionDeferred && traversal.progressComplete) {
        // A later attempt starts over for the tombstone we deferred.
        await traversal.clear(_database, _userId);
      } else {
        await traversal.save(_database, _userId);
      }
    });
    if (incomplete case final error?) throw error;
    return false;
  }

  Future<_PullSnapshot> _snapshotForPull() async {
    final db = _database;
    final lists = db.vocabularyListsTable;
    final concepts = db.conceptsTable;
    final variants = db.wordVariantsTable;
    final progress = db.variantProgressTable;
    final conceptQuery = db.select(concepts).join([
      innerJoin(lists, lists.id.equalsExp(concepts.listId)),
    ])..where(lists.ownerId.equals(_userId));
    final variantQuery = db.select(variants).join([
      innerJoin(concepts, concepts.id.equalsExp(variants.conceptId)),
      innerJoin(lists, lists.id.equalsExp(concepts.listId)),
    ])..where(lists.ownerId.equals(_userId));
    return _PullSnapshot(
      {
        for (final row in await (db.select(
          lists,
        )..where((t) => t.ownerId.equals(_userId))).get())
          row.id: row,
      },
      {
        for (final row
            in await conceptQuery.map((r) => r.readTable(concepts)).get())
          row.id: row,
      },
      {
        for (final row
            in await variantQuery.map((r) => r.readTable(variants)).get())
          row.id: row,
      },
      {
        for (final row in await (db.select(
          progress,
        )..where((t) => t.userId.equals(_userId))).get())
          (row.variantId, row.direction): row,
      },
    );
  }

  Future<void> _updateWordCount(String listId, int delta) async {
    final row = await _listDao.getById(listId);
    if (row == null) return;
    final newCount = (row.wordCount + delta).clamp(0, 999999);
    await _listDao.updateWordCount(listId, newCount);
  }

  Future<Result<T>> _write<T>(Future<T> Function() write) async {
    if (_userId.isEmpty) return const Failure(_accountRequired);
    try {
      return Success(await _database.writeOutbound(_userId, write));
    } on AppException catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(StorageException(e.toString()));
    }
  }

  Future<VocabularyListsTableData?> _findList(String id) async {
    final canonicalId = await _listDao.resolveStarterId(
      StarterAliasKind.list,
      _userId,
      id,
    );
    final row = await _listDao.getById(canonicalId);
    if (row == null || row.ownerId != _userId || row.isDeleted) return null;
    return row;
  }

  Future<VocabularyListsTableData> _requireList(String id) async =>
      await _findList(id) ?? (throw const NotFoundException('List not found'));

  Future<ConceptsTableData> _requireConcept(String id) async {
    final canonicalId = await _listDao.resolveStarterId(
      StarterAliasKind.concept,
      _userId,
      id,
    );
    return _requireActiveConcept(canonicalId);
  }

  Future<ConceptsTableData> _requireActiveConcept(String id) async {
    final row = await _conceptDao.getById(id);
    if (row != null && !row.isDeleted) {
      final list = await _listDao.getById(row.listId);
      if (list != null && list.ownerId == _userId && !list.isDeleted) {
        return row;
      }
    }
    throw const NotFoundException('Concept not found');
  }

  Future<WordVariantsTableData> _requireVariant(String id) async {
    final canonicalId = await _listDao.resolveStarterId(
      StarterAliasKind.variant,
      _userId,
      id,
    );
    final row = await _conceptDao.getVariantById(canonicalId);
    if (row == null || row.isDeleted) {
      throw const NotFoundException('Variant not found');
    }
    await _requireActiveConcept(row.conceptId);
    return row;
  }
}

/// A committed account checkpoint makes paging resumable after a restart.
/// Each slice compares fresh remote rows against its own local CAS snapshot.
class _RestoreTraversal {
  _RestoreTraversal(Map<String, dynamic> stored)
    : lists = {
        for (final raw in stored['lists'] as List? ?? const [])
          raw['id'] as String: VocabularyList.fromJson(
            raw as Map<String, dynamic>,
          ),
      },
      conflictingProgressVariantIds = {
        ...(stored['progressConflicts'] as List? ?? const []).cast<String>(),
      },
      catalog = {
        for (final raw in stored['catalog'] as List? ?? const [])
          raw['id'] as String: VocabularyList.fromJson(
            raw as Map<String, dynamic>,
          ),
      },
      fromRevision = stored['fromRevision'] as int?,
      throughRevision = stored['throughRevision'] as int?,
      listsComplete = stored['listsComplete'] as bool? ?? false,
      contentsDone = stored['contentsDone'] as int? ?? 0,
      afterId = stored['afterId'] as String?,
      progressComplete = stored['progressComplete'] as bool? ?? false,
      deletionDeferred = stored['deletionDeferred'] as bool? ?? false;

  final Map<String, VocabularyList> lists;
  final Set<String> conflictingProgressVariantIds;
  final Map<String, VocabularyList> catalog;
  int? fromRevision;
  int? throughRevision;
  bool listsComplete;
  int contentsDone;
  String? afterId;
  bool progressComplete;
  bool deletionDeferred;

  VocabularyChangeWindow? get changeWindow => fromRevision == null
      ? null
      : (after: fromRevision!, through: throughRevision!);

  void recordList(VocabularyList list) {
    lists[list.id] = list;
    if (list.origin == 'starter' && list.seedId != null) {
      catalog[list.id] = list;
    } else {
      catalog.remove(list.id);
    }
  }

  void startCatchup(int revision) {
    fromRevision = throughRevision;
    throughRevision = revision;
    lists.clear();
    listsComplete = false;
    contentsDone = 0;
    afterId = null;
    progressComplete = false;
  }

  static String _key(String ownerId) => 'vocabulary-pull:$ownerId';

  static Future<_RestoreTraversal> load(AppDatabase db, String ownerId) async {
    final row = await db
        .customSelect(
          'SELECT snapshot FROM shared_import_bootstrap WHERE id = ?',
          variables: [Variable(_key(ownerId))],
        )
        .getSingleOrNull();
    if (row == null) return _RestoreTraversal({});
    try {
      final stored =
          jsonDecode(row.read<String>('snapshot')) as Map<String, dynamic>;
      return _RestoreTraversal(stored['throughRevision'] == null ? {} : stored);
    } on FormatException {
      return _RestoreTraversal({});
    } on TypeError {
      return _RestoreTraversal({});
    }
  }

  Future<void> save(AppDatabase db, String ownerId) async {
    final key = Variable(_key(ownerId));
    await db.customInsert(
      'INSERT INTO shared_import_bootstrap (id, snapshot) VALUES (?, ?) '
      'ON CONFLICT(id) DO UPDATE SET snapshot = excluded.snapshot',
      variables: [
        key,
        Variable(
          jsonEncode({
            'lists': lists.values.map((list) => list.toJson()).toList(),
            'catalog': catalog.values.map((list) => list.toJson()).toList(),
            'fromRevision': fromRevision,
            'throughRevision': throughRevision,
            'progressConflicts': conflictingProgressVariantIds.toList(),
            'listsComplete': listsComplete,
            'contentsDone': contentsDone,
            'afterId': afterId,
            'progressComplete': progressComplete,
            'deletionDeferred': deletionDeferred,
          }),
        ),
      ],
    );
  }

  Future<void> clear(AppDatabase db, String ownerId) async {
    await db.customUpdate(
      'DELETE FROM shared_import_bootstrap WHERE id = ?',
      variables: [Variable(_key(ownerId))],
    );
  }

  void advancePage(List<Map<String, dynamic>> rows, {required bool complete}) {
    if (complete) {
      afterId = null;
    } else if (rows.isNotEmpty) {
      afterId =
          (rows.last[VocabularyRemoteDataSource.pullRevisionKey] ??
                  rows.last['id'])
              as String;
    }
  }
}

class _PullSnapshot {
  const _PullSnapshot(this.lists, this.concepts, this.variants, this.progress);

  final Map<String, VocabularyListsTableData> lists;
  final Map<String, ConceptsTableData> concepts;
  final Map<String, WordVariantsTableData> variants;
  final Map<(String, String), VariantProgressTableData> progress;
}

/// A tombstone affects the whole subtree, so a change to any descendant
/// makes that tombstone stale for this pull.
class _PullChanges {
  _PullChanges(_PullSnapshot before, _PullSnapshot current) {
    for (final key in _changedKeys(before.progress, current.progress)) {
      variants.add(key.$1);
    }
    variants.addAll(_changedKeys(before.variants, current.variants));
    for (final id in variants) {
      final oldParent = before.variants[id]?.conceptId;
      final newParent = current.variants[id]?.conceptId;
      if (oldParent != null) concepts.add(oldParent);
      if (newParent != null) concepts.add(newParent);
    }
    concepts.addAll(_changedKeys(before.concepts, current.concepts));
    for (final id in concepts) {
      final oldParent = before.concepts[id]?.listId;
      final newParent = current.concepts[id]?.listId;
      if (oldParent != null) lists.add(oldParent);
      if (newParent != null) lists.add(newParent);
    }
    lists.addAll(_changedKeys(before.lists, current.lists));
  }

  final lists = <String>{};
  final concepts = <String>{};
  final variants = <String>{};

  static Iterable<K> _changedKeys<K, V>(Map<K, V> before, Map<K, V> current) =>
      {
        ...before.keys,
        ...current.keys,
      }.where((id) => before[id] != current[id]);
}
