import 'dart:convert' show jsonDecode, jsonEncode;
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
import '../../services/audio/audio_asset_path.dart';
import 'package:drift/drift.dart' show Value, innerJoin;

const _uuid = Uuid();

class VocabularyRepositoryImpl implements VocabularyRepository {
  VocabularyRepositoryImpl(
    this._listDao,
    this._conceptDao,
    this._remote,
    this._userId,
    this._database,
  );

  final VocabularyListDao _listDao;
  final ConceptDao _conceptDao;
  final VocabularyRemoteDataSource _remote;
  final String _userId;
  final AppDatabase _database;

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
      await _listDao.upsert(list.toLocalCompanion());
      return Success(list);
    } catch (e) {
      return Failure(StorageException(e.toString()));
    }
  }

  @override
  Future<Result<VocabularyList>> updateList(VocabularyList list) async {
    final updated = list.copyWith(updatedAt: DateTime.now(), isSynced: false);
    try {
      await _listDao.upsert(updated.toLocalCompanion());
      return Success(updated);
    } catch (e) {
      return Failure(StorageException(e.toString()));
    }
  }

  @override
  Future<Result<VocabularyList>> renameList(String listId, String name) async {
    try {
      return await _database.transaction(() async {
        final current = await _listDao.getById(listId);
        if (current == null ||
            current.ownerId != _userId ||
            current.isDeleted) {
          return const Failure(NotFoundException('List not found'));
        }
        return updateList(current.toDomain().copyWith(name: name));
      });
    } catch (e) {
      return Failure(StorageException(e.toString()));
    }
  }

  @override
  Future<Result<void>> deleteList(String listId) async {
    try {
      // Deleting a list frees a quota slot but the user LOSES its mastery
      // (product decision 2026-07-04): soft-delete the words so they vanish
      // from smart lists, and delete their progress rows outright.
      final concepts = await _conceptDao.getConceptsByList(listId);
      final conceptIds = concepts.map((c) => c.id).toList();
      final variantIds =
          await _database.progressDao.getVariantIdsForConcepts(conceptIds);
      await _database.transaction(() async {
        await _listDao.softDelete(listId);
        for (final id in conceptIds) {
          await _conceptDao.softDelete(id);
        }
        for (final id in variantIds) {
          await _conceptDao.softDeleteVariant(id);
        }
        await _database.progressDao
            .deleteProgressForVariants(userId: _userId, variantIds: variantIds);
      });
      return const Success(null);
    } catch (e) {
      return Failure(StorageException(e.toString()));
    }
  }

  @override
  Future<Result<VocabularyList>> getListById(String listId) async {
    final row = await _listDao.getById(listId);
    if (row == null) return const Failure(NotFoundException('List not found'));
    return Success(row.toDomain());
  }

  @override
  Future<Result<VocabularyList?>> getListByShareToken(String token) async {
    final row = await _listDao.getByShareToken(token, ownerId: _userId);
    return Success(row?.toDomain());
  }

  @override
  Stream<List<Concept>> watchConcepts(String listId) =>
      _conceptDao.watchByList(listId).map((rows) => rows
          .map((r) => Concept(
                id: r.id,
                listId: r.listId,
                category: r.category,
                notes: r.notes,
                imageUrl: r.imageUrl,
                exampleFr: r.exampleFr,
                exampleKo: r.exampleKo,
                createdAt: r.createdAt,
                updatedAt: r.updatedAt,
              ))
          .toList());

  @override
  Future<Result<Concept>> createConcept({
    required String listId,
    String? category,
    String? notes,
    String? exampleFr,
    String? exampleKo,
  }) async {
    final now = DateTime.now();
    final concept = Concept(
      id: _uuid.v4(),
      listId: listId,
      category: category,
      notes: notes,
      exampleFr: exampleFr,
      exampleKo: exampleKo,
      createdAt: now,
      updatedAt: now,
    );
    try {
      await _conceptDao.upsert(ConceptsTableCompanion(
        id: Value(concept.id),
        listId: Value(concept.listId),
        category: Value(concept.category),
        notes: Value(concept.notes),
        imageUrl: Value(concept.imageUrl),
        exampleFr: Value(concept.exampleFr),
        exampleKo: Value(concept.exampleKo),
        createdAt: Value(concept.createdAt),
        updatedAt: Value(concept.updatedAt),
      ));
      await _updateWordCount(listId, 1);
      return Success(concept);
    } catch (e) {
      return Failure(StorageException(e.toString()));
    }
  }

  @override
  Future<Result<Concept>> addConceptWithVariants({
    required String listId,
    required String wordA,
    required String wordB,
    String langA = 'fr',
    String langB = 'ko',
    String? notes,
    String? category,
  }) async {
    final now = DateTime.now();
    final concept = Concept(
      id: _uuid.v4(),
      listId: listId,
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
          langCode: langA),
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
          langCode: langB),
      createdAt: now,
      updatedAt: now,
    );
    try {
      await _database.transaction(() async {
        await _conceptDao.upsert(ConceptsTableCompanion(
          id: Value(concept.id),
          listId: Value(concept.listId),
          category: Value(concept.category),
          notes: Value(concept.notes),
          imageUrl: Value(concept.imageUrl),
          exampleFr: Value(concept.exampleFr),
          exampleKo: Value(concept.exampleKo),
          createdAt: Value(concept.createdAt),
          updatedAt: Value(concept.updatedAt),
        ));
        await _conceptDao.upsertVariant(frVariant.toLocalCompanion());
        await _conceptDao.upsertVariant(koVariant.toLocalCompanion());
      });
      await _updateWordCount(listId, 1);
      return Success(concept);
    } catch (e) {
      return Failure(StorageException(e.toString()));
    }
  }

  @override
  Future<Result<Concept>> updateConcept(Concept concept) async {
    final updated =
        concept.copyWith(updatedAt: DateTime.now(), isSynced: false);
    try {
      await _conceptDao.upsert(ConceptsTableCompanion(
        id: Value(updated.id),
        listId: Value(updated.listId),
        category: Value(updated.category),
        notes: Value(updated.notes),
        imageUrl: Value(updated.imageUrl),
        exampleFr: Value(updated.exampleFr),
        exampleKo: Value(updated.exampleKo),
        isSynced: Value(false),
        createdAt: Value(updated.createdAt),
        updatedAt: Value(updated.updatedAt),
      ));
      return Success(updated);
    } catch (e) {
      return Failure(StorageException(e.toString()));
    }
  }

  @override
  Future<Result<void>> deleteConcept(String conceptId) async {
    try {
      final row = await _conceptDao.getById(conceptId);
      await _conceptDao.softDelete(conceptId);
      if (row != null) {
        await _updateWordCount(row.listId, -1);
      }
      return const Success(null);
    } catch (e) {
      return Failure(StorageException(e.toString()));
    }
  }

  @override
  Future<Result<List<WordVariant>>> getVariants(String conceptId) async {
    try {
      final rows = await _conceptDao.getVariantsByConcept(conceptId);
      return Success(rows.map((r) => r.toDomain()).toList());
    } catch (e) {
      return Failure(StorageException(e.toString()));
    }
  }

  @override
  Future<Result<WordVariant>> createVariant({
    required String conceptId,
    required String word,
    required String langCode,
    String registerTag = 'neutral',
    bool isPrimary = false,
  }) async {
    final now = DateTime.now();
    final variantId = _uuid.v4();
    final variant = WordVariant(
      id: variantId,
      conceptId: conceptId,
      word: word,
      langCode: langCode,
      registerTag: registerTag,
      isPrimary: isPrimary,
      audioPath: AudioAssetPath.user(
          userId: _userId,
          variantId: variantId,
          text: word,
          langCode: langCode),
      createdAt: now,
      updatedAt: now,
    );
    try {
      await _conceptDao.upsertVariant(variant.toLocalCompanion());
      return Success(variant);
    } catch (e) {
      return Failure(StorageException(e.toString()));
    }
  }

  @override
  Future<Result<WordVariant>> updateVariant(WordVariant variant) async {
    final updated = variant.copyWith(
      audioPath: AudioAssetPath.user(
          userId: _userId,
          variantId: variant.id,
          text: variant.word,
          langCode: variant.langCode),
      updatedAt: DateTime.now(),
      isSynced: false,
    );
    try {
      await _conceptDao.upsertVariant(updated.toLocalCompanion());
      return Success(updated);
    } catch (e) {
      return Failure(StorageException(e.toString()));
    }
  }

  @override
  Future<Result<void>> deleteVariant(String variantId) async {
    try {
      await _conceptDao.softDeleteVariant(variantId);
      return const Success(null);
    } catch (e) {
      return Failure(StorageException(e.toString()));
    }
  }

  @override
  Future<Result<Map<String, dynamic>>> exportToJson(String listId) async {
    try {
      final listRow = await _listDao.getById(listId);
      if (listRow == null) {
        return const Failure(NotFoundException('List not found'));
      }

      final concepts = await _conceptDao.getConceptsByList(listId);
      final conceptsJson = <Map<String, dynamic>>[];

      for (final c in concepts) {
        final variants = await _conceptDao.getVariantsByConcept(c.id);
        conceptsJson.add({
          'category': c.category,
          'notes': c.notes,
          'exampleFr': c.exampleFr,
          'exampleKo': c.exampleKo,
          'variants': variants
              .map((v) => {
                    'word': v.word,
                    'langCode': v.langCode,
                    'registerTag': v.registerTag,
                    'contextTags': jsonDecode(v.contextTags),
                    'isPrimary': v.isPrimary,
                    'position': v.position,
                    'example': v.example,
                  })
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
  Future<Result<VocabularyList>> importFromJson(Map<String, dynamic> json,
          {String origin = 'user'}) =>
      _importFromJson(json, origin: origin);

  Future<Result<VocabularyList>> _importFromJson(Map<String, dynamic> json,
      {String origin = 'user',
      String? sharedListId,
      String? shareToken}) async {
    try {
      final listData = json['list'] as Map<String, dynamic>?;
      if (listData == null) {
        return const Failure(ValidationException('Invalid export format'));
      }

      final now = DateTime.now();
      final listId = sharedListId ?? _uuid.v4();
      final name = listData['name'] as String? ?? 'Imported List';
      final description = listData['description'] as String?;
      final langA = _field<String>(listData, 'langA', 'lang_a') ?? 'fr';
      final langB = _field<String>(listData, 'langB', 'lang_b') ?? 'ko';
      final listSeedId = _field<String>(listData, 'seedId', 'seed_id');
      final concepts =
          (listData['concepts'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      // Atomic: if any concept/variant insert fails the whole import rolls back.
      await _database.transaction(() async {
        await _listDao.upsert(VocabularyListsTableCompanion(
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
        ));
        if (sharedListId != null) {
          await _listDao.rememberSharedImport(
              listId, (await _listDao.getById(listId))!);
        }

        for (final (index, cData) in concepts.indexed) {
          final conceptId = sharedListId == null
              ? _uuid.v4()
              : _uuid.v5(listId, jsonEncode(['concept', cData['id'] ?? index]));
          await _conceptDao.upsert(ConceptsTableCompanion(
            id: Value(conceptId),
            listId: Value(listId),
            category: Value(cData['category'] as String?),
            notes: Value(cData['notes'] as String?),
            exampleFr: Value(_field<String>(cData, 'exampleFr', 'example_fr')),
            exampleKo: Value(_field<String>(cData, 'exampleKo', 'example_ko')),
            seedId: Value(_field<String>(cData, 'seedId', 'seed_id')),
            isDeleted: const Value(false),
            createdAt: Value(now),
            updatedAt: Value(now),
          ));
          if (sharedListId != null) {
            await _listDao.rememberSharedImport(
                conceptId, (await _conceptDao.getById(conceptId))!);
          }

          final variants = (_field<List>(cData, 'variants', 'word_variants'))
                  ?.cast<Map<String, dynamic>>() ??
              [];
          for (final (index, vData) in variants.indexed) {
            final variantId = sharedListId == null
                ? _uuid.v4()
                : _uuid.v5(
                    conceptId, jsonEncode(['variant', vData['id'] ?? index]));
            final word = vData['word'] as String? ?? '';
            final langCode =
                _field<String>(vData, 'langCode', 'lang_code') ?? langA;
            final audioPath = origin == 'starter'
                ? AudioAssetPath.seed(text: word, langCode: langCode)
                : AudioAssetPath.user(
                    userId: _userId,
                    variantId: variantId,
                    text: word,
                    langCode: langCode);
            await _conceptDao.upsertVariant(WordVariantsTableCompanion(
              id: Value(variantId),
              conceptId: Value(conceptId),
              word: Value(word),
              langCode: Value(langCode),
              registerTag: Value(
                  _field<String>(vData, 'registerTag', 'register_tag') ??
                      'neutral'),
              contextTags: Value(jsonEncode(
                  _field<List>(vData, 'contextTags', 'context_tags') ??
                      const [])),
              isPrimary: Value(
                  _field<bool>(vData, 'isPrimary', 'is_primary') ?? false),
              position: Value(vData['position'] as int? ?? 0),
              example: Value(vData['example'] as String?),
              audioPath: Value(audioPath),
              isDeleted: const Value(false),
              createdAt: Value(now),
              updatedAt: Value(now),
            ));
            if (sharedListId != null) {
              await _listDao.rememberSharedImport(
                  variantId, (await _conceptDao.getVariantById(variantId))!);
            }
          }
        }
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
    try {
      final token = _uuid.v4().replaceAll('-', '');
      await _listDao.setShareToken(listId, token, publish: true);
      return Success('vocabkr://import?token=$token');
    } catch (e) {
      return Failure(StorageException(e.toString()));
    }
  }

  @override
  Future<Result<VocabularyList>> importFromShareToken(String token) async {
    // Return existing local copy if already imported (dedup by share token).
    final existing = await _listDao.getImportedCopy(token, _userId) ??
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
    final conceptsJson =
        remoteConcepts.where((c) => c['is_deleted'] != true).map((c) {
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
            .map((v) => {
                  'id': v['id'],
                  'word': v['word'],
                  'langCode': v['lang_code'],
                  'registerTag': v['register_tag'],
                  'contextTags': v['context_tags'],
                  'isPrimary': v['is_primary'],
                  'position': v['position'],
                  'example': v['example'],
                })
            .toList(),
      };
    }).toList();

    return _database.transaction(() async {
      final copy = await _listDao.getImportedCopy(token, _userId) ??
          await _listDao.getByShareToken(token, ownerId: _userId);
      if (copy != null) return Success(copy.toDomain());

      // A deliberate reimport after deletion gets a fresh deterministic
      // generation, keeping the deleted copy and its children untouched.
      var generation = 0;
      String idForGeneration() => _uuid.v5(Namespace.url.value,
          jsonEncode(['ponderin', 'share-import', _userId, token, generation]));
      var listId = idForGeneration();
      while (await _listDao.getById(listId) != null) {
        generation++;
        listId = idForGeneration();
      }
      return _importFromJson({
        'list': {
          'name': data['name'],
          'description': data['description'],
          'lang_a': data['lang_a'],
          'lang_b': data['lang_b'],
          'seed_id': data['seed_id'],
          'concepts': conceptsJson,
        },
      }, sharedListId: listId, shareToken: token);
    });
  }

  @override
  Future<void> syncFromRemote() async {
    if (_userId.isEmpty) return;
    // Capture the whole account before any remote I/O. A push can acknowledge
    // an edit between the request and response, leaving isSynced=true again.
    final before = await _database.transaction(_snapshotForPull);
    final lists = <VocabularyList>[];
    final contents = <String, List<Map<String, dynamic>>>{};
    final result = await _remote.fetchLists(_userId);
    if (result case Success(:final value)) {
      for (final map in value) {
        final list = map.toVocabularyListDomain();
        if (list.ownerId != _userId) continue;
        lists.add(list);
        if (list.isDeleted) continue;
        final concepts = await _remote.fetchConcepts(list.id);
        if (concepts case Success(:final value)) contents[list.id] = value;
      }
    }
    final progress = await _remote.fetchProgress(_userId);

    await _database.transaction(() async {
      final current = await _snapshotForPull();
      final changed = _PullChanges(before, current);
      for (final list in lists) {
        final localList = current.lists[list.id];
        final keepLocalList = localList != before.lists[list.id] ||
            (localList != null && !localList.isSynced && !list.isDeleted);
        if (list.isDeleted && changed.lists.contains(list.id)) continue;
        if (!keepLocalList) {
          await _listDao.upsert(list.toLocalCompanion());
        } else if (localList == null || localList.isDeleted) {
          continue;
        }
        if (list.isDeleted) {
          await _listDao.forgetSharedImportBases([list.id]);
          await _conceptDao.tombstoneListContents(list.id, _userId);
          continue;
        }

        for (final c in contents[list.id] ?? const <Map<String, dynamic>>[]) {
          final conceptId = c['id'] as String;
          final localConcept = current.concepts[conceptId];
          final remoteConceptDeleted = c['is_deleted'] as bool? ?? false;
          final keepLocalConcept = localConcept != before.concepts[conceptId] ||
              (localConcept != null &&
                  !localConcept.isSynced &&
                  !remoteConceptDeleted);
          if (remoteConceptDeleted && changed.concepts.contains(conceptId)) {
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
          for (final v in variants) {
            final variantId = v['id'] as String;
            final localVariant = current.variants[variantId];
            final remoteVariantDeleted = v['is_deleted'] as bool? ?? false;
            if (localVariant != before.variants[variantId] ||
                (localVariant != null &&
                    !localVariant.isSynced &&
                    !remoteVariantDeleted) ||
                (remoteVariantDeleted &&
                    changed.variants.contains(variantId))) {
              continue;
            }
            await _conceptDao.upsertVariant(wordVariantCompanionFromRemote(v));
            if (remoteVariantDeleted) {
              await _listDao.forgetSharedImportBases([variantId]);
              await _database.progressDao.deleteProgressForVariants(
                  userId: _userId, variantIds: [variantId]);
            }
          }
        }
        // Recount from actual non-deleted rows so the stored wordCount
        // is always authoritative, regardless of what the remote sent.
        final actualCount = await _conceptDao.countByList(list.id);
        if (!keepLocalList) {
          await _listDao.refreshWordCount(list.id, actualCount);
        }
      }

      // Apply progress after content so parent liveness reflects this pull.
      if (progress case Success(:final value) when value.isNotEmpty) {
        final progressDao = _database.progressDao;
        final liveVariantIds = await progressDao.getLiveVariantIds(_userId);
        final changedRows = <(String, String), VariantProgressTableData>{};
        for (final map in value) {
          try {
            final row = variantProgressFromRemote(map);
            if (row.userId != _userId ||
                !liveVariantIds.contains(row.variantId)) {
              continue;
            }
            final key = (row.variantId, row.direction);
            final local = current.progress[key];
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
    });
  }

  Future<_PullSnapshot> _snapshotForPull() async {
    final db = _database;
    final lists = db.vocabularyListsTable;
    final concepts = db.conceptsTable;
    final variants = db.wordVariantsTable;
    final progress = db.variantProgressTable;
    final conceptQuery = db.select(concepts).join([
      innerJoin(lists, lists.id.equalsExp(concepts.listId)),
    ])
      ..where(lists.ownerId.equals(_userId));
    final variantQuery = db.select(variants).join([
      innerJoin(concepts, concepts.id.equalsExp(variants.conceptId)),
      innerJoin(lists, lists.id.equalsExp(concepts.listId)),
    ])
      ..where(lists.ownerId.equals(_userId));
    return _PullSnapshot(
      {
        for (final row in await (db.select(lists)
              ..where((t) => t.ownerId.equals(_userId)))
            .get())
          row.id: row
      },
      {
        for (final row
            in await conceptQuery.map((r) => r.readTable(concepts)).get())
          row.id: row
      },
      {
        for (final row
            in await variantQuery.map((r) => r.readTable(variants)).get())
          row.id: row
      },
      {
        for (final row in await (db.select(progress)
              ..where((t) => t.userId.equals(_userId)))
            .get())
          (row.variantId, row.direction): row
      },
    );
  }

  Future<void> _updateWordCount(String listId, int delta) async {
    final row = await _listDao.getById(listId);
    if (row == null) return;
    final newCount = (row.wordCount + delta).clamp(0, 999999);
    await _listDao.updateWordCount(listId, newCount);
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
      {...before.keys, ...current.keys}
          .where((id) => before[id] != current[id]);
}
