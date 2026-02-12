import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_error.dart';

/// Service de reconnaissance vocale pour les réponses du quiz
class SpeechRecognitionService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;
  String? _lastError;

  bool get isListening => _isListening;
  bool get isInitialized => _isInitialized;
  String? get lastError => _lastError;

  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      _isInitialized = await _speech.initialize(
        onError: (SpeechRecognitionError error) {
          _lastError = error.errorMsg;
          _isListening = false;
        },
        onStatus: (status) {
          if (status == 'notListening' || status == 'done') {
            _isListening = false;
          } else if (status == 'listening') {
            _isListening = true;
          }
        },
      );

      if (!_isInitialized) {
        _lastError = 'Service de reconnaissance vocale non disponible';
      }

      return _isInitialized;
    } catch (e) {
      _lastError = e.toString();
      return false;
    }
  }

  Future<bool> startListening({
    required String langCode,
    required Function(String) onResult,
    Function(double)? onConfidence,
  }) async {
    if (!_isInitialized) return false;

    if (_isListening || _speech.isListening) {
      await _speech.stop();
      _isListening = false;
      await Future.delayed(const Duration(milliseconds: 200));
    }

    try {
      final localeId = _getLocaleId(langCode);

      await _speech.listen(
        onResult: (result) {
          if (result.finalResult) {
            onResult(result.recognizedWords);
            onConfidence?.call(result.confidence);
          }
        },
        localeId: localeId,
        listenOptions: stt.SpeechListenOptions(
          cancelOnError: true,
          listenMode: stt.ListenMode.dictation,
        ),
        listenFor: const Duration(seconds: 5),
        pauseFor: const Duration(seconds: 2),
      );

      _isListening = true;
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> stopListening() async {
    if (_isListening) {
      await _speech.stop();
      _isListening = false;
    }
  }

  Future<void> cancelListening() async {
    if (_isListening) {
      await _speech.cancel();
      _isListening = false;
    }
  }

  String _getLocaleId(String langCode) {
    switch (langCode.toLowerCase()) {
      case 'fr':
        return 'fr-FR';
      case 'ko':
        return 'ko-KR';
      case 'en':
        return 'en-US';
      case 'es':
        return 'es-ES';
      case 'de':
        return 'de-DE';
      case 'it':
        return 'it-IT';
      case 'ja':
        return 'ja-JP';
      case 'zh':
        return 'zh-CN';
      default:
        return 'en-US';
    }
  }

  Future<bool> isLanguageAvailable(String langCode) async {
    if (!_isInitialized) {
      await initialize();
    }

    final locales = await _speech.locales();
    final localeId = _getLocaleId(langCode);

    return locales.any((l) => l.localeId == localeId);
  }

  Future<List<String>> getAvailableLanguages() async {
    if (!_isInitialized) {
      await initialize();
    }

    final locales = await _speech.locales();
    return locales.map((l) => l.localeId).toList();
  }

  void dispose() {
    _speech.stop();
    _isInitialized = false;
    _isListening = false;
  }
}
