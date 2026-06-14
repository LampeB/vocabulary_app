// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vocabulary_list.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$VocabularyListImpl _$$VocabularyListImplFromJson(Map<String, dynamic> json) =>
    _$VocabularyListImpl(
      id: json['id'] as String,
      ownerId: json['ownerId'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      visibility:
          $enumDecodeNullable(_$ListVisibilityEnumMap, json['visibility']) ??
              ListVisibility.private,
      wordCount: (json['wordCount'] as num?)?.toInt() ?? 0,
      shareToken: json['shareToken'] as String?,
      isSynced: json['isSynced'] as bool? ?? false,
      isDeleted: json['isDeleted'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$$VocabularyListImplToJson(
        _$VocabularyListImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'ownerId': instance.ownerId,
      'name': instance.name,
      'description': instance.description,
      'visibility': _$ListVisibilityEnumMap[instance.visibility]!,
      'wordCount': instance.wordCount,
      'shareToken': instance.shareToken,
      'isSynced': instance.isSynced,
      'isDeleted': instance.isDeleted,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };

const _$ListVisibilityEnumMap = {
  ListVisibility.private: 'private',
  ListVisibility.friends: 'friends',
  ListVisibility.public: 'public',
};
