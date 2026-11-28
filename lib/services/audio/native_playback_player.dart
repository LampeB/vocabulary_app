import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:audioplayers_platform_interface/audioplayers_platform_interface.dart';

import '../../core/utils/stt_debug_log.dart';
import 'audio_ports.dart';

/// An audioplayers adapter for playback that must finish before the mic opens.
final class NativePlaybackPlayer extends AudioPlayer {
  final _native = AudioplayersPlatformInterface.instance;
  Completer<void>? _completion;
  bool _closing = false;
  Future<void>? _stopping;
  Future<void>? _releasedForDisposal;
  Future<void>? _cleanup;

  Future<void> playToEnd(Source source, {bool Function()? keepGoing}) async {
    final completion = _completion = Completer<void>();
    final events = onPlayerComplete.listen(
      (_) {
        if (!completion.isCompleted) completion.complete();
      },
      onError: (Object error, StackTrace stack) {
        if (!completion.isCompleted) completion.completeError(error, stack);
      },
      onDone: _cancelPlayback,
    );
    try {
      await Future.wait<void>([
        keepGoing == null ? play(source) : playWhenCurrent(source, keepGoing),
        completion.future,
      ], eagerError: true);
    } finally {
      if (identical(_completion, completion)) _completion = null;
      unawaited(
        events.cancel().catchError((Object error) {
          sttLog('[AUDIO] playback event cancellation failed: $error');
        }),
      );
    }
  }

  /// A quiz source may finish preparing after the card changed. Check the
  /// intent right before dispatching native resume, including after a delayed
  /// source ACK. Quiz clips do not use the package's position polling.
  Future<void> playWhenCurrent(Source source, bool Function() keepGoing) async {
    await setSource(source);
    if (_closing || !keepGoing()) throw const AudioPlaybackCancelled();
    await _native.resume(playerId);
    if (_closing || !keepGoing()) throw const AudioPlaybackCancelled();
    if (state != PlayerState.completed) state = PlayerState.playing;
  }

  void _cancelPlayback() {
    final completion = _completion;
    if (completion != null && !completion.isCompleted) {
      completion.completeError(const AudioPlaybackCancelled());
    }
  }

  @override
  Future<void> stop() {
    _cancelPlayback();
    return _stopping ??= super.stop().then<void>(
      (_) {
        if (!_closing) _stopping = null;
      },
      onError: (Object error, StackTrace stack) {
        _stopping = null;
        Error.throwWithStackTrace(error, stack);
      },
    );
  }

  Future<void> releaseForDisposal() {
    _closing = true;
    return release();
  }

  @override
  Future<void> release() {
    if (!_closing) return super.release();
    return _releasedForDisposal ??= super.release().onError((
      Object error,
      StackTrace stack,
    ) {
      _releasedForDisposal = null;
      Error.throwWithStackTrace(error, stack);
    });
  }

  @override
  Future<void> dispose() {
    _closing = true;
    return _cleanup ??= _disposeNative();
  }

  Future<void> _disposeNative() async {
    try {
      await super.dispose();
    } catch (_) {
      // In audioplayers 6.7.1, disposed means release already succeeded and
      // the wrapper cannot call stop again. Retry just the native registry
      // cleanup once, using the same platform and player ID as the wrapper.
      if (state != PlayerState.disposed) rethrow;
      await _native.dispose(playerId);
    }
  }
}
