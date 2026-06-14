import 'package:drift/drift.dart' show Value;
import '../../domain/entities/vocabulary_list.dart';
import '../datasources/local/app_database.dart';

extension VocabularyListDto on VocabularyList {
  VocabularyListsTableCompanion toLocalCompanion() {
    return VocabularyListsTableCompanion(
      id: Value(id),
      ownerId: Value(ownerId),
      name: Value(name),
      description: Value(description),
      visibility: Value(visibility.name),
      wordCount: Value(wordCount),
      shareToken: Value(shareToken),
      isSynced: Value(isSynced),
      isDeleted: Value(isDeleted),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  Map<String, dynamic> toRemoteMap() => {
        'id': id,
        'owner_id': ownerId,
        'name': name,
        'description': description,
        'visibility': visibility.name,
        'word_count': wordCount,
        'share_token': shareToken,
        'is_deleted': isDeleted,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

extension VocabularyListFromLocal on VocabularyListsTableData {
  VocabularyList toDomain() => VocabularyList(
        id: id,
        ownerId: ownerId,
        name: name,
        description: description,
        visibility: ListVisibility.values.byName(visibility),
        wordCount: wordCount,
        shareToken: shareToken,
        isSynced: isSynced,
        isDeleted: isDeleted,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}

extension VocabularyListFromRemote on Map<String, dynamic> {
  VocabularyList toVocabularyListDomain() => VocabularyList(
        id: this['id'] as String,
        ownerId: this['owner_id'] as String,
        name: this['name'] as String,
        description: this['description'] as String?,
        visibility: ListVisibility.values.byName(this['visibility'] as String? ?? 'private'),
        wordCount: this['word_count'] as int? ?? 0,
        shareToken: this['share_token'] as String?,
        isSynced: true,
        isDeleted: this['is_deleted'] as bool? ?? false,
        createdAt: DateTime.parse(this['created_at'] as String),
        updatedAt: DateTime.parse(this['updated_at'] as String),
      );
}
