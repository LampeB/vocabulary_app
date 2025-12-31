class Concept {
  final String id;
  final String listId;
  final String? category;
  final String? contextLang1;
  final String? contextLang2;
  final String? imageUrl;
  final String? exampleSentenceLang1;
  final String? exampleSentenceLang2;
  final String? notes;
  final String createdAt;

  Concept({
    required this.id,
    required this.listId,
    this.category,
    this.contextLang1,
    this.contextLang2,
    this.imageUrl,
    this.exampleSentenceLang1,
    this.exampleSentenceLang2,
    this.notes,
    required this.createdAt,
  });

  // Conversion depuis Map (SQLite)
  factory Concept.fromMap(Map<String, dynamic> map) {
    return Concept(
      id: map['id'] as String,
      listId: map['list_id'] as String,
      category: map['category'] as String?,
      contextLang1: map['context_lang1'] as String?,
      contextLang2: map['context_lang2'] as String?,
      imageUrl: map['image_url'] as String?,
      exampleSentenceLang1: map['example_sentence_lang1'] as String?,
      exampleSentenceLang2: map['example_sentence_lang2'] as String?,
      notes: map['notes'] as String?,
      createdAt: map['created_at'] as String,
    );
  }

  // Conversion vers Map (SQLite)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'list_id': listId,
      'category': category,
      'context_lang1': contextLang1,
      'context_lang2': contextLang2,
      'image_url': imageUrl,
      'example_sentence_lang1': exampleSentenceLang1,
      'example_sentence_lang2': exampleSentenceLang2,
      'notes': notes,
      'created_at': createdAt,
    };
  }

  // Copie avec modifications
  Concept copyWith({
    String? id,
    String? listId,
    String? category,
    String? contextLang1,
    String? contextLang2,
    String? imageUrl,
    String? exampleSentenceLang1,
    String? exampleSentenceLang2,
    String? notes,
    String? createdAt,
  }) {
    return Concept(
      id: id ?? this.id,
      listId: listId ?? this.listId,
      category: category ?? this.category,
      contextLang1: contextLang1 ?? this.contextLang1,
      contextLang2: contextLang2 ?? this.contextLang2,
      imageUrl: imageUrl ?? this.imageUrl,
      exampleSentenceLang1: exampleSentenceLang1 ?? this.exampleSentenceLang1,
      exampleSentenceLang2: exampleSentenceLang2 ?? this.exampleSentenceLang2,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'Concept(id: $id, category: $category, context: $contextLang1/$contextLang2)';
  }
}
