import 'package:flutter_tts/flutter_tts.dart';
import '../../config/api_config.dart';

/// Service TTS natif Flutter (gratuit, sans API key)
/// Utilise la synthèse vocale du système
class FlutterTtsService {
  FlutterTts? _tts;
  bool _isInitialized = false;
  bool _isSpeaking = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    _tts = FlutterTts();

    await _tts!.setVolume(1.0);
    await _tts!.setSpeechRate(0.5);
    await _tts!.setPitch(1.0);

    _tts!.setStartHandler(() {
      _isSpeaking = true;
    });

    _tts!.setCompletionHandler(() {
      _isSpeaking = false;
    });

    _tts!.setErrorHandler((msg) {
      _isSpeaking = false;
    });

    _isInitialized = true;
  }

  Future<bool> speak(String text, String langCode) async {
    try {
      await initialize();

      if (_isSpeaking) {
        await stop();
      }

      final locale = _getLocaleForLang(langCode);
      await _tts!.setLanguage(locale);

      final result = await _tts!.speak(text);
      return result == 1;
    } catch (e) {
      return false;
    }
  }

  Future<void> stop() async {
    if (_tts != null) {
      await _tts!.stop();
      _isSpeaking = false;
    }
  }

  Future<bool> isLanguageAvailable(String langCode) async {
    await initialize();
    final locale = _getLocaleForLang(langCode);
    final result = await _tts!.isLanguageAvailable(locale);
    return result == 1;
  }

  Future<List<dynamic>> getVoices() async {
    await initialize();
    return await _tts!.getVoices;
  }

  Future<void> setSpeechRate(double rate) async {
    await initialize();
    await _tts!.setSpeechRate(rate);
  }

  Future<void> setPitch(double pitch) async {
    await initialize();
    await _tts!.setPitch(pitch);
  }

  Future<void> setVolume(double volume) async {
    await initialize();
    await _tts!.setVolume(volume);
  }

  String _getLocaleForLang(String langCode) {
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

      await _tts!.awaitSpeakCompletion(false);

      return result == 1;
    } catch (e) {
      return false;
    }
  }

  void dispose() {
    _tts?.stop();
    _tts = null;
    _isInitialized = false;
    _isSpeaking = false;
  }

  static bool get isFreeTTSEnabled => ApiConfig.useFreeTTS;
}
