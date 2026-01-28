import 'package:audioplayers/audioplayers.dart';
import '../../config/app_config.dart';
import '../../config/api_config.dart';
import 'flutter_tts_service.dart';

/// Service de lecture audio (local et HTTP)
/// Supporte aussi le TTS natif Flutter quand useFreeTTS est actif
class AudioPlayerService {
  AudioPlayer? _player;
  bool _isDisposed = false;
  FlutterTtsService? _ttsService;

  /// Initialiser le service audio
  Future<void> initialize() async {
    if (_player != null && !_isDisposed) {
      print('⚠️ AudioPlayer déjà initialisé');
      return;
    }

    _player = AudioPlayer();
    _isDisposed = false;
    print('✅ AudioPlayerService initialisé');
  }

  /// Vérifier et réinitialiser si nécessaire
  Future<void> _ensureInitialized() async {
    if (_player == null || _isDisposed) {
      print('⚠️ Player non initialisé ou disposed, réinitialisation...');
      await initialize();
    }
  }

  /// Jouer l'audio par hash
  Future<bool> playAudioByHash(String hash) async {
    try {
      // ✅ Vérifier et réinitialiser si nécessaire
      await _ensureInitialized();

      final audioService = AppConfig.createAudioService();
      final audioUrl = await audioService.getAudioUrl(hash);

      if (audioUrl == null) {
        print('❌ Audio introuvable pour le hash: $hash');
        return false;
      }

      print('📍 Lecture audio depuis: $audioUrl');
      return await _playFromUrl(audioUrl);
    } catch (e) {
      print('❌ Erreur lors de la lecture audio: $e');
      return false;
    }
  }

  /// Jouer depuis une URL (local ou HTTP)
  Future<bool> _playFromUrl(String url) async {
    try {
      // ✅ Double vérification
      await _ensureInitialized();

      if (_player == null) {
        print('❌ Player toujours null après réinitialisation');
        return false;
      }

      // Arrêter la lecture en cours
      await _player!.stop();

      // Détecter si c'est un fichier local ou HTTP
      if (url.startsWith('http://') || url.startsWith('https://')) {
        // URL HTTP
        print('🌐 Mode HTTP - URL: $url');
        await _player!.play(UrlSource(url));
      } else {
        // Fichier local - convertir en URI file://
        String fileUri = url;
        if (!url.startsWith('file://')) {
          // Convertir chemin Windows en URI
          fileUri = 'file:///${url.replaceAll('\\', '/')}';
        }

        print('💾 Mode local - Chemin fichier: $url');
        print('🔗 URI converti: $fileUri');

        await _player!.play(DeviceFileSource(url));
      }

      print('✅ Lecture démarrée avec succès');
      return true;
    } catch (e, stackTrace) {
      print('❌ Erreur lors de la lecture: $e');
      print('Stack trace: $stackTrace');

      // Tenter de réinitialiser pour la prochaine fois
      _isDisposed = true;

      return false;
    }
  }

  /// Arrêter la lecture
  Future<void> stop() async {
    try {
      if (_player != null && !_isDisposed) {
        await _player!.stop();
        print('🛑 Lecture arrêtée');
      }
    } catch (e) {
      print('❌ Erreur lors de l\'arrêt: $e');
    }
  }

  /// Mettre en pause
  Future<void> pause() async {
    try {
      if (_player != null && !_isDisposed) {
        await _player!.pause();
        print('⏸️ Lecture en pause');
      }
    } catch (e) {
      print('❌ Erreur lors de la mise en pause: $e');
    }
  }

  /// Reprendre la lecture
  Future<void> resume() async {
    try {
      await _ensureInitialized();
      if (_player != null) {
        await _player!.resume();
        print('▶️ Lecture reprise');
      }
    } catch (e) {
      print('❌ Erreur lors de la reprise: $e');
    }
  }

  /// Jouer l'audio avec TTS natif (mode gratuit)
  /// Utilise la synthèse vocale du système
  Future<bool> speakText(String text, String langCode) async {
    try {
      // Initialiser le service TTS si nécessaire
      _ttsService ??= FlutterTtsService();
      await _ttsService!.initialize();

      print('🗣️ TTS: "$text" en $langCode');
      return await _ttsService!.speak(text, langCode);
    } catch (e) {
      print('❌ Erreur TTS: $e');
      return false;
    }
  }

  /// Jouer l'audio intelligemment :
  /// - Si audioHash existe et useFreeTTS est false : lecture du fichier
  /// - Sinon : utilise le TTS natif
  Future<bool> playAudioSmart({
    String? audioHash,
    required String text,
    required String langCode,
  }) async {
    // Si on a un hash ET qu'on n'utilise pas le TTS gratuit, lire le fichier
    if (audioHash != null && !ApiConfig.useFreeTTS) {
      return await playAudioByHash(audioHash);
    }

    // Sinon, utiliser le TTS natif
    return await speakText(text, langCode);
  }

  /// Arrêter le TTS
  Future<void> stopTts() async {
    if (_ttsService != null) {
      await _ttsService!.stop();
    }
  }

  /// Libérer les ressources
  void dispose() {
    if (_player != null && !_isDisposed) {
      _player!.dispose();
      _player = null;
      _isDisposed = true;
      print('🗑️ AudioPlayerService disposed');
    }
    _ttsService?.dispose();
    _ttsService = null;
  }
}
