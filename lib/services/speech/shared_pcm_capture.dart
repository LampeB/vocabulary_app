import 'dart:async';
import 'dart:typed_data';

import '../../core/utils/pcm_segmenter.dart';
import '../../core/utils/stt_debug_log.dart';
import 'pcm_microphone.dart';
import 'stt_engine.dart';

/// Native release was rejected or was not acknowledged by the deadline.
class PcmReleaseException implements Exception {
  const PcmReleaseException(this.cause);

  final Object cause;

  @override
  String toString() => 'Microphone release failed: $cause';
}

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
  /// [onInterruption] reports an unexpected end of input. The caller must
  /// close that session and wait for native release.
  Future<PcmCaptureSession?> open({
    required void Function(bool inSpeech) onSpeechChange,
    required void Function(PcmSegment segment) onSegment,
    required void Function(Object error) onInterruption,
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
    this.releaseTimeout = sttMicReleaseTimeout,
  }) : _microphone = microphone ?? RecordPcmMicrophone(),
       _segmenterFactory = segmenterFactory ?? _defaultSegmenter;

  /// 500ms of silence ends an answer: Scribe kept 38/38 corpus words at
  /// 450ms, Whisper's conservative setting was 700ms. An answer is a word or
  /// two, so utterances hard-stop at 3s (longer is ambient conversation).
  static PcmSegmenter _defaultSegmenter() =>
      PcmSegmenter(silenceEndMs: 500, maxUtteranceMs: 3000);

  final Duration releaseTimeout;
  final PcmMicrophone _microphone;
  final PcmSegmenter Function() _segmenterFactory;
  _Session? _current;
  int _request = 0;
  bool _disposed = false;

  /// Resolves the permission prompt without starting capture.
  Future<bool> ensurePermission() => _microphone.hasPermission();

  /// Checks whether playback may use the audio channel. Only the owner of
  /// the capture can request a stop.
  Future<void>? waitForMicrophoneRelease() {
    final session = _current;
    if (session == null) return null;
    return session._closing?.timeout(releaseTimeout) ??
        Future<void>.error(StateError('PCM microphone still in use'));
  }

  @override
  Future<PcmCaptureSession?> open({
    required void Function(bool inSpeech) onSpeechChange,
    required void Function(PcmSegment segment) onSegment,
    required void Function(Object error) onInterruption,
  }) async {
    final request = ++_request;
    bool cancelled() => _disposed || request != _request;
    await _current?.close();
    if (cancelled()) return null;
    final permitted = await ensurePermission();
    if (cancelled()) return null;
    if (!permitted) {
      sttLog('[CAP] ❌ mic permission denied');
      return null;
    }
    final session = _Session(
      this,
      _segmenterFactory(),
      onSpeechChange,
      onSegment,
      onInterruption,
    );
    _current = session;
    final starting = session._starting = Future.sync(
      _microphone.startVoiceStream,
    );
    try {
      final stream = await starting;
      if (cancelled()) return null;
      session._sub = stream.listen(
        session._feed,
        onError: session._interruptInput,
        onDone: () => session._interruptInput(
          StateError('Microphone stream ended unexpectedly'),
        ),
      );
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
    try {
      await session._starting;
    } catch (_) {
      if (identical(_current, session)) _current = null;
      return; // the native recorder did not start
    }
    await _microphone.stop();
    // Keep the session quarantined until native release is acknowledged.
    _current = null;
  }

  /// Invalidates a pending permission request, or waits for the recorder
  /// to release its stream if startup has already reached the native mic.
  Future<void> stop() async {
    _request++;
    await _current?.close();
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(
      stop()
          .catchError((Object error) {
            sttLog('[CAP] mic disposal after release failure: $error');
          })
          .whenComplete(_microphone.dispose),
    );
  }
}

class _Session implements PcmCaptureSession {
  _Session(
    this._owner,
    this._segmenter,
    this._onSpeechChange,
    this._onSegment,
    this._onInterruption,
  );

  final SharedPcmCapture _owner;
  final PcmSegmenter _segmenter;
  final void Function(bool) _onSpeechChange;
  final void Function(PcmSegment) _onSegment;
  final void Function(Object) _onInterruption;
  StreamSubscription<Uint8List>? _sub;
  Future<Stream<Uint8List>>? _starting;
  Future<void>? _closing;
  bool _closedForInput = false;
  bool _wasInSpeech = false;

  @override
  bool get inSpeech => !_closedForInput && _segmenter.inSpeech;

  void _interruptInput(Object error) {
    if (_closedForInput) return;
    _closedForInput = true;
    _onInterruption(error);
  }

  void _feed(Uint8List chunk) {
    if (_closedForInput) return;
    final segments = _segmenter.feed(chunk);
    if (_segmenter.inSpeech != _wasInSpeech) {
      _wasInSpeech = _segmenter.inSpeech;
      if (_wasInSpeech) {
        sttLog(
          '[CAP] 🗣 speech onset  '
          'floor=${_segmenter.noiseFloor.toStringAsFixed(0)}',
        );
      }
      _onSpeechChange(_wasInSpeech);
    }
    for (final segment in segments) {
      sttLog(
        '[CAP] utterance ${segment.durationMs}ms  '
        'peak=${segment.peakRms.toStringAsFixed(0)}',
      );
      _onSegment(segment);
    }
  }

  @override
  Future<PcmSegment?> close({bool flush = false}) async {
    final tail = flush && !_closedForInput ? _segmenter.flush() : null;
    _closedForInput = true;
    if (tail != null) {
      sttLog('[CAP] ✂️ window closed mid-answer — kept ${tail.durationMs}ms');
    }
    try {
      // A timeout releases the caller, while a repeated close still joins
      // the same native stop until its real result arrives.
      await (_closing ??= Future<void>.microtask(
        _close,
      )).timeout(_owner.releaseTimeout);
    } on TimeoutException catch (error) {
      throw PcmReleaseException(error);
    }
    return tail;
  }

  Future<void> _close() async {
    final subscription = _sub;
    _sub = null;
    // Sealing input and detaching the Dart stream are separate from asking
    // the recorder to release the native microphone.
    if (subscription != null) {
      unawaited(
        Future<void>.sync(subscription.cancel).catchError((Object error) {
          sttLog('[CAP] mic stream cancellation failed: $error');
        }),
      );
    }
    try {
      await _owner._release(this);
    } catch (error) {
      _closing = null; // an explicit retry may call the native stop again
      throw PcmReleaseException(error);
    }
  }
}
