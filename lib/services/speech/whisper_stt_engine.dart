import 'dart:typed_data';

import '../../core/languages.dart';
import 'stt_engine.dart';
import 'whisper_speech_service.dart';

/// Adapts on-device Whisper (whisper.cpp, ggml-base multilingual) to the
/// [SttEngine] contract. It transcribes every studied language with one model
/// and grades wrong answers as real transcripts.
///
/// Today it owns its own mic capture, so it's a mic owner (a fallback for when
/// the platform recognizer is unavailable or doesn't support the language).
/// Converting it to consume coordinator-fed PCM ([SttCapture.sharedPcm]) is
/// what will let it race in true parallel with other offline engines such as
/// sherpa-onnx — that refactor is the next step.
class WhisperSttEngine implements SttEngine {
  WhisperSttEngine(this._service);

  final WhisperSpeechService _service;

  @override
  String get id => 'whisper';

  @override
  SttCapture get capture => SttCapture.ownsMicrophone;

  @override
  bool get isReady => _service.isReady;

  @override
  bool supportsLanguage(String langCode) =>
      Languages.supported.contains(langCode);

  @override
  Future<void> prepare() => _service.ensureModel();

  @override
  Future<bool> start({
    required String langCode,
    required List<String> promptHints,
    required void Function(SttHypothesis) onHypothesis,
  }) {
    return _service.startListening(
      langCode: langCode,
      promptHints: promptHints,
      onFinal: (text, segmentMs) => onHypothesis(SttHypothesis(
        engineId: id,
        transcript: text,
        candidates: [text],
        confidence: 0.7,
        isFinal: true,
      )),
    );
  }

  @override
  void feed(Uint8List pcm16) {} // own capture today; sharedPcm is the next step

  @override
  Future<void> stop() => _service.stopListening();

  @override
  void dispose() => _service.dispose();
}
