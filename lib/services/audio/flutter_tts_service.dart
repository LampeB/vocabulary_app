import 'package:flutter_tts/flutter_tts.dart';
import 'audio_service.dart';

class FlutterTtsService implements AudioService {
  final _tts = FlutterTts();
  bool _initialized = false;

  Future<void> _init() async {
    if (_initialized) return;
    await _tts.setLanguage('fr-FR');
    await _tts.setSpeechRate(0.85);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    _initialized = true;
  }

  @override
  Future<void> speak(String text, String langCode, {String? voiceId}) async {
    await _init();
    final locale = langCode == 'ko' ? 'ko-KR' : 'fr-FR';
    await _tts.setLanguage(locale);
    await _tts.speak(text);
  }

  @override
  Future<void> stop() async => _tts.stop();

  @override
  Future<bool> isAvailable() async => true;

  @override
  void dispose() => _tts.stop();
}
