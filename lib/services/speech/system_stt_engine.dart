import 'dart:typed_data';

import '../../core/languages.dart';
import 'speech_recognition_service.dart';
import 'stt_engine.dart';

/// Adapts the platform recognizer (Google on Android / Apple on iOS) to the
/// [SttEngine] contract. It owns the mic through the plugin, so it can't run
/// alongside another mic owner or a shared-PCM pool — the [SttEngineRegistry]
/// enforces that. In field logs this is the fastest, most accurate engine for
/// the languages it supports, so register it first (priority order).
class SystemSttEngine implements SttEngine {
  SystemSttEngine(this._service, {Set<String>? languages})
      : _languages = languages ?? Languages.supported.toSet();

  final SpeechRecognitionService _service;
  final Set<String> _languages;
  bool _ready = false;

  // The service exposes a single onListeningDone callback, owned by the quiz
  // screen's legacy path. While racing we borrow it to surface session-end to
  // the race (the platform recognizer closes after one utterance) and restore
  // the original on stop() so the legacy path keeps working afterwards.
  void Function()? _restoreDone;
  bool _hooked = false;

  @override
  String get id => 'system';

  @override
  SttCapture get capture => SttCapture.ownsMicrophone;

  @override
  bool get isReady => _ready;

  @override
  bool supportsLanguage(String langCode) => _languages.contains(langCode);

  @override
  Future<void> prepare() async {
    _ready = await _service.initialize();
  }

  @override
  Future<bool> start({
    required String langCode,
    required List<String> promptHints,
    required void Function(SttHypothesis) onHypothesis,
    void Function()? onSessionEnd,
  }) {
    if (onSessionEnd != null) {
      if (!_hooked) {
        _restoreDone = _service.onListeningDone;
        _hooked = true;
      }
      _service.onListeningDone = onSessionEnd;
    }
    return _service.startListening(
      langCode: langCode,
      onResult: (primary, candidates) => onHypothesis(SttHypothesis(
        engineId: id,
        transcript: primary,
        candidates: candidates,
        confidence: 0.9,
        isFinal: true,
      )),
      onPartial: (primary, candidates) => onHypothesis(SttHypothesis(
        engineId: id,
        transcript: primary,
        candidates: candidates,
        confidence: 0.5,
        isFinal: false,
      )),
    );
  }

  @override
  void feed(Uint8List pcm16) {} // owns its own mic — nothing to feed

  @override
  Future<void> stop() {
    if (_hooked) {
      _service.onListeningDone = _restoreDone;
      _hooked = false;
      _restoreDone = null;
    }
    return _service.stopListening();
  }

  @override
  void dispose() => _service.dispose();
}
