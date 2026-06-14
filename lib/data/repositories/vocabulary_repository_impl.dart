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
  VocabularyRepositoryImpl(this._listDao, this._conceptDao, this._remote, this._userId);

  final VocabularyListDao _listDao;
  final ConceptDao _conceptDao;
  final VocabularyRemoteDataSource _remote;
  final String _userId;

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
      _remote.upsertList(list.toRemoteMap()); // fire-and-forget
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
      _remote.upsertList(updated.toRemoteMap());
      return Success(updated);
    } catch (e) {
      return Failure(StorageException(e.toString()));
    }
  }

  @override
  Future<Result<void>> deleteList(String listId) async {
    try {
      await _listDao.softDelete(listId);
      _remote.deleteList(listId);
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
      await _conceptDao.softDelete(conceptId);
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
  Future<Result<VocabularyList>> importFromJson(Map<String, dynamic> json) async {
    // Basic import — full implementation in Phase 7
    return const Failure(UnknownException('Import not yet implemented'));
  }

  @override
  Future<Result<Map<String, dynamic>>> exportToJson(String listId) async {
    return const Failure(UnknownException('Export not yet implemented'));
  }

  @override
  Future<Result<String>> generateShareLink(String listId) async {
    return const Failure(UnknownException('Share link not yet implemented'));
  }
}
