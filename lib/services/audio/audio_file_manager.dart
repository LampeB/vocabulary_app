import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// Gestionnaire de fichiers audio
class AudioFileManager {
  static final AudioFileManager _instance = AudioFileManager._internal();
  String? _audioDirectory;

  factory AudioFileManager() {
    return _instance;
  }

  AudioFileManager._internal();

  /// Initialiser le gestionnaire et créer le dossier audio
  Future<void> initialize() async {
    if (_audioDirectory != null) return;

    try {
      final appDir = await getApplicationDocumentsDirectory();
      _audioDirectory = path.join(appDir.path, 'VocabularyApp', 'audio');

      final dir = Directory(_audioDirectory!);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
    } catch (e) {
      print('Erreur lors de l\'initialisation du dossier audio: $e');
    }
  }

  /// Sauvegarder un fichier audio
  /// 
  /// Paramètres:
  /// - audioBytes: Les bytes du fichier audio
  /// - hash: Le hash unique du fichier (MD5 du texte + langue)
  /// 
  /// Retourne: Le chemin du fichier sauvegardé, ou null en cas d'erreur
  Future<String?> saveAudioFile({
    required Uint8List audioBytes,
    required String hash,
  }) async {
    if (_audioDirectory == null) {
      await initialize();
    }

    try {
      final fileName = '$hash.mp3';
      final filePath = path.join(_audioDirectory!, fileName);
      final file = File(filePath);

      await file.writeAsBytes(audioBytes);
      print('Fichier audio sauvegardé: $filePath');

      return filePath;
    } catch (e) {
      print('Erreur lors de la sauvegarde du fichier audio: $e');
      return null;
    }
  }

  /// Obtenir le chemin d'un fichier audio à partir de son hash
  /// 
  /// Retourne: Le chemin du fichier, ou null s'il n'existe pas
  Future<String?> getAudioFilePath(String hash) async {
    if (_audioDirectory == null) {
      await initialize();
    }

    final fileName = '$hash.mp3';
    final filePath = path.join(_audioDirectory!, fileName);
    final file = File(filePath);

    if (await file.exists()) {
      return filePath;
    }

    return null;
  }

  /// Vérifier si un fichier audio existe
  Future<bool> audioFileExists(String hash) async {
    final filePath = await getAudioFilePath(hash);
    return filePath != null;
  }

  /// Supprimer un fichier audio
  Future<void> deleteAudioFile(String hash) async {
    try {
      final filePath = await getAudioFilePath(hash);
      if (filePath != null) {
        final file = File(filePath);
        await file.delete();
        print('Fichier audio supprimé: $filePath');
      }
    } catch (e) {
      print('Erreur lors de la suppression du fichier audio: $e');
    }
  }

  /// Obtenir la taille du dossier audio (en bytes)
  Future<int> getAudioFolderSize() async {
    if (_audioDirectory == null) {
      await initialize();
    }

    int totalSize = 0;
    try {
      final dir = Directory(_audioDirectory!);
      if (await dir.exists()) {
        await for (var entity in dir.list(recursive: true)) {
          if (entity is File) {
            totalSize += await entity.length();
          }
        }
      }
    } catch (e) {
      print('Erreur lors du calcul de la taille: $e');
    }

    return totalSize;
  }

  /// Nettoyer les fichiers audio orphelins
  /// (fichiers qui ne sont plus référencés dans la DB)
  Future<void> cleanOrphanedFiles(List<String> validHashes) async {
    if (_audioDirectory == null) {
      await initialize();
    }

    try {
      final dir = Directory(_audioDirectory!);
      if (!await dir.exists()) return;

      await for (var entity in dir.list()) {
        if (entity is File && entity.path.endsWith('.mp3')) {
          final fileName = path.basename(entity.path);
          final hash = fileName.replaceAll('.mp3', '');

          if (!validHashes.contains(hash)) {
            await entity.delete();
            print('Fichier orphelin supprimé: $fileName');
          }
        }
      }
    } catch (e) {
      print('Erreur lors du nettoyage: $e');
    }
  }

  /// Obtenir le nombre de fichiers audio
  Future<int> getAudioFileCount() async {
    if (_audioDirectory == null) {
      await initialize();
    }

    int count = 0;
    try {
      final dir = Directory(_audioDirectory!);
      if (await dir.exists()) {
        await for (var entity in dir.list()) {
          if (entity is File && entity.path.endsWith('.mp3')) {
            count++;
          }
        }
      }
    } catch (e) {
      print('Erreur lors du comptage: $e');
    }

    return count;
  }
}
