// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'concept.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ConceptImpl _$$ConceptImplFromJson(Map<String, dynamic> json) =>
    _$ConceptImpl(
      id: json['id'] as String,
      listId: json['listId'] as String,
      category: json['category'] as String?,
      notes: json['notes'] as String?,
      imageUrl: json['imageUrl'] as String?,
      exampleFr: json['exampleFr'] as String?,
      exampleKo: json['exampleKo'] as String?,
      isSynced: json['isSynced'] as bool? ?? false,
      isDeleted: json['isDeleted'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$$ConceptImplToJson(_$ConceptImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'listId': instance.listId,
      'category': instance.category,
      'notes': instance.notes,
      'imageUrl': instance.imageUrl,
      'exampleFr': instance.exampleFr,
      'exampleKo': instance.exampleKo,
      'isSynced': instance.isSynced,
      'isDeleted': instance.isDeleted,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };
