import 'package:freezed_annotation/freezed_annotation.dart';

part 'vocabulary_list.freezed.dart';
part 'vocabulary_list.g.dart';

enum ListVisibility { private, friends, public }

@freezed
class VocabularyList with _$VocabularyList {
  const factory VocabularyList({
    required String id,
    required String ownerId,
    required String name,
    String? description,
    @Default(ListVisibility.private) ListVisibility visibility,
    @Default(0) int wordCount,
    String? shareToken,
    @Default(false) bool isSynced,
    @Default(false) bool isDeleted,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _VocabularyList;

  factory VocabularyList.fromJson(Map<String, dynamic> json) =>
      _$VocabularyListFromJson(json);
}
