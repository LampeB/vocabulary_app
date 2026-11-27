import 'dart:convert';
import 'package:drift/drift.dart' show Value;
import '../../domain/entities/word_variant.dart';
import '../datasources/local/app_database.dart';

extension WordVariantDto on WordVariant {
  WordVariantsTableCompanion toLocalCompanion() => WordVariantsTableCompanion(
    id: Value(id),
    conceptId: Value(conceptId),
    word: Value(word),
    langCode: Value(langCode),
    registerTag: Value(registerTag),
    contextTags: Value(jsonEncode(contextTags)),
    isPrimary: Value(isPrimary),
    audioHash: Value(audioHash),
    audioVoiceId: Value(audioVoiceId),
    audioPath: Value(audioPath),
    position: Value(position),
    example: Value(example),
    isSynced: Value(isSynced),
    isDeleted: Value(isDeleted),
    createdAt: Value(createdAt),
    updatedAt: Value(updatedAt),
  );
}

extension WordVariantFromLocal on WordVariantsTableData {
  WordVariant toDomain() => WordVariant(
    id: id,
    conceptId: conceptId,
    word: word,
    langCode: langCode,
    registerTag: registerTag,
    contextTags: List<String>.from(jsonDecode(contextTags) as List<dynamic>),
    isPrimary: isPrimary,
    audioHash: audioHash,
    audioVoiceId: audioVoiceId,
    audioPath: audioPath,
    position: position,
    example: example,
    isSynced: isSynced,
    isDeleted: isDeleted,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  Map<String, dynamic> toRemoteMap() => {
    'id': id,
    'concept_id': conceptId,
    'word': word,
    'lang_code': langCode,
    'register_tag': registerTag,
    'context_tags': jsonDecode(contextTags),
    'is_primary': isPrimary,
    'audio_hash': audioHash,
    'audio_voice_id': audioVoiceId,
    'audio_path': audioPath,
    'position': position,
    'example': example,
    'is_deleted': isDeleted,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };
}

WordVariantsTableCompanion wordVariantCompanionFromRemote(
  Map<String, dynamic> row, {
  bool isSynced = true,
}) => WordVariantsTableCompanion(
  id: Value(row['id'] as String),
  conceptId: Value(row['concept_id'] as String),
  word: Value(row['word'] as String? ?? ''),
  // A physical tombstone may have no language. It still reserves its UUID.
  langCode: Value(
    row['lang_code'] as String? ?? (row['is_deleted'] == true ? '' : 'fr'),
  ),
  registerTag: Value(row['register_tag'] as String? ?? 'neutral'),
  contextTags: Value(jsonEncode(row['context_tags'] as List? ?? const [])),
  isPrimary: Value(row['is_primary'] as bool? ?? false),
  audioHash: Value(row['audio_hash'] as String?),
  audioVoiceId: Value(row['audio_voice_id'] as String?),
  audioPath: Value(row['audio_path'] as String?),
  position: Value(row['position'] as int? ?? 0),
  example: Value(row['example'] as String?),
  isDeleted: Value(row['is_deleted'] as bool? ?? false),
  isSynced: Value(isSynced),
  createdAt: Value(DateTime.parse(row['created_at'] as String)),
  updatedAt: Value(DateTime.parse(row['updated_at'] as String)),
);
