import 'dart:async' show Completer;

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
  Future<void>? _stopping;
  Future<void>? _nativeDisposal;

  bool _current(int generation) =>
      !_disposed && generation == _playbackGeneration;

  final _pendingSpeaks = <Completer<void>>{};
  Completer<void>? _activeSpeak;

  /// Whether any utterance is still in flight — hands-free must not open the
  /// mic (which stops audio AND hears the speaker) while this is true.
  @override
  bool get isSpeaking => _activeSpeak != null;

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

  /// Keeps configuration and the complete utterance in one queue slot. Native
  /// TTS has one speech-completion reply, and warm-up changes the same voice.
  Future<T> _serialized<T>(
    Future<T> Function() action, {
    Future<T>? interruption,
  }) {
    final queued = _nativeOps.then((_) => action());
    final result = interruption == null
        ? queued
        : Future.any<T>([queued, interruption]);
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
    if (_disposed) return;
    final generation = _playbackGeneration;
    final interrupted = Completer<void>();
    _pendingSpeaks.add(interrupted);
    try {
      await _serialized(
        () => _speak(text, langCode, generation, interrupted),
        interruption: interrupted.future.then<void>(
          (_) => throw const AudioPlaybackCancelled(),
        ),
      );
    } finally {
      _pendingSpeaks.remove(interrupted);
    }
  }

  Future<void> _speak(
    String text,
    String langCode,
    int generation,
    Completer<void> request,
  ) async {
    final tts = await _configure(langCode, generation);
    if (tts == null || !_current(generation)) {
      await (_nativeDisposal ?? _stopping);
      throw const AudioPlaybackCancelled();
    }
    _activeSpeak = request;
    sttLog('[TTS] ▶ speak start lang=$langCode "$text"');
    try {
      final result = await tts.speak(text);
      if (!_current(generation)) {
        await (_nativeDisposal ?? _stopping);
        throw const AudioPlaybackCancelled();
      }
      // The pinned native plugin reports rejection with 0. Other backends
      // may complete successfully without a numeric acknowledgement.
      if (result == 0) throw TtsRejected('speak', langCode);
    } finally {
      if (identical(_activeSpeak, request)) _activeSpeak = null;
      sttLog('[TTS] ■ speak done lang=$langCode "$text"');
    }
  }

  @override
  Future<void> stop() {
    if (_disposed) return dispose();
    return _stopping ??= _stopForReplay().whenComplete(() => _stopping = null);
  }

  Future<void> _stopForReplay() {
    _playbackGeneration++;
    final prior = _nativeOps;
    final switching = _engineSwitch;
    final stopping = _stopSpeechRequests();
    // The pinned plugin applies setLanguage before sending its reply. Android
    // drains early native requests in order when the engine becomes ready.
    // A later acknowledged stop therefore fences those synchronous mutations
    // even if their Dart replies never arrive. Engine initialization has its
    // own asynchronous callback and must still settle before a new voice.
    _nativeOps = stopping.then<void>((_) async {
      try {
        await switching;
      } catch (_) {
        // The interrupted configuration owns this engine-switch error.
      }
    }, onError: (Object _, StackTrace _) => prior);
    return stopping;
  }

  Future<void> _stopSpeechRequests() async {
    final interrupted = _pendingSpeaks.toList(growable: false);
    await _stopVoices();
    // iOS acknowledges stop but can leave the interrupted speak reply open.
    // Retire only these utterances once native stop is confirmed.
    for (final speech in interrupted) {
      if (_pendingSpeaks.remove(speech)) {
        if (identical(_activeSpeak, speech)) _activeSpeak = null;
        speech.complete();
      }
    }
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
  Future<void> dispose() {
    if (!_disposed) {
      _disposed = true;
      _playbackGeneration++;
    }
    return _nativeDisposal ??= _disposeEngine().onError((
      Object error,
      StackTrace stack,
    ) {
      _nativeDisposal = null;
      Error.throwWithStackTrace(error, stack);
    });
  }

  Future<void> _disposeEngine() async {
    final stopping = _stopping;
    final switching = _engineSwitch;
    if (switching == null && stopping != null) return stopping;
    try {
      await switching;
    } finally {
      await stopping;
      await _stopSpeechRequests();
    }
  }
}
