// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'word_variant.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$WordVariantImpl _$$WordVariantImplFromJson(Map<String, dynamic> json) =>
    _$WordVariantImpl(
      id: json['id'] as String,
      conceptId: json['conceptId'] as String,
      word: json['word'] as String,
      langCode: json['langCode'] as String,
      registerTag: json['registerTag'] as String? ?? 'neutral',
      contextTags: (json['contextTags'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      isPrimary: json['isPrimary'] as bool? ?? false,
      audioHash: json['audioHash'] as String?,
      audioVoiceId: json['audioVoiceId'] as String?,
      position: (json['position'] as num?)?.toInt() ?? 0,
      isSynced: json['isSynced'] as bool? ?? false,
      isDeleted: json['isDeleted'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$$WordVariantImplToJson(_$WordVariantImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'conceptId': instance.conceptId,
      'word': instance.word,
      'langCode': instance.langCode,
      'registerTag': instance.registerTag,
      'contextTags': instance.contextTags,
      'isPrimary': instance.isPrimary,
      'audioHash': instance.audioHash,
      'audioVoiceId': instance.audioVoiceId,
      'position': instance.position,
      'isSynced': instance.isSynced,
      'isDeleted': instance.isDeleted,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };
