import 'dart:typed_data';

import '../../core/languages.dart';
import '../../core/utils/pcm_segmenter.dart';
import 'stt_engine.dart';

abstract interface class CloudSpeechCapture {
  Future<bool> startListening({
    required String langCode,
    required List<String> promptHints,
    required void Function(String text, int segmentMs) onFinal,
    void Function()? onSessionEnd,
  });

  Future<void> stopListening();

  /// Sends one utterance captured by the race's shared microphone to Scribe.
  /// Returns the cleaned transcript, or null when Scribe heard nothing.
  /// Throws on a transport/service failure (offline, timeout, 5xx).
  Future<String?> transcribeSegment({
    required Uint8List pcm16,
    required String langCode,
    required String expectedWord,
  });
  void dispose();
}

/// Adapter that makes cloud ElevenLabs Scribe available to [SttRace]. It
/// consumes the race's shared capture, so it runs in PARALLEL with the other
/// shared engines (on-device Whisper) on the very same utterance. It needs the
/// network, so the registry never selects it offline.
class ElevenLabsSttEngine implements SttEngine {
  ElevenLabsSttEngine(this._service);

  final CloudSpeechCapture _service;

  @override
  String get id => 'elevenlabs';

  @override
  SttCapture get capture => SttCapture.sharedPcm;

  @override
  bool get requiresNetwork => true;

  @override
  bool get isReady => true;

  @override
  bool supportsLanguage(String langCode) =>
      Languages.supported.contains(langCode);

  @override
  Future<void> prepare() async {}

  @override
  Future<bool> start({
    required String langCode,
    required List<String> promptHints,
    required void Function(SttHypothesis) onHypothesis,
    void Function()? onSessionEnd,
  }) =>
      _service.startListening(
        langCode: langCode,
        promptHints: promptHints,
        onSessionEnd: onSessionEnd,
        onFinal: (text, _) => onHypothesis(SttHypothesis(
          engineId: id,
          transcript: text,
          candidates: [text],
          confidence: 0.95,
          isFinal: true,
        )),
      );

  @override
  Future<SttHypothesis?> recognize(
    PcmSegment segment, {
    required String langCode,
    required List<String> promptHints,
  }) async {
    final text = await _service.transcribeSegment(
      pcm16: segment.bytes,
      langCode: langCode,
      expectedWord: promptHints.isEmpty ? '' : promptHints.first,
    );
    if (text == null) return null;
    return SttHypothesis(
      engineId: id,
      transcript: text,
      candidates: [text],
      confidence: 0.95,
      isFinal: true,
    );
  }

  @override
  Future<void> stop() => _service.stopListening();

  @override
  void dispose() => _service.dispose();
}
