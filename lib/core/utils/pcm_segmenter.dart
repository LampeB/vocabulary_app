import 'dart:math' as math;
import 'dart:typed_data';

/// A completed speech segment: pre-roll + speech + tail, 16kHz mono PCM16.
class PcmSegment {
  const PcmSegment(this.bytes, this.durationMs, this.peakRms);
  final Uint8List bytes;
  final int durationMs;
  final double peakRms;
}

/// Energy-based voice activity segmenter for a raw PCM16 mono stream.
///
/// This is OUR endpointing — the whole reason the Whisper pipeline exists.
/// Vendor recognizers decide "was that speech?" opaquely and drop short
/// words in noise (field logs 2026-07-08/09); here the rules are explicit,
/// logged, and tunable:
///
/// - A rolling noise-floor estimate adapts to the room (EMA of non-speech
///   frame RMS), so "speech" means "well above THIS room's floor", not an
///   absolute level.
/// - A pre-roll ring buffer is always kept, so the first syllable is never
///   clipped — the classic short-word killer.
/// - Speech ends after [silenceEndMs] below the floor-relative threshold,
///   or hard-stops at [maxUtteranceMs].
class PcmSegmenter {
  PcmSegmenter({
    this.sampleRate = 16000,
    this.frameMs = 30,
    this.preRollMs = 400,
    this.silenceEndMs = 700,
    this.maxUtteranceMs = 6000,
    this.startFactor = 3.0,
    this.endFactor = 1.8,
    this.minStartRms = 900,
    this.minSpeechMs = 200,
  });

  final int sampleRate;
  final int frameMs;
  final int preRollMs;
  final int silenceEndMs;
  final int maxUtteranceMs;

  /// Speech starts when frame RMS exceeds noiseFloor * [startFactor]
  /// (and at least [minStartRms], so a dead-quiet room doesn't trigger on
  /// breathing).
  final double startFactor;

  /// Speech ends when frame RMS falls below noiseFloor * [endFactor].
  final double endFactor;
  final double minStartRms;

  /// Segments with less speech than this are discarded as clicks/pops.
  final int minSpeechMs;

  final _pending = BytesBuilder(copy: true);
  final _preRoll = <Uint8List>[];
  final _speech = BytesBuilder(copy: true);

  double _noiseFloor = 0;
  bool _floorSeeded = false;
  bool _inSpeech = false;
  int _speechFrames = 0;
  int _silentFrames = 0;
  int _framesSinceSpeechStart = 0;
  double _peakRms = 0;

  int get _frameBytes => sampleRate * frameMs ~/ 1000 * 2;
  int get _preRollFrames => (preRollMs / frameMs).ceil();
  int get _silenceEndFrames => (silenceEndMs / frameMs).ceil();
  int get _maxUtteranceFrames => (maxUtteranceMs / frameMs).ceil();

  /// Current adaptive noise floor (RMS) — exposed for telemetry.
  double get noiseFloor => _noiseFloor;
  bool get inSpeech => _inSpeech;

  static double frameRms(Uint8List frame) {
    final samples = frame.buffer.asInt16List(
        frame.offsetInBytes, frame.lengthInBytes ~/ 2);
    if (samples.isEmpty) return 0;
    double sum = 0;
    for (final s in samples) {
      sum += s * s;
    }
    return math.sqrt(sum / samples.length);
  }

  /// Feeds a chunk of streamed PCM16 bytes; returns any segments that
  /// COMPLETED during this chunk (usually empty or one).
  List<PcmSegment> feed(Uint8List chunk) {
    _pending.add(chunk);
    final out = <PcmSegment>[];
    while (_pending.length >= _frameBytes) {
      final buffered = _pending.takeBytes();
      final frame = Uint8List.sublistView(buffered, 0, _frameBytes);
      if (buffered.length > _frameBytes) {
        _pending.add(Uint8List.sublistView(buffered, _frameBytes));
      }
      final seg = _processFrame(Uint8List.fromList(frame));
      if (seg != null) out.add(seg);
    }
    return out;
  }

  PcmSegment? _processFrame(Uint8List frame) {
    final rms = frameRms(frame);

    if (!_floorSeeded) {
      _noiseFloor = rms;
      _floorSeeded = true;
    }

    if (!_inSpeech) {
      final threshold =
          (_noiseFloor * startFactor).clamp(minStartRms, double.infinity);
      if (rms >= threshold) {
        _inSpeech = true;
        _speechFrames = 1;
        _silentFrames = 0;
        _framesSinceSpeechStart = 0;
        _peakRms = rms;
        _speech.clear();
        for (final f in _preRoll) {
          _speech.add(f);
        }
        _speech.add(frame);
        return null;
      }
      // Non-speech frame: adapt the floor slowly (EMA) and keep pre-roll.
      _noiseFloor = _noiseFloor * 0.95 + rms * 0.05;
      _preRoll.add(frame);
      if (_preRoll.length > _preRollFrames) _preRoll.removeAt(0);
      return null;
    }

    // In speech.
    _speech.add(frame);
    _framesSinceSpeechStart++;
    if (rms > _peakRms) _peakRms = rms;
    // The end threshold needs a floor of its own: in a dead-quiet room the
    // noise floor is ~0 and `rms < 0` would never be true — the utterance
    // would only ever end at maxUtteranceMs.
    final endThreshold =
        math.max(_noiseFloor * endFactor, minStartRms / 3);
    if (rms < endThreshold) {
      _silentFrames++;
    } else {
      _silentFrames = 0;
      _speechFrames++;
    }

    final endedBySilence = _silentFrames >= _silenceEndFrames;
    final endedByLength = _framesSinceSpeechStart >= _maxUtteranceFrames;
    if (!endedBySilence && !endedByLength) return null;

    _inSpeech = false;
    _preRoll.clear();
    final bytes = _speech.takeBytes();
    final durationMs = bytes.length ~/ 2 * 1000 ~/ sampleRate;
    final speechMs = _speechFrames * frameMs;
    final peak = _peakRms;
    _speechFrames = 0;
    _silentFrames = 0;
    if (speechMs < minSpeechMs) return null; // click/pop — discard
    return PcmSegment(bytes, durationMs, peak);
  }

  /// Flushes an in-progress utterance (stream ended mid-speech).
  PcmSegment? flush() {
    if (!_inSpeech) return null;
    _inSpeech = false;
    final bytes = _speech.takeBytes();
    final durationMs = bytes.length ~/ 2 * 1000 ~/ sampleRate;
    final speechMs = _speechFrames * frameMs;
    _speechFrames = 0;
    _silentFrames = 0;
    _preRoll.clear();
    if (speechMs < minSpeechMs) return null;
    return PcmSegment(bytes, durationMs, _peakRms);
  }
}
