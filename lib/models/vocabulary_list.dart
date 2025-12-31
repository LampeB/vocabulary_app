class VocabularyList {
  final String id;
  final String name;
  final String lang1Code;
  final String lang2Code;
  final String createdAt;
  final int totalConcepts;
  final bool isDownloaded;
  final String downloadStatus; // 'idle', 'downloading', 'completed', 'error'

  VocabularyList({
    required this.id,
    required this.name,
    required this.lang1Code,
    required this.lang2Code,
    required this.createdAt,
    this.totalConcepts = 0,
    this.isDownloaded = false,
    this.downloadStatus = 'idle',
  });

  // Conversion depuis Map (SQLite)
  factory VocabularyList.fromMap(Map<String, dynamic> map) {
    return VocabularyList(
      id: map['id'] as String,
      name: map['name'] as String,
      lang1Code: map['lang1_code'] as String,
      lang2Code: map['lang2_code'] as String,
      createdAt: map['created_at'] as String,
      totalConcepts: map['total_concepts'] as int? ?? 0,
      isDownloaded: (map['is_downloaded'] as int? ?? 0) == 1,
      downloadStatus: map['download_status'] as String? ?? 'idle',
    );
  }

  // Conversion vers Map (SQLite)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'lang1_code': lang1Code,
      'lang2_code': lang2Code,
      'created_at': createdAt,
      'total_concepts': totalConcepts,
      'is_downloaded': isDownloaded ? 1 : 0,
      'download_status': downloadStatus,
    };
  }

  // Copie avec modifications
  VocabularyList copyWith({
    String? id,
    String? name,
    String? lang1Code,
    String? lang2Code,
    String? createdAt,
    int? totalConcepts,
    bool? isDownloaded,
    String? downloadStatus,
  }) {
    return VocabularyList(
      id: id ?? this.id,
      name: name ?? this.name,
      lang1Code: lang1Code ?? this.lang1Code,
      lang2Code: lang2Code ?? this.lang2Code,
      createdAt: createdAt ?? this.createdAt,
      totalConcepts: totalConcepts ?? this.totalConcepts,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      downloadStatus: downloadStatus ?? this.downloadStatus,
    );
  }

  @override
  String toString() {
    return 'VocabularyList(id: $id, name: $name, $lang1Code ↔ $lang2Code, concepts: $totalConcepts)';
  }
}
