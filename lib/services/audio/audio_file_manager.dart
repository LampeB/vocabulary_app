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

  Future<void> initialize() async {
    if (_audioDirectory != null) return;

    try {
      final appDir = await getApplicationDocumentsDirectory();
      _audioDirectory = path.join(appDir.path, 'VocabularyApp', 'audio');

      final dir = Directory(_audioDirectory!);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
    } catch (_) {}
  }

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
      return filePath;
    } catch (e) {
      return null;
    }
  }

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

  Future<bool> audioFileExists(String hash) async {
    final filePath = await getAudioFilePath(hash);
    return filePath != null;
  }

  Future<void> deleteAudioFile(String hash) async {
    try {
      final filePath = await getAudioFilePath(hash);
      if (filePath != null) {
        final file = File(filePath);
        await file.delete();
      }
    } catch (_) {}
  }

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
    } catch (_) {}

    return totalSize;
  }

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
          }
        }
      }
    } catch (_) {}
  }

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
    } catch (_) {}

    return count;
  }
}
