import '../../core/utils/pcm_segmenter.dart';

/// How an STT engine gets its audio — the key constraint for racing engines in
/// parallel. On Android/iOS only ONE component can own the microphone at a
/// time, so [ownsMicrophone] engines can't run alongside each other or a
/// [sharedPcm] capture. [sharedPcm] engines accept audio the coordinator feeds
/// them, so several of them CAN run on one shared capture (true parallelism).
enum SttCapture { ownsMicrophone, sharedPcm }

/// One recognition guess from an engine — partial or final. The race validates
/// each guess's [candidates] against the quiz's accepted answers; since the
/// answer is known, we don't fuse transcripts, we just take the first guess
/// (from any engine) that validates.
class SttHypothesis {
  const SttHypothesis({
    required this.engineId,
    required this.transcript,
    required this.candidates,
    this.confidence = 0.0,
    this.isFinal = true,
  });

  /// The engine that produced this guess.
  final String engineId;

  /// The engine's top interpretation.
  final String transcript;

  /// Every interpretation to grade (top pick + alternates); the top pick is
  /// often not the right one while an alternate is.
  final List<String> candidates;

  /// The engine's own confidence in [transcript] (0–1), when it reports one.
  final double confidence;

  /// A finished utterance vs a live partial. Partials drive UI feedback and
  /// can win the race early (a validating partial ends the turn immediately).
  final bool isFinal;
}

/// A pluggable speech-to-text engine that can enter the recognition race.
/// Add a new engine (e.g. sherpa-onnx) by implementing this and registering it
/// with the [SttEngineRegistry] — no other code changes. Remove one by
/// unregistering it. Engines are ranked/selected by the registry, not here.
abstract interface class SttEngine {
  /// Stable id for logs and registry keys (e.g. 'system', 'whisper', 'sherpa').
  String get id;

  /// Whether this engine opens its own mic or consumes coordinator-fed PCM.
  SttCapture get capture;

  /// True once the engine can recognize (model loaded / platform initialised).
  bool get isReady;

  /// True for cloud engines: they are never selected while the device is
  /// offline (user rule 2026-10-02 — "hors ligne on n'active pas les moteurs
  /// en ligne").
  bool get requiresNetwork;

  /// Content languages this engine can transcribe well (langCodes, e.g. 'fr').
  bool supportsLanguage(String langCode);

  /// Loads models / initialises the platform recognizer. Idempotent.
  Future<void> prepare();

  /// Begins recognizing [langCode]. Every partial/final guess is delivered to
  /// [onHypothesis]. [promptHints] biases decoders toward the expected answers.
  /// Returns false if it could not start (permission, not ready, mic busy).
  ///
  /// [onSessionEnd] fires when the engine ends its OWN listening session
  /// before being stopped (platform recognizers close after one utterance —
  /// a wrong answer would otherwise leave a dead mic for the rest of the
  /// race window; field log 2026-07-19). Continuous engines that listen until
  /// stopped never call it.
  Future<bool> start({
    required String langCode,
    required List<String> promptHints,
    required void Function(SttHypothesis) onHypothesis,
    void Function()? onSessionEnd,
  });

  /// Transcribes one utterance captured by the race's shared microphone
  /// ([SttCapture.sharedPcm] engines only). Returns null when the engine
  /// heard nothing usable (silence, hallucination, service failure).
  /// Mic owners return null — they capture themselves via [start].
  Future<SttHypothesis?> recognize(
    PcmSegment segment, {
    required String langCode,
    required List<String> promptHints,
  });

  /// Stops recognition and releases the mic/decoder for this turn.
  Future<void> stop();

  /// Frees all resources for good.
  void dispose();
}
