import 'package:flutter_tts/flutter_tts.dart';
import '../../config/api_config.dart';

/// Service TTS natif Flutter (gratuit, sans API key)
/// Utilise la synthèse vocale du système
class FlutterTtsService {
  FlutterTts? _tts;
  bool _isInitialized = false;
  bool _isSpeaking = false;

  /// Initialiser le service TTS
  Future<void> initialize() async {
    if (_isInitialized) return;

    _tts = FlutterTts();

    // Configuration par défaut
    await _tts!.setVolume(1.0);
    await _tts!.setSpeechRate(0.5);
    await _tts!.setPitch(1.0);

    // Callbacks
    _tts!.setStartHandler(() {
      _isSpeaking = true;
    });

    _tts!.setCompletionHandler(() {
      _isSpeaking = false;
    });

    _tts!.setErrorHandler((msg) {
      _isSpeaking = false;
      print('TTS Error: $msg');
    });

    _isInitialized = true;
  }

  /// Parler un texte avec la langue spécifiée
  Future<bool> speak(String text, String langCode) async {
    try {
      await initialize();

      // Arrêter si déjà en cours
      if (_isSpeaking) {
        await stop();
      }

      // Configurer la langue
      final locale = _getLocaleForLang(langCode);
      await _tts!.setLanguage(locale);

      // Parler
      final result = await _tts!.speak(text);
      return result == 1;
    } catch (e) {
      print('Erreur TTS: $e');
      return false;
    }
  }

  /// Arrêter la lecture
  Future<void> stop() async {
    if (_tts != null) {
      await _tts!.stop();
      _isSpeaking = false;
    }
  }

  /// Vérifier si le TTS est disponible pour une langue
  Future<bool> isLanguageAvailable(String langCode) async {
    await initialize();
    final locale = _getLocaleForLang(langCode);
    final result = await _tts!.isLanguageAvailable(locale);
    return result == 1;
  }

  /// Obtenir les voix disponibles
  Future<List<dynamic>> getVoices() async {
    await initialize();
    return await _tts!.getVoices;
  }

  /// Configurer la vitesse de lecture (0.0 - 1.0)
  Future<void> setSpeechRate(double rate) async {
    await initialize();
    await _tts!.setSpeechRate(rate);
  }

  /// Configurer la hauteur de la voix (0.5 - 2.0)
  Future<void> setPitch(double pitch) async {
    await initialize();
    await _tts!.setPitch(pitch);
  }

  /// Configurer le volume (0.0 - 1.0)
  Future<void> setVolume(double volume) async {
    await initialize();
    await _tts!.setVolume(volume);
  }

  /// Convertir le code langue en locale TTS
  String _getLocaleForLang(String langCode) {
    // Map des codes langue vers les locales TTS
    final localeMap = {
      'fr': 'fr-FR',
      'en': 'en-US',
      'ko': 'ko-KR',
      'es': 'es-ES',
      'de': 'de-DE',
      'it': 'it-IT',
      'pt': 'pt-PT',
      'ja': 'ja-JP',
      'zh': 'zh-CN',
      'ru': 'ru-RU',
      'ar': 'ar-SA',
      'hi': 'hi-IN',
      'nl': 'nl-NL',
      'pl': 'pl-PL',
      'tr': 'tr-TR',
      'vi': 'vi-VN',
      'th': 'th-TH',
      'id': 'id-ID',
    };

    return localeMap[langCode.toLowerCase()] ?? 'en-US';
  }

  /// Speak text and wait for completion before returning.
  Future<bool> speakAndWait(String text, String langCode) async {
    try {
      await initialize();

      if (_isSpeaking) {
        await stop();
      }

      await _tts!.awaitSpeakCompletion(true);

      final locale = _getLocaleForLang(langCode);
      await _tts!.setLanguage(locale);

      final result = await _tts!.speak(text);

      // Reset to non-blocking for normal usage
      await _tts!.awaitSpeakCompletion(false);

      return result == 1;
    } catch (e) {
      print('Erreur TTS (speakAndWait): $e');
      return false;
    }
  }

  /// Libérer les ressources
  void dispose() {
    _tts?.stop();
    _tts = null;
    _isInitialized = false;
    _isSpeaking = false;
  }

  /// Vérifier si le mode TTS gratuit est actif
  static bool get isFreeTTSEnabled => ApiConfig.useFreeTTS;
}
