import 'package:audioplayers/audioplayers.dart';
import '../../config/app_config.dart';

/// Service de lecture audio (local et HTTP)
class AudioPlayerService {
  AudioPlayer? _player;
  bool _isDisposed = false;

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

  /// Libérer les ressources
  void dispose() {
    if (_player != null && !_isDisposed) {
      _player!.dispose();
      _player = null;
      _isDisposed = true;
      print('🗑️ AudioPlayerService disposed');
    }
  }
}
