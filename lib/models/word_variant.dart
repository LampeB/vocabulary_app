import 'dart:convert';

class WordVariant {
  final String id;
  final String conceptId;
  final String word;
  final String langCode;
  final String registerTag; // 'formal', 'informal', 'neutral', 'very_informal'
  final List<String> contextTags; // Ex: ["written", "oral"]
  final int position;
  final bool isPrimary;
  final String? audioHash;
  final String createdAt;

  WordVariant({
    required this.id,
    required this.conceptId,
    required this.word,
    required this.langCode,
    this.registerTag = 'neutral',
    this.contextTags = const [],
    this.position = 0,
    this.isPrimary = false,
    this.audioHash,
    required this.createdAt,
  });

  // Conversion depuis Map (SQLite)
  factory WordVariant.fromMap(Map<String, dynamic> map) {
    // Decoder le JSON pour contextTags
    List<String> tags = [];
    if (map['context_tags'] != null) {
      final decoded = json.decode(map['context_tags'] as String);
      if (decoded is List) {
        tags = decoded.cast<String>();
      }
    }

    return WordVariant(
      id: map['id'] as String,
      conceptId: map['concept_id'] as String,
      word: map['word'] as String,
      langCode: map['lang_code'] as String,
      registerTag: map['register_tag'] as String? ?? 'neutral',
      contextTags: tags,
      position: map['position'] as int? ?? 0,
      isPrimary: (map['is_primary'] as int? ?? 0) == 1,
      audioHash: map['audio_hash'] as String?,
      createdAt: map['created_at'] as String,
    );
  }

  // Conversion vers Map (SQLite)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'concept_id': conceptId,
      'word': word,
      'lang_code': langCode,
      'register_tag': registerTag,
      'context_tags': json.encode(contextTags),
      'position': position,
      'is_primary': isPrimary ? 1 : 0,
      'audio_hash': audioHash,
      'created_at': createdAt,
    };
  }

  // Copie avec modifications
  WordVariant copyWith({
    String? id,
    String? conceptId,
    String? word,
    String? langCode,
    String? registerTag,
    List<String>? contextTags,
    int? position,
    bool? isPrimary,
    String? audioHash,
    String? createdAt,
  }) {
    return WordVariant(
      id: id ?? this.id,
      conceptId: conceptId ?? this.conceptId,
      word: word ?? this.word,
      langCode: langCode ?? this.langCode,
      registerTag: registerTag ?? this.registerTag,
      contextTags: contextTags ?? this.contextTags,
      position: position ?? this.position,
      isPrimary: isPrimary ?? this.isPrimary,
      audioHash: audioHash ?? this.audioHash,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'WordVariant(word: $word, lang: $langCode, register: $registerTag, primary: $isPrimary)';
  }
}
