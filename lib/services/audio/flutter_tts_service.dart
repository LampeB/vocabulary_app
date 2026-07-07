import 'package:flutter_tts/flutter_tts.dart';
import 'audio_service.dart';
import '../../core/languages.dart';
import '../../core/utils/stt_debug_log.dart';

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

  // Overlapping speaks (e.g. KO answer then FR question) each count.
  int _activeSpeaks = 0;

  /// Whether any utterance is still in flight — hands-free must not open the
  /// mic (which stops audio AND hears the speaker) while this is true.
  bool get isSpeaking => _activeSpeaks > 0;

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
    // speak() resolves when the utterance FINISHES, so callers (and
    // isSpeaking) can coordinate with real speech, not just its start.
    await tts.awaitSpeakCompletion(true);
    _ttsByLang[langCode] = tts;
    return tts;
  }

  // flutter_tts shares ONE native TextToSpeech engine across all Dart
  // instances, and switching its language (fr↔ko) costs 1–3.7s on device
  // (field log 2026-07-07 22:30: "singe" took 3.7s to become audible after
  // a Korean utterance). Track what the native engine is configured for so
  // redundant switches are skipped, and let callers pre-load the next
  // language during idle windows via [warmUp].
  String? _nativeLang;
  Future<void> _nativeOps = Future.value();

  /// Serializes native-engine configuration calls — a warmUp racing a speak
  /// would interleave setLanguage/setSpeechRate across the shared engine.
  Future<T> _serialized<T>(Future<T> Function() action) {
    final result = _nativeOps.then((_) => action());
    _nativeOps = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<FlutterTts> _configure(String langCode) async {
    final tts = await _ttsFor(langCode);
    if (_nativeLang == langCode) return tts;
    final sw = Stopwatch()..start();
    await tts.setLanguage(Languages.speechLocaleFor(langCode));
    // Must set rate/pitch AFTER setLanguage — Android TTS resets them on language change.
    await tts.setSpeechRate(speechRate);
    await tts.setPitch(pitch);
    _nativeLang = langCode;
    sttLog('[TTS] 🔥 voice switched to $langCode in ${sw.elapsedMilliseconds}ms');
    return tts;
  }

  /// Pre-loads [langCode]'s voice on the shared engine so the next speak()
  /// in that language starts instantly. Call during idle windows (e.g. while
  /// the hands-free mic is listening); it produces no audio.
  Future<void> warmUp(String langCode) =>
      _serialized(() async => _configure(langCode));

  @override
  Future<void> speak(String text, String langCode, {String? voiceId}) async {
    final tts = await _serialized(() => _configure(langCode));
    _activeSpeaks++;
    sttLog('[TTS] ▶ speak start lang=$langCode "$text" (active=$_activeSpeaks)');
    try {
      await tts.speak(text);
    } finally {
      _activeSpeaks--;
      sttLog('[TTS] ■ speak done  lang=$langCode "$text" (active=$_activeSpeaks)');
    }
  }

  @override
  Future<void> stop() async {
    if (_activeSpeaks > 0) {
      sttLog('[TTS] ✋ stop() while $_activeSpeaks utterance(s) in flight — speech is being CUT OFF');
    }
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
