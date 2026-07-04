import 'package:flutter_tts/flutter_tts.dart';
import 'audio_service.dart';
import '../../core/languages.dart';

// Priority-ordered engine IDs per language — device-quality tuning, the first
// engine found on the device wins. Languages without an entry fall back to
// Google's engine (ships the widest language coverage), so a NEW language
// needs no entry here unless a better engine is known for it.
const _enginePreferences = <String, List<String>>{
  // Samsung (best Korean prosody on Galaxy) → Google → system default
  'ko': ['com.samsung.SMT', 'com.google.android.tts'],
  // Google ships French out of the box; Samsung only with a language pack
  'fr': ['com.google.android.tts', 'com.samsung.SMT'],
};
const _defaultEnginePreference = ['com.google.android.tts'];

class FlutterTtsService implements AudioService {
  FlutterTtsService({this.speechRate = 0.85, this.pitch = 1.0});

  final double speechRate;
  final double pitch;

  // One instance per language, created lazily — never pay the cost of
  // switching engines mid-session, and any langCode works (generic-language-
  // pairs epic; was two hardcoded fr/ko instances).
  final _ttsByLang = <String, FlutterTts>{};
  List<dynamic>? _availableEngines;

  Future<FlutterTts> _ttsFor(String langCode) async {
    final existing = _ttsByLang[langCode];
    if (existing != null) return existing;

    final tts = FlutterTts();
    if (_availableEngines == null) {
      try {
        _availableEngines = (await tts.getEngines as List?) ?? [];
      } catch (_) {
        _availableEngines = [];
      }
    }
    final preference = _enginePreferences[langCode] ?? _defaultEnginePreference;
    final engine = preference.firstWhere(
      _availableEngines!.contains,
      orElse: () => '',
    );
    if (engine.isNotEmpty) await tts.setEngine(engine);
    await tts.setVolume(1.0);
    _ttsByLang[langCode] = tts;
    return tts;
  }

  @override
  Future<void> speak(String text, String langCode, {String? voiceId}) async {
    final tts = await _ttsFor(langCode);
    await tts.setLanguage(Languages.speechLocaleFor(langCode));
    // Must set rate/pitch AFTER setLanguage — Android TTS resets them on language change.
    await tts.setSpeechRate(speechRate);
    await tts.setPitch(pitch);
    await tts.speak(text);
  }

  @override
  Future<void> stop() async {
    for (final tts in _ttsByLang.values) {
      await tts.stop();
    }
  }

  @override
  Future<bool> isAvailable() async => true;

  @override
  void dispose() {
    for (final tts in _ttsByLang.values) {
      tts.stop();
    }
  }
}
