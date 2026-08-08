import 'dart:async' show unawaited;
import 'dart:convert' show jsonEncode;
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
import '../models/variant_progress_dto.dart';
import '../models/vocabulary_list_dto.dart';
import '../models/word_variant_dto.dart';
import 'package:drift/drift.dart' show Value;

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
  Stream<List<VocabularyList>> watchMyLists() =>
      _listDao.watchByOwner(_userId).map((rows) => rows.map((r) => r.toDomain()).toList());

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
      unawaited(_remote.upsertList(list.toRemoteMap()));
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
      unawaited(_remote.upsertList(updated.toRemoteMap()));
      return Success(updated);
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
        await _database.progressDao.deleteProgressForVariants(
            userId: _userId, variantIds: variantIds);
      });
      unawaited(_remote.deleteList(listId));
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
    final row = await _listDao.getByShareToken(token);
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
    final frVariant = WordVariant(
      id: _uuid.v4(),
      conceptId: concept.id,
      word: wordA,
      langCode: langA,
      isPrimary: true,
      createdAt: now,
      updatedAt: now,
    );
    final koVariant = WordVariant(
      id: _uuid.v4(),
      conceptId: concept.id,
      word: wordB,
      langCode: langB,
      isPrimary: true,
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
      unawaited(_remote.upsertConcept(_conceptToRemote(concept)));
      unawaited(_remote.upsertVariant(_variantToRemote(frVariant)));
      unawaited(_remote.upsertVariant(_variantToRemote(koVariant)));
      return Success(concept);
    } catch (e) {
      return Failure(StorageException(e.toString()));
    }
  }

  @override
  Future<Result<Concept>> updateConcept(Concept concept) async {
    final updated = concept.copyWith(updatedAt: DateTime.now(), isSynced: false);
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
      unawaited(_remote.upsertConcept(_conceptToRemote(updated)));
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
        unawaited(_remote.upsertConcept({
          'id': conceptId,
          'list_id': row.listId,
          'is_deleted': true,
          'updated_at': DateTime.now().toIso8601String(),
        }));
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
    final variant = WordVariant(
      id: _uuid.v4(),
      conceptId: conceptId,
      word: word,
      langCode: langCode,
      registerTag: registerTag,
      isPrimary: isPrimary,
      createdAt: now,
      updatedAt: now,
    );
    try {
      await _conceptDao.upsertVariant(variant.toLocalCompanion());
      unawaited(_remote.upsertVariant(_variantToRemote(variant)));
      return Success(variant);
    } catch (e) {
      return Failure(StorageException(e.toString()));
    }
  }

  @override
  Future<Result<WordVariant>> updateVariant(WordVariant variant) async {
    final updated = variant.copyWith(updatedAt: DateTime.now(), isSynced: false);
    try {
      await _conceptDao.upsertVariant(updated.toLocalCompanion());
      unawaited(_remote.upsertVariant(_variantToRemote(updated)));
      return Success(updated);
    } catch (e) {
      return Failure(StorageException(e.toString()));
    }
  }

  @override
  Future<Result<void>> deleteVariant(String variantId) async {
    try {
      await _conceptDao.softDeleteVariant(variantId);
      unawaited(_remote.upsertVariant({
        'id': variantId,
        'is_deleted': true,
        'updated_at': DateTime.now().toIso8601String(),
      }));
      return const Success(null);
    } catch (e) {
      return Failure(StorageException(e.toString()));
    }
  }

  @override
  Future<Result<Map<String, dynamic>>> exportToJson(String listId) async {
    try {
      final listRow = await _listDao.getById(listId);
      if (listRow == null) return const Failure(NotFoundException('List not found'));

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
                    'isPrimary': v.isPrimary,
                    'position': v.position,
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
      {String origin = 'user'}) async {
    try {
      final listData = json['list'] as Map<String, dynamic>?;
      if (listData == null) {
        return const Failure(ValidationException('Invalid export format'));
      }

      final now = DateTime.now();
      final listId = _uuid.v4();
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
          isSynced: const Value(false),
          isDeleted: const Value(false),
          createdAt: Value(now),
          updatedAt: Value(now),
        ));

        for (final cData in concepts) {
          final conceptId = _uuid.v4();
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

          final variants =
              (_field<List>(cData, 'variants', 'word_variants'))
                      ?.cast<Map<String, dynamic>>() ??
                  [];
          for (final vData in variants) {
            await _conceptDao.upsertVariant(WordVariantsTableCompanion(
              id: Value(_uuid.v4()),
              conceptId: Value(conceptId),
              word: Value(vData['word'] as String? ?? ''),
              langCode:
                  Value(_field<String>(vData, 'langCode', 'lang_code') ?? langA),
              registerTag: Value(
                  _field<String>(vData, 'registerTag', 'register_tag') ??
                      'neutral'),
              contextTags: Value(jsonEncode(
                  _field<List>(vData, 'contextTags', 'context_tags') ??
                      const [])),
              isPrimary:
                  Value(_field<bool>(vData, 'isPrimary', 'is_primary') ?? false),
              position: Value(vData['position'] as int? ?? 0),
              example: Value(vData['example'] as String?),
              isDeleted: const Value(false),
              createdAt: Value(now),
              updatedAt: Value(now),
            ));
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
        createdAt: now,
        updatedAt: now,
      );

      unawaited(_remote.upsertList(imported.toRemoteMap()));
      return Success(imported);
    } catch (e) {
      return Failure(StorageException(e.toString()));
    }
  }

  @override
  Future<Result<String>> generateShareLink(String listId) async {
    try {
      final token = _uuid.v4().replaceAll('-', '');
      await _listDao.setShareToken(listId, token);
      unawaited(_remote.upsertList({
        'id': listId,
        'share_token': token,
        'visibility': 'public',
        'updated_at': DateTime.now().toIso8601String(),
      }));
      return Success('vocabkr://import?token=$token');
    } catch (e) {
      return Failure(StorageException(e.toString()));
    }
  }

  @override
  Future<Result<VocabularyList>> importFromShareToken(String token) async {
    // Return existing local copy if already imported (dedup by share token).
    final existing = await _listDao.getByShareToken(token);
    if (existing != null) return Success(existing.toDomain());

    final remoteResult = await _remote.fetchPublicListByToken(token);
    if (remoteResult case Failure(:final exception)) return Failure(exception);
    final data = (remoteResult as Success).value;
    if (data == null) return const Failure(NotFoundException('Shared list not found'));

    final remoteConcepts = (data['concepts'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final conceptsJson = remoteConcepts.map((c) {
      final variants = (c['word_variants'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      return {
        'category': c['category'],
        'notes': c['notes'],
        'exampleFr': c['example_fr'],
        'exampleKo': c['example_ko'],
        'variants': variants.map((v) => {
          'word': v['word'],
          'langCode': v['lang_code'],
          'registerTag': v['register_tag'],
          'isPrimary': v['is_primary'],
          'position': v['position'],
        }).toList(),
      };
    }).toList();

    final importResult = await importFromJson({
      'list': {
        'name': data['name'],
        'description': data['description'],
        'concepts': conceptsJson,
      },
    });

    if (importResult case Success(:final value)) {
      // Tag the imported list with the share token for future dedup.
      unawaited(_listDao.setShareToken(value.id, token));
    }
    return importResult;
  }

  @override
  Future<void> syncFromRemote() async {
    if (_userId.isEmpty) return;
    final result = await _remote.fetchLists(_userId);
    if (result case Success(:final value)) {
      for (final map in value) {
        final list = map.toVocabularyListDomain();
        await _listDao.upsert(list.toLocalCompanion());
        // Tombstone: the upsert above marks the local copy deleted; its
        // contents no longer matter.
        if (list.isDeleted) continue;

        final conceptsResult = await _remote.fetchConcepts(list.id);
        if (conceptsResult case Success(:final value)) {
          for (final c in value) {
            await _conceptDao.upsert(ConceptsTableCompanion(
              id: Value(c['id'] as String),
              listId: Value(c['list_id'] as String),
              category: Value(c['category'] as String?),
              notes: Value(c['notes'] as String?),
              imageUrl: Value(c['image_url'] as String?),
              exampleFr: Value(c['example_fr'] as String?),
              exampleKo: Value(c['example_ko'] as String?),
              seedId: Value(c['seed_id'] as String?),
              isDeleted: Value(c['is_deleted'] as bool? ?? false),
              isSynced: const Value(true),
              createdAt: Value(DateTime.parse(c['created_at'] as String)),
              updatedAt: Value(DateTime.parse(c['updated_at'] as String)),
            ));
            final variants = (c['word_variants'] as List?)
                    ?.cast<Map<String, dynamic>>() ??
                [];
            for (final v in variants) {
              await _conceptDao.upsertVariant(WordVariantsTableCompanion(
                id: Value(v['id'] as String),
                conceptId: Value(v['concept_id'] as String),
                word: Value(v['word'] as String? ?? ''),
                langCode: Value(v['lang_code'] as String? ?? 'fr'),
                registerTag:
                    Value(v['register_tag'] as String? ?? 'neutral'),
                contextTags:
                    Value(jsonEncode(v['context_tags'] as List? ?? const [])),
                isPrimary: Value(v['is_primary'] as bool? ?? false),
                position: Value(v['position'] as int? ?? 0),
                example: Value(v['example'] as String?),
                isDeleted: Value(v['is_deleted'] as bool? ?? false),
                isSynced: const Value(true),
                createdAt:
                    Value(DateTime.parse(v['created_at'] as String)),
                updatedAt:
                    Value(DateTime.parse(v['updated_at'] as String)),
              ));
            }
          }
        }
        // Recount from actual non-deleted rows so the stored wordCount
        // is always authoritative, regardless of what the remote sent.
        final actualCount = await _conceptDao.countByList(list.id);
        await _listDao.updateWordCount(list.id, actualCount);
      }
    }

    // Progress comes down AFTER content so its variant rows exist locally.
    // A local row still marked unsynced is a pending outbound write — newer
    // than anything the server has — so the remote copy must not clobber it.
    // Per-row failures are skipped: one malformed row can't abort restoring
    // the rest.
    final progressResult = await _remote.fetchProgress(_userId);
    if (progressResult case Success(:final value)) {
      final progressDao = _database.progressDao;
      for (final map in value) {
        try {
          final local = await progressDao.getById(map['id'] as String);
          if (local != null && !local.isSynced) continue;
          await progressDao.upsert(variantProgressCompanionFromRemote(map));
        } catch (_) {}
      }
    }
  }

  Future<void> _updateWordCount(String listId, int delta) async {
    final row = await _listDao.getById(listId);
    if (row == null) return;
    final newCount = (row.wordCount + delta).clamp(0, 999999);
    await _listDao.updateWordCount(listId, newCount);
    unawaited(_remote.upsertList({
      'id': listId,
      'word_count': newCount,
      'updated_at': DateTime.now().toIso8601String(),
    }));
  }

  static Map<String, dynamic> _conceptToRemote(Concept c) => {
        'id': c.id,
        'list_id': c.listId,
        'category': c.category,
        'notes': c.notes,
        'image_url': c.imageUrl,
        'example_fr': c.exampleFr,
        'example_ko': c.exampleKo,
        'seed_id': c.seedId,
        'is_deleted': c.isDeleted,
        'created_at': c.createdAt.toIso8601String(),
        'updated_at': c.updatedAt.toIso8601String(),
      };

  static Map<String, dynamic> _variantToRemote(WordVariant v) => {
        'id': v.id,
        'concept_id': v.conceptId,
        'word': v.word,
        'lang_code': v.langCode,
        'register_tag': v.registerTag,
        'context_tags': v.contextTags,
        'is_primary': v.isPrimary,
        'position': v.position,
        'example': v.example,
        'is_deleted': v.isDeleted,
        'created_at': v.createdAt.toIso8601String(),
        'updated_at': v.updatedAt.toIso8601String(),
      };
}
