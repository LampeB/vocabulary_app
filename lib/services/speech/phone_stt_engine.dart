import 'dart:async';

import '../../core/languages.dart';
import '../../core/utils/pcm_segmenter.dart';
import '../../core/utils/stt_debug_log.dart';
import 'phone_pcm_recognizer.dart';
import 'stt_engine.dart';

/// The phone's recognizer (Google on Android) as a SHARED engine: it
/// transcribes the very utterance our capture recorded, in parallel with
/// cloud Scribe and on-device Whisper (user decision 2026-10-02: "que tous
/// les moteurs se basent sur l'enregistrement"). Corpus on the SM-S908B:
/// 29/38 right, 0 wrong (9 empty, mostly one-syllable words), ~1s.
///
/// It is marked [requiresNetwork]: Google's service transcribes fed audio
/// online unless an offline pack is installed, so offline it would mostly
/// fail.
class PhoneSttEngine implements CancellablePcmSttEngine {
  PhoneSttEngine(this._recognizer);

  final PhonePcmRecognizer _recognizer;
  bool _ready = false;

  /// The platform service handles one session at a time.
  Future<void> _chain = Future.value();
  var _turnCancelled = Completer<PhonePcmTranscript>();

  @override
  String get id => 'phone';

  @override
  SttCapture get capture => SttCapture.sharedPcm;

  @override
  bool get requiresNetwork => true;

  @override
  bool get isReady => _ready;

  @override
  bool supportsLanguage(String langCode) =>
      Languages.supported.contains(langCode);

  @override
  Future<void> prepare() async {
    _ready = await _recognizer.isSupported();
  }

  @override
  Future<SttHypothesis?> recognize(
    PcmSegment segment, {
    required String langCode,
    required List<String> promptHints,
  }) {
    final turn = _turnCancelled;
    final result = _chain.then((_) async {
      if (turn.isCompleted) return null;
      final sw = Stopwatch()..start();
      final (:texts, :isFinal) = await Future.any([
        _recognizer.recognize(
          segment.bytes,
          Languages.speechLocaleFor(langCode),
        ),
        turn.future,
      ]);
      if (turn.isCompleted) return null;
      sttLog(
        '[PHN] ${segment.durationMs}ms in ${sw.elapsedMilliseconds}ms: '
        '$texts',
      );
      if (texts.isEmpty) return null;
      return SttHypothesis(
        engineId: id,
        transcript: texts.first,
        candidates: texts,
        confidence: isFinal ? 0.9 : 0.5,
        isFinal: isFinal,
      );
    });
    _chain = result.then((_) {}, onError: (_) {});
    return result;
  }

  @override
  Future<bool> start({
    required String langCode,
    required List<String> promptHints,
    required void Function(SttHypothesis) onHypothesis,
    void Function()? onSessionEnd,
  }) async => true; // shared engine — fed by the race's capture, never starts a mic

  @override
  Future<void> stop() async {
    _turnCancelled.complete((texts: const <String>[], isFinal: false));
    _turnCancelled = Completer<PhonePcmTranscript>();
    // New work waits for native teardown, independent of the old queue.
    _chain = _recognizer.cancel().catchError((Object error) {
      sttLog('[PHN] cancel failed: $error');
    });
    await _chain;
  }

  @override
  void dispose() => unawaited(stop());
}
