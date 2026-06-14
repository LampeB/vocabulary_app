import 'package:freezed_annotation/freezed_annotation.dart';

part 'word_variant.freezed.dart';
part 'word_variant.g.dart';

@freezed
class WordVariant with _$WordVariant {
  const factory WordVariant({
    required String id,
    required String conceptId,
    required String word,
    required String langCode,
    @Default('neutral') String registerTag,
    @Default([]) List<String> contextTags,
    @Default(false) bool isPrimary,
    String? audioHash,
    String? audioVoiceId,
    @Default(0) int position,
    @Default(false) bool isSynced,
    @Default(false) bool isDeleted,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _WordVariant;

  factory WordVariant.fromJson(Map<String, dynamic> json) =>
      _$WordVariantFromJson(json);
}
