import 'package:flutter_tts/flutter_tts.dart';
import 'audio_service.dart';
import 'audio_ports.dart';
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

class TtsRejected implements Exception {
  const TtsRejected(this.operation, this.language);

  final String operation;
  final String language;

  @override
  String toString() => 'Device speech rejected $operation for $language';
}

class FlutterTtsService implements AudioService, DeviceSpeech {
  FlutterTtsService({this.speechRate = 0.85, this.pitch = 1.0});

  final double speechRate;
  final double pitch;

  // One instance per language, created lazily — never pay the cost of
  // switching engines mid-session, and any langCode works (generic-language-
  // pairs epic; was two hardcoded fr/ko instances).
  final _ttsByLang = <String, FlutterTts>{};
  FlutterTts? _lastNativeVoice;
  Future<dynamic>? _engineSwitch;
  List<dynamic>? _availableEngines;
  int _playbackGeneration = 0;
  bool _disposed = false;

  bool _current(int generation) =>
      !_disposed && generation == _playbackGeneration;

  // Overlapping speaks (e.g. KO answer then FR question) each count.
  int _activeSpeaks = 0;

  /// Whether any utterance is still in flight — hands-free must not open the
  /// mic (which stops audio AND hears the speaker) while this is true.
  @override
  bool get isSpeaking => _activeSpeaks > 0;

  Future<FlutterTts?> _ttsFor(String langCode, int generation) async {
    final existing = _ttsByLang[langCode];
    if (existing != null) return existing;

    final tts = _lastNativeVoice = FlutterTts();
    if (_availableEngines == null) {
      List<dynamic> available;
      try {
        available = (await tts.getEngines as List?) ?? [];
      } catch (_) {
        available = [];
      }
      if (!_current(generation)) return null;
      _availableEngines = available;
    }
    if (!_current(generation)) return null;
    final preference = _enginePreferences[langCode] ?? _defaultEnginePreference;
    final engine = preference.firstWhere(
      _availableEngines!.contains,
      orElse: () => '',
    );
    if (engine.isNotEmpty) {
      // Selecting a different Android engine can reset its language.
      _nativeLang = null;
      final switching = _engineSwitch = tts.setEngine(engine);
      try {
        await switching;
      } finally {
        if (identical(_engineSwitch, switching)) _engineSwitch = null;
      }
      if (!_current(generation)) return null;
    }
    await tts.setVolume(1.0);
    if (!_current(generation)) return null;
    // speak() resolves when the utterance FINISHES, so callers (and
    // isSpeaking) can coordinate with real speech, not just its start.
    await tts.awaitSpeakCompletion(true);
    if (!_current(generation)) return null;
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

  Future<FlutterTts?> _configure(String langCode, int generation) async {
    if (!_current(generation)) return null;
    final tts = await _ttsFor(langCode, generation);
    if (tts == null || !_current(generation)) return null;
    if (_nativeLang == langCode) return tts;
    final sw = Stopwatch()..start();
    // The previous language is no longer known once a switch is dispatched.
    _nativeLang = null;
    final lang = Languages.speechLocaleFor(langCode);
    final result = await tts.setLanguage(lang);
    if (!_current(generation)) return null;
    if (result == 0) throw TtsRejected('setLanguage', lang);
    // Must set rate/pitch AFTER setLanguage — Android TTS resets them on language change.
    await tts.setSpeechRate(speechRate);
    if (!_current(generation)) return null;
    await tts.setPitch(pitch);
    if (!_current(generation)) return null;
    _nativeLang = langCode;
    sttLog(
      '[TTS] 🔥 voice switched to $langCode in ${sw.elapsedMilliseconds}ms',
    );
    return tts;
  }

  /// Pre-loads [langCode]'s voice on the shared engine so the next speak()
  /// in that language starts instantly. Call during idle windows (e.g. while
  /// the hands-free mic is listening); it produces no audio.
  @override
  Future<void> warmUp(String langCode) async {
    final generation = _playbackGeneration;
    try {
      await _serialized(() => _configure(langCode, generation));
    } on TtsRejected catch (error) {
      sttLog('[TTS] optional warm-up failed: $error');
    }
  }

  @override
  Future<void> speak(String text, String langCode, {String? voiceId}) async {
    final generation = _playbackGeneration;
    final tts = await _serialized(() => _configure(langCode, generation));
    if (tts == null || !_current(generation)) return;
    _activeSpeaks++;
    sttLog(
      '[TTS] ▶ speak start lang=$langCode "$text" (active=$_activeSpeaks)',
    );
    try {
      final result = await tts.speak(text);
      // The pinned native plugin reports rejection with 0. Other backends
      // may complete successfully without a numeric acknowledgement.
      if (result == 0 && _current(generation)) {
        throw TtsRejected('speak', langCode);
      }
    } finally {
      _activeSpeaks--;
      sttLog(
        '[TTS] ■ speak done  lang=$langCode "$text" (active=$_activeSpeaks)',
      );
    }
  }

  @override
  Future<void> stop() async {
    _playbackGeneration++;
    if (_disposed) return;
    if (_activeSpeaks > 0) {
      sttLog(
        '[TTS] ✋ stop() while $_activeSpeaks utterance(s) in flight — speech is being CUT OFF',
      );
    }
    final prior = _nativeOps;
    final engineSwitchPending = _engineSwitch != null;
    final stopping = _stopVoices();
    // The pinned plugin applies setLanguage before sending its reply. Android
    // drains early native requests in order when the engine becomes ready.
    // A later acknowledged stop therefore fences those synchronous mutations
    // even if their Dart replies never arrive. Engine initialization has its
    // own asynchronous callback and must still settle before a new voice.
    _nativeOps = stopping.then<void>((_) async {
      if (engineSwitchPending) await prior;
    }, onError: (Object _, StackTrace _) => prior);
    await stopping;
  }

  Future<void> _stopVoices() async {
    final voices = [
      ..._ttsByLang.values,
      if (_ttsByLang.isEmpty && _lastNativeVoice != null) _lastNativeVoice!,
    ];
    await Future.wait(
      voices.map((voice) async {
        if (await voice.stop() == 0) throw const TtsRejected('stop', '');
      }),
    );
  }

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _playbackGeneration++;
    final switching = _engineSwitch;
    try {
      await switching;
    } finally {
      await _stopVoices();
    }
  }
}
