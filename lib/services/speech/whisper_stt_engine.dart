import '../../core/languages.dart';
import '../../core/utils/pcm_segmenter.dart';
import 'stt_engine.dart';
import 'whisper_speech_service.dart';

/// Adapts on-device Whisper (whisper.cpp, ggml-base multilingual) to the
/// [SttEngine] contract. It transcribes every studied language with one model
/// and grades wrong answers as real transcripts.
///
/// It consumes the race's shared capture ([SttCapture.sharedPcm]), so it runs
/// in parallel with cloud Scribe online and stands alone offline — never as a
/// slow sequential lane after another engine's window.
class WhisperSttEngine implements SttEngine {
  WhisperSttEngine(this._service);

  final WhisperSpeechCapture _service;

  @override
  String get id => 'whisper';

  @override
  SttCapture get capture => SttCapture.sharedPcm;

  @override
  bool get requiresNetwork => false;

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
    // Ignored: Whisper listens continuously until stopped, so its session
    // never self-ends.
    void Function()? onSessionEnd,
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
  Future<SttHypothesis?> recognize(
    PcmSegment segment, {
    required String langCode,
    required List<String> promptHints,
  }) async {
    final text = await _service.transcribeSegment(
      pcm16: segment.bytes,
      langCode: langCode,
      promptHints: promptHints,
    );
    if (text == null) return null;
    return SttHypothesis(
      engineId: id,
      transcript: text,
      candidates: [text],
      confidence: 0.7,
      isFinal: true,
    );
  }

  @override
  Future<void> stop() => _service.stopListening();

  @override
  void dispose() => _service.dispose();
}
