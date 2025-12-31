class DatabaseSchema {
  // Nom de la base de données
  static const String dbName = 'vocabulary.db';
  static const int dbVersion = 1;

  // Noms des tables
  static const String tableVocabularyLists = 'vocabulary_lists';
  static const String tableConcepts = 'concepts';
  static const String tableWordVariants = 'word_variants';
  static const String tableVariantRelations = 'variant_relations';
  static const String tableVariantProgress = 'variant_progress';

  // Script de création des tables
  static const String createVocabularyListsTable = '''
    CREATE TABLE $tableVocabularyLists (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      lang1_code TEXT NOT NULL,
      lang2_code TEXT NOT NULL,
      created_at TEXT NOT NULL,
      total_concepts INTEGER DEFAULT 0,
      is_downloaded INTEGER DEFAULT 0,
      download_status TEXT DEFAULT 'idle'
    )
  ''';

  static const String createConceptsTable = '''
    CREATE TABLE $tableConcepts (
      id TEXT PRIMARY KEY,
      list_id TEXT NOT NULL,
      category TEXT,
      context_lang1 TEXT,
      context_lang2 TEXT,
      image_url TEXT,
      example_sentence_lang1 TEXT,
      example_sentence_lang2 TEXT,
      notes TEXT,
      created_at TEXT NOT NULL,
      FOREIGN KEY (list_id) REFERENCES $tableVocabularyLists(id) ON DELETE CASCADE
    )
  ''';

  static const String createWordVariantsTable = '''
    CREATE TABLE $tableWordVariants (
      id TEXT PRIMARY KEY,
      concept_id TEXT NOT NULL,
      word TEXT NOT NULL,
      lang_code TEXT NOT NULL,
      register_tag TEXT DEFAULT 'neutral',
      context_tags TEXT,
      position INTEGER DEFAULT 0,
      is_primary INTEGER DEFAULT 0,
      audio_hash TEXT,
      created_at TEXT NOT NULL,
      FOREIGN KEY (concept_id) REFERENCES $tableConcepts(id) ON DELETE CASCADE
    )
  ''';

  static const String createVariantRelationsTable = '''
    CREATE TABLE $tableVariantRelations (
      id TEXT PRIMARY KEY,
      concept_id TEXT NOT NULL,
      variant_lang1_id TEXT NOT NULL,
      variant_lang2_id TEXT NOT NULL,
      is_valid INTEGER DEFAULT 1,
      relation_type TEXT DEFAULT 'auto',
      confidence REAL,
      created_at TEXT NOT NULL,
      FOREIGN KEY (concept_id) REFERENCES $tableConcepts(id) ON DELETE CASCADE,
      FOREIGN KEY (variant_lang1_id) REFERENCES $tableWordVariants(id) ON DELETE CASCADE,
      FOREIGN KEY (variant_lang2_id) REFERENCES $tableWordVariants(id) ON DELETE CASCADE
    )
  ''';

  static const String createVariantProgressTable = '''
    CREATE TABLE $tableVariantProgress (
      id TEXT PRIMARY KEY,
      variant_id TEXT NOT NULL,
      direction TEXT NOT NULL,
      times_shown_as_question INTEGER DEFAULT 0,
      times_shown_as_answer INTEGER DEFAULT 0,
      times_answered_correctly INTEGER DEFAULT 0,
      times_user_preferred INTEGER DEFAULT 0,
      last_seen_date TEXT,
      next_review_date TEXT,
      mastery_level REAL DEFAULT 0.0,
      is_known INTEGER DEFAULT 0,
      FOREIGN KEY (variant_id) REFERENCES $tableWordVariants(id) ON DELETE CASCADE
    )
  ''';

  // Index pour améliorer les performances
  static const List<String> indexes = [
    'CREATE INDEX idx_concepts_list ON $tableConcepts(list_id)',
    'CREATE INDEX idx_concepts_category ON $tableConcepts(category)',
    'CREATE INDEX idx_variants_concept ON $tableWordVariants(concept_id)',
    'CREATE INDEX idx_variants_word ON $tableWordVariants(word)',
    'CREATE INDEX idx_variants_lang ON $tableWordVariants(lang_code)',
    'CREATE INDEX idx_variants_hash ON $tableWordVariants(audio_hash)',
    'CREATE INDEX idx_relations_concept ON $tableVariantRelations(concept_id)',
    'CREATE INDEX idx_relations_v1 ON $tableVariantRelations(variant_lang1_id)',
    'CREATE INDEX idx_relations_v2 ON $tableVariantRelations(variant_lang2_id)',
    'CREATE INDEX idx_progress_variant ON $tableVariantProgress(variant_id)',
    'CREATE INDEX idx_progress_direction ON $tableVariantProgress(direction)',
    'CREATE INDEX idx_progress_review ON $tableVariantProgress(next_review_date)',
  ];

  // Script complet de création de la base
  static Future<void> onCreate(dynamic db, int version) async {
    // Créer les tables
    await db.execute(createVocabularyListsTable);
    await db.execute(createConceptsTable);
    await db.execute(createWordVariantsTable);
    await db.execute(createVariantRelationsTable);
    await db.execute(createVariantProgressTable);

    // Créer les index
    for (String index in indexes) {
      await db.execute(index);
    }
  }

  // Migration (pour versions futures)
  static Future<void> onUpgrade(dynamic db, int oldVersion, int newVersion) async {
    // Pour l'instant, pas de migration nécessaire
    // Ajoutez ici les migrations futures si besoin
  }
}
