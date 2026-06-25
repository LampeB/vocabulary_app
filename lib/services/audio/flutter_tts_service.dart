import 'package:flutter_tts/flutter_tts.dart';
import 'audio_service.dart';

// Priority-ordered engine IDs per language.
// The first engine found on the device wins.
//
// Korean:  Samsung (best prosody on Galaxy) → Google → system default
// French:  Google → Samsung (no French pack) → system default
const _koEnginePreference = [
  'com.samsung.SMT',        // Galaxy devices — native Korean quality
  'com.google.android.tts', // All other Android
];
const _frEnginePreference = [
  'com.google.android.tts', // Ships French out of the box
  'com.samsung.SMT',        // Only if the user installed the French language pack
];

class FlutterTtsService implements AudioService {
  FlutterTtsService({this.speechRate = 0.85, this.pitch = 1.0});

  final double speechRate;
  final double pitch;

  // Two separate instances so we never pay the cost of switching engines
  // mid-session.
  final _koTts = FlutterTts();
  final _frTts = FlutterTts();
  bool _initialized = false;

  Future<void> _init() async {
    if (_initialized) return;

    List<dynamic> available = [];
    try {
      available = (await _koTts.getEngines as List?) ?? [];
    } catch (_) {}

    final koEngine = _koEnginePreference.firstWhere(
      available.contains,
      orElse: () => '',
    );
    final frEngine = _frEnginePreference.firstWhere(
      available.contains,
      orElse: () => '',
    );

    if (koEngine.isNotEmpty) await _koTts.setEngine(koEngine);
    if (frEngine.isNotEmpty) await _frTts.setEngine(frEngine);

    await _koTts.setVolume(1.0);
    await _frTts.setVolume(1.0);
    _initialized = true;
  }

  @override
  Future<void> speak(String text, String langCode, {String? voiceId}) async {
    await _init();
    final isKorean = langCode == 'ko';
    final tts    = isKorean ? _koTts : _frTts;
    final locale = isKorean ? 'ko-KR' : 'fr-FR';
    await tts.setLanguage(locale);
    // Must set rate/pitch AFTER setLanguage — Android TTS resets them on language change.
    await tts.setSpeechRate(speechRate);
    await tts.setPitch(pitch);
    await tts.speak(text);
  }

  @override
  Future<void> stop() async {
    await _koTts.stop();
    await _frTts.stop();
  }

  @override
  Future<bool> isAvailable() async => true;

  @override
  void dispose() {
    _koTts.stop();
    _frTts.stop();
  }
}
