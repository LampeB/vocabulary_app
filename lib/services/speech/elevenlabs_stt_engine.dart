import 'dart:typed_data';

import '../../core/languages.dart';
import 'stt_engine.dart';

abstract interface class CloudSpeechCapture {
  Future<bool> startListening({
    required String langCode,
    required List<String> promptHints,
    required void Function(String text, int segmentMs) onFinal,
    void Function()? onSessionEnd,
  });

  Future<void> stopListening();
  void dispose();
}

/// Adapter that makes cloud ElevenLabs Scribe available to [SttRace]. It owns
/// the microphone while it captures one short answer, so Whisper runs only as
/// a sequential offline rescue after it releases the mic.
class ElevenLabsSttEngine implements SttEngine {
  ElevenLabsSttEngine(this._service);

  final CloudSpeechCapture _service;

  @override
  String get id => 'elevenlabs';

  @override
  SttCapture get capture => SttCapture.ownsMicrophone;

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
  void feed(Uint8List pcm16) {}

  @override
  Future<void> stop() => _service.stopListening();

  @override
  void dispose() => _service.dispose();
}
