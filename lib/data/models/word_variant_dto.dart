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
        position: Value(position),
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
        contextTags: List<String>.from(
            jsonDecode(contextTags) as List<dynamic>),
        isPrimary: isPrimary,
        audioHash: audioHash,
        audioVoiceId: audioVoiceId,
        position: position,
        isSynced: isSynced,
        isDeleted: isDeleted,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}
