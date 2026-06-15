import 'dart:async' show unawaited;
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
  }) async {
    final now = DateTime.now();
    final list = VocabularyList(
      id: _uuid.v4(),
      ownerId: _userId,
      name: name,
      description: description,
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
      await _listDao.softDelete(listId);
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
      unawaited(_updateWordCount(listId, 1));
      return Success(concept);
    } catch (e) {
      return Failure(StorageException(e.toString()));
    }
  }

  @override
  Future<Result<Concept>> addConceptWithVariants({
    required String listId,
    required String frWord,
    required String koWord,
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
      word: frWord,
      langCode: 'fr',
      isPrimary: true,
      createdAt: now,
      updatedAt: now,
    );
    final koVariant = WordVariant(
      id: _uuid.v4(),
      conceptId: concept.id,
      word: koWord,
      langCode: 'ko',
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
      print('[addConceptWithVariants] committed conceptId=${concept.id} frId=${frVariant.id} koId=${koVariant.id} listId=$listId');
      unawaited(_updateWordCount(listId, 1));
      return Success(concept);
    } catch (e) {
      print('[addConceptWithVariants] FAILED: $e');
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
      if (row != null) unawaited(_updateWordCount(row.listId, -1));
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

  @override
  Future<Result<VocabularyList>> importFromJson(Map<String, dynamic> json) async {
    try {
      final listData = json['list'] as Map<String, dynamic>?;
      if (listData == null) {
        return const Failure(ValidationException('Invalid export format'));
      }

      final now = DateTime.now();
      final listId = _uuid.v4();
      final name = listData['name'] as String? ?? 'Imported List';
      final description = listData['description'] as String?;
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
            exampleFr: Value(cData['exampleFr'] as String?),
            exampleKo: Value(cData['exampleKo'] as String?),
            isDeleted: const Value(false),
            createdAt: Value(now),
            updatedAt: Value(now),
          ));

          final variants =
              (cData['variants'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          for (final vData in variants) {
            await _conceptDao.upsertVariant(WordVariantsTableCompanion(
              id: Value(_uuid.v4()),
              conceptId: Value(conceptId),
              word: Value(vData['word'] as String? ?? ''),
              langCode: Value(vData['langCode'] as String? ?? 'fr'),
              registerTag: Value(vData['registerTag'] as String? ?? 'neutral'),
              isPrimary: Value(vData['isPrimary'] as bool? ?? false),
              position: Value(vData['position'] as int? ?? 0),
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
}
