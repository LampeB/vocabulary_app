import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'database_schema.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() {
    return _instance;
  }

  DatabaseService._internal();

  // Initialiser sqflite pour desktop (Windows, Linux, macOS)
  static void initializeFfi() {
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }

  // Getter pour accéder à la base de données
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // Initialiser la base de données
  Future<Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsPath();
    final path = join(documentsDirectory, DatabaseSchema.dbName);

    // Sur Android/iOS, utiliser openDatabase directement
    // Sur Desktop, utiliser databaseFactory qui a été configuré dans initializeFfi
    if (Platform.isAndroid || Platform.isIOS) {
      return await openDatabase(
        path,
        version: DatabaseSchema.dbVersion,
        onCreate: DatabaseSchema.onCreate,
        onUpgrade: DatabaseSchema.onUpgrade,
        onConfigure: (db) async {
          // Activer les foreign keys
          await db.execute('PRAGMA foreign_keys = ON');
        },
      );
    } else {
      return await databaseFactory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: DatabaseSchema.dbVersion,
          onCreate: DatabaseSchema.onCreate,
          onUpgrade: DatabaseSchema.onUpgrade,
          onConfigure: (db) async {
            // Activer les foreign keys
            await db.execute('PRAGMA foreign_keys = ON');
          },
        ),
      );
    }
  }

  // Obtenir le chemin du dossier documents
  Future<String> getApplicationDocumentsPath() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final directory = await getApplicationDocumentsDirectory();
      final appDir = Directory(join(directory.path, 'VocabularyApp'));
      if (!await appDir.exists()) {
        await appDir.create(recursive: true);
      }
      return appDir.path;
    } else {
      // Mobile (Android/iOS)
      final directory = await getApplicationDocumentsDirectory();
      return directory.path;
    }
  }

  // Fermer la base de données
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }

  // Supprimer complètement la base de données (pour reset)
  Future<void> deleteDatabase() async {
    final documentsPath = await getApplicationDocumentsPath();
    final path = join(documentsPath, DatabaseSchema.dbName);
    await databaseFactory.deleteDatabase(path);
    _database = null;
  }

  // ==================== VOCABULARY LISTS ====================

  Future<int> insertVocabularyList(Map<String, dynamic> list) async {
    final db = await database;
    return await db.insert(
      DatabaseSchema.tableVocabularyLists,
      list,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getAllVocabularyLists() async {
    final db = await database;
    return await db.query(
      DatabaseSchema.tableVocabularyLists,
      orderBy: 'created_at DESC',
    );
  }

  Future<Map<String, dynamic>?> getVocabularyListById(String id) async {
    final db = await database;
    final results = await db.query(
      DatabaseSchema.tableVocabularyLists,
      where: 'id = ?',
      whereArgs: [id],
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<int> updateVocabularyList(
      String id, Map<String, dynamic> updates) async {
    final db = await database;
    return await db.update(
      DatabaseSchema.tableVocabularyLists,
      updates,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteVocabularyList(String id) async {
    final db = await database;
    // Les cascades suppriment automatiquement les concepts, variantes, etc.
    return await db.delete(
      DatabaseSchema.tableVocabularyLists,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==================== CONCEPTS ====================

  Future<int> insertConcept(Map<String, dynamic> concept) async {
    final db = await database;
    return await db.insert(
      DatabaseSchema.tableConcepts,
      concept,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getConceptsByListId(String listId) async {
    final db = await database;
    return await db.query(
      DatabaseSchema.tableConcepts,
      where: 'list_id = ?',
      whereArgs: [listId],
      orderBy: 'created_at ASC',
    );
  }

  Future<Map<String, dynamic>?> getConceptById(String id) async {
    final db = await database;
    final results = await db.query(
      DatabaseSchema.tableConcepts,
      where: 'id = ?',
      whereArgs: [id],
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<int> updateConcept(String id, Map<String, dynamic> updates) async {
    final db = await database;
    return await db.update(
      DatabaseSchema.tableConcepts,
      updates,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteConcept(String id) async {
    final db = await database;
    return await db.delete(
      DatabaseSchema.tableConcepts,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==================== WORD VARIANTS ====================

  Future<int> insertWordVariant(Map<String, dynamic> variant) async {
    final db = await database;
    return await db.insert(
      DatabaseSchema.tableWordVariants,
      variant,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getVariantsByConceptId(
      String conceptId) async {
    final db = await database;
    return await db.query(
      DatabaseSchema.tableWordVariants,
      where: 'concept_id = ?',
      whereArgs: [conceptId],
      orderBy: 'position ASC',
      distinct: true,
    );
  }

  Future<Map<String, dynamic>?> getWordVariantById(String id) async {
    final db = await database;
    final results = await db.query(
      DatabaseSchema.tableWordVariants,
      where: 'id = ?',
      whereArgs: [id],
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<Map<String, dynamic>?> getVariantById(String variantId) async {
    final db = await database;
    final results = await db.query(
      'word_variants',
      where: 'id = ?',
      whereArgs: [variantId],
    );

    return results.isNotEmpty ? results.first : null;
  }

  Future<void> updateWordVariant(
    String variantId,
    Map<String, dynamic> updates,
  ) async {
    final db = await database;
    await db.update(
      'word_variants',
      updates,
      where: 'id = ?',
      whereArgs: [variantId],
    );
  }

  Future<int> deleteWordVariant(String id) async {
    final db = await database;
    return await db.delete(
      DatabaseSchema.tableWordVariants,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==================== VARIANT PROGRESS ====================

  Future<int> insertVariantProgress(Map<String, dynamic> progress) async {
    final db = await database;
    return await db.insert(
      DatabaseSchema.tableVariantProgress,
      progress,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getProgressByVariantAndDirection(
    String variantId,
    String direction,
  ) async {
    final db = await database;
    final results = await db.query(
      DatabaseSchema.tableVariantProgress,
      where: 'variant_id = ? AND direction = ?',
      whereArgs: [variantId, direction],
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<int> updateVariantProgress(
      String id, Map<String, dynamic> updates) async {
    final db = await database;
    return await db.update(
      DatabaseSchema.tableVariantProgress,
      updates,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Récupérer les variantes à réviser (next_review_date <= aujourd'hui)
  Future<List<Map<String, dynamic>>> getVariantsDueForReview({
    int limit = 20,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    return await db.query(
      DatabaseSchema.tableVariantProgress,
      where: 'next_review_date <= ?',
      whereArgs: [now],
      orderBy: 'next_review_date ASC',
      limit: limit,
    );
  }

  // ==================== STATISTIQUES ====================

  // Nombre total de concepts dans une liste
  Future<int> getConceptCountForList(String listId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ${DatabaseSchema.tableConcepts} WHERE list_id = ?',
      [listId],
    );
    if (result.isEmpty) return 0;
    return (result.first['count'] as int?) ?? 0;
  }

  // Nombre de mots connus (mastery >= 0.7) dans une liste
  Future<int> getKnownWordsCountForList(String listId) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT COUNT(DISTINCT vp.variant_id) as count
      FROM ${DatabaseSchema.tableVariantProgress} vp
      INNER JOIN ${DatabaseSchema.tableWordVariants} wv ON vp.variant_id = wv.id
      INNER JOIN ${DatabaseSchema.tableConcepts} c ON wv.concept_id = c.id
      WHERE c.list_id = ? AND vp.is_known = 1
    ''', [listId]);
    if (result.isEmpty) return 0;
    return (result.first['count'] as int?) ?? 0;
  }
}
