import '../../repositories/vocabulary_repository.dart';
import '../../entities/vocabulary_list.dart';
import '../../../core/errors/failure.dart';

class ExportListUseCase {
  const ExportListUseCase(this._repo);
  final VocabularyRepository _repo;

  Future<Result<Map<String, dynamic>>> call(String listId) =>
      _repo.exportToJson(listId);
}

class ImportListUseCase {
  const ImportListUseCase(this._repo);
  final VocabularyRepository _repo;

  Future<Result<VocabularyList>> call(Map<String, dynamic> json) =>
      _repo.importFromJson(json);
}

class GenerateShareLinkUseCase {
  const GenerateShareLinkUseCase(this._repo);
  final VocabularyRepository _repo;

  Future<Result<String>> call(String listId) =>
      _repo.generateShareLink(listId);
}
