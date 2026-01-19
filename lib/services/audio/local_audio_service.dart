import 'dart:typed_data';
import 'audio_service.dart';
import 'elevenlabs_service.dart';
import 'audio_file_manager.dart';
import '../../models/audio_settings.dart';
import '../../utils/audio_preferences.dart';

/// Implémentation locale du service audio
/// Utilise ElevenLabs pour la génération et stocke les fichiers localement
class LocalAudioService implements AudioService {
  final ElevenLabsService _elevenlabs;
  final AudioFileManager _fileManager;

  LocalAudioService({
    ElevenLabsService? elevenlabs,
    AudioFileManager? fileManager,
  })  : _elevenlabs = elevenlabs ?? ElevenLabsService(),
        _fileManager = fileManager ?? AudioFileManager();

  @override
  Future<AudioResult> getOrGenerateAudio({
    required String text,
    required String langCode,
    Function(String)? onProgress,
    bool forceRegenerate = false,
  }) async {
    // Initialiser le gestionnaire de fichiers
    await _fileManager.initialize();

    // Calculer le hash
    final hash = calculateHash(text, langCode);

    // Vérifier si l'audio existe déjà en cache (sauf si régénération forcée)
    if (!forceRegenerate && await audioExists(hash)) {
      onProgress?.call('Audio trouvé dans le cache');
      final url = await getAudioUrl(hash);
      return AudioResult(
        hash: hash,
        audioUrl: url!,
        fromCache: true,
      );
    }

    // Charger les paramètres audio de l'utilisateur
    final audioSettings = await AudioPreferences.loadSettings();

    // Générer l'audio avec ElevenLabs
    if (forceRegenerate) {
      onProgress?.call('Régénération de l\'audio: "$text"...');
    } else {
      onProgress?.call('Génération audio: "$text"...');
    }

    final audioBytes = await _elevenlabs.generateAudio(
      text: text,
      langCode: langCode,
      settings: audioSettings,
    );

    if (audioBytes == null) {
      throw AudioGenerationException(
          'Échec de la génération audio pour "$text"');
    }

    // Sauvegarder localement (écraser si régénération)
    onProgress?.call('Sauvegarde du fichier audio...');

    final filePath = await _fileManager.saveAudioFile(
      audioBytes: audioBytes,
      hash: hash,
    );

    if (filePath == null) {
      throw AudioStorageException('Échec de la sauvegarde de l\'audio');
    }

    // Convertir le chemin en URL file://
    final url = await getAudioUrl(hash);

    return AudioResult(
      hash: hash,
      audioUrl: url!,
      fromCache: false,
    );
  }

  @override
  Future<String?> getAudioUrl(String hash) async {
    final filePath = await _fileManager.getAudioFilePath(hash);

    if (filePath == null) {
      return null;
    }

    // Le chemin local sera converti en URI file:// par l'AudioPlayerService
    return filePath;
  }

  @override
  Future<bool> audioExists(String hash) async {
    return await _fileManager.audioFileExists(hash);
  }

  @override
  Future<void> deleteAudio(String hash) async {
    await _fileManager.deleteAudioFile(hash);
  }

  @override
  String calculateHash(String text, String langCode) {
    return _elevenlabs.calculateHash(text, langCode);
  }
}

/// Exception levée lors de l'échec de génération audio
class AudioGenerationException implements Exception {
  final String message;
  AudioGenerationException(this.message);

  @override
  String toString() => 'AudioGenerationException: $message';
}

/// Exception levée lors de l'échec de stockage audio
class AudioStorageException implements Exception {
  final String message;
  AudioStorageException(this.message);

  @override
  String toString() => 'AudioStorageException: $message';
}
