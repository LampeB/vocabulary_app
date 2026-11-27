import 'dart:async';
import 'dart:typed_data';

import '../../core/utils/pcm_segmenter.dart';
import '../../core/utils/stt_debug_log.dart';
import 'pcm_microphone.dart';

/// One open microphone window of a [PcmCaptureSource].
abstract interface class PcmCaptureSession {
  /// The user is speaking right now (an utterance is being captured).
  bool get inSpeech;

  /// Closes the mic. With [flush], an utterance still in progress is cut
  /// and returned instead of being thrown away — the answer someone was
  /// saying when the window ended is still graded (field log 2026-10-02:
  /// four answers lost mid-word at the deadline).
  Future<PcmSegment?> close({bool flush = false});
}

/// Opens microphone windows that deliver whole utterances. Several
/// [SttCapture.sharedPcm] engines transcribe each utterance in parallel.
abstract interface class PcmCaptureSource {
  /// Opens the mic. Returns null when it could not open (permission denied,
  /// mic busy). Opening a new window silences any previous one first.
  Future<PcmCaptureSession?> open({
    required void Function(bool inSpeech) onSpeechChange,
    required void Function(PcmSegment segment) onSegment,
  });
}

/// The race's single microphone: one capture + one endpointing decision,
/// fanned out to every shared engine. Engines therefore agree on what "the
/// answer" was, and the UI can tell the learner exactly when their voice was
/// detected.
class SharedPcmCapture implements PcmCaptureSource {
  SharedPcmCapture({
    PcmMicrophone? microphone,
    PcmSegmenter Function()? segmenterFactory,
  })  : _microphone = microphone ?? RecordPcmMicrophone(),
        _segmenterFactory = segmenterFactory ?? _defaultSegmenter;

  /// 500ms of silence ends an answer: Scribe kept 38/38 corpus words at
  /// 450ms, Whisper's conservative setting was 700ms. An answer is a word or
  /// two, so utterances hard-stop at 3s (longer is ambient conversation).
  static PcmSegmenter _defaultSegmenter() =>
      PcmSegmenter(silenceEndMs: 500, maxUtteranceMs: 3000);

  final PcmMicrophone _microphone;
  final PcmSegmenter Function() _segmenterFactory;
  _Session? _current;
  Future<void>? _stopping;
  int _request = 0;
  bool _disposed = false;

  @override
  Future<PcmCaptureSession?> open({
    required void Function(bool inSpeech) onSpeechChange,
    required void Function(PcmSegment segment) onSegment,
  }) async {
    final request = ++_request;
    bool cancelled() => _disposed || request != _request;
    await _current?.close();
    await _stopping;
    if (cancelled()) return null;
    final permitted = await _microphone.hasPermission();
    if (cancelled()) return null;
    if (!permitted) {
      sttLog('[CAP] ❌ mic permission denied');
      return null;
    }
    final session =
        _Session(this, _segmenterFactory(), onSpeechChange, onSegment);
    _current = session;
    final starting =
        session._starting = Future.sync(_microphone.startVoiceStream);
    try {
      final stream = await starting;
      if (cancelled()) return null;
      session._sub = stream.listen(session._feed);
      sttLog('[CAP] 🎙️ mic open');
      return session;
    } catch (error) {
      sttLog('[CAP] mic start failed: $error');
      if (identical(_current, session)) _current = null;
      return null;
    }
  }

  Future<void> _release(_Session session) async {
    if (!identical(_current, session)) return;
    _current = null;
    await (_stopping = _stopMicrophone(session));
  }

  Future<void> _stopMicrophone(_Session session) async {
    try {
      await session._starting;
    } catch (_) {
      return; // the native recorder did not start
    }
    try {
      await _microphone.stop();
    } catch (error) {
      sttLog('[CAP] mic stop failed: $error');
    }
  }

  /// Invalidates a pending permission request, or waits for the recorder
  /// to release its stream if startup has already reached the native mic.
  Future<void> stop() async {
    _request++;
    await _current?.close();
    await _stopping;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(stop().whenComplete(_microphone.dispose));
  }
}

class _Session implements PcmCaptureSession {
  _Session(this._owner, this._segmenter, this._onSpeechChange, this._onSegment);

  final SharedPcmCapture _owner;
  final PcmSegmenter _segmenter;
  final void Function(bool) _onSpeechChange;
  final void Function(PcmSegment) _onSegment;
  StreamSubscription<Uint8List>? _sub;
  Future<Stream<Uint8List>>? _starting;
  Future<void>? _closing;
  bool _wasInSpeech = false;

  @override
  bool get inSpeech => _closing == null && _segmenter.inSpeech;

  void _feed(Uint8List chunk) {
    if (_closing != null) return;
    final segments = _segmenter.feed(chunk);
    if (_segmenter.inSpeech != _wasInSpeech) {
      _wasInSpeech = _segmenter.inSpeech;
      if (_wasInSpeech) {
        sttLog('[CAP] 🗣 speech onset  '
            'floor=${_segmenter.noiseFloor.toStringAsFixed(0)}');
      }
      _onSpeechChange(_wasInSpeech);
    }
    for (final segment in segments) {
      sttLog('[CAP] utterance ${segment.durationMs}ms  '
          'peak=${segment.peakRms.toStringAsFixed(0)}');
      _onSegment(segment);
    }
  }

  @override
  Future<PcmSegment?> close({bool flush = false}) async {
    final closing = _closing;
    if (closing != null) {
      await closing;
      return null;
    }
    final tail = flush ? _segmenter.flush() : null;
    if (tail != null) {
      sttLog('[CAP] ✂️ window closed mid-answer — kept ${tail.durationMs}ms');
    }
    await (_closing = _close());
    return tail;
  }

  Future<void> _close() async {
    await _sub?.cancel();
    _sub = null;
    await _owner._release(this);
  }
}
