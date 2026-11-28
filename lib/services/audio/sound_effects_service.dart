import 'dart:async' show Completer, unawaited;
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';

import '../../core/utils/stt_debug_log.dart';
import 'audio_ports.dart';
import 'native_playback_player.dart';

/// The tiny boundary around the platform audio player used for earcons.
///
/// Keeping byte generation in [SoundEffectsService] deterministic lets it be
/// verified without a device, while this adapter remains the only code that
/// crosses into the audioplayers plugin.
abstract interface class SoundEffectPlayer {
  Future<void> prepare();
  Future<void> play(Uint8List bytes, {bool waitForCompletion = false});
  Future<void> stop();
  void dispose();
}

// coverage:ignore-start
// Device adapter: Android/iOS audio-focus routing is exercised in hands-free
// device smoke tests; its deterministic caller is unit-tested through the port.
class _AudioPlayersSoundEffectPlayer implements SoundEffectPlayer {
  final _player = NativePlaybackPlayer();

  @override
  Future<void> prepare() => _player.setAudioContext(
    AudioContext(
      // Earcons must NEVER take Android audio focus: the default (GAIN)
      // contests focus with SpeechRecognizer and kills young listen sessions
      // within tens of ms — field log 2026-07-07: every hands-free retry
      // beeped, instantly lost the mic, and the card was skipped ("it bips a
      // few times then skips"). FOCUS_NONE plays the beep on top of whatever
      // holds audio without contesting it. Usage stays MEDIA on purpose:
      // assistanceSonification routes to Samsung's system-sounds stream,
      // which is silent for most users ("all the bips disappeared").
      android: const AudioContextAndroid(
        contentType: AndroidContentType.sonification,
        usageType: AndroidUsageType.media,
        audioFocus: AndroidAudioFocus.none,
      ),
      iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
    ),
  );

  @override
  Future<void> play(Uint8List bytes, {bool waitForCompletion = false}) {
    final source = BytesSource(bytes);
    return waitForCompletion ? _player.playToEnd(source) : _player.play(source);
  }

  @override
  Future<void> stop() => _player.stop();

  @override
  void dispose() {
    unawaited(
      _player.dispose().catchError((Object error) {
        sttLog('[SFX] player disposal failed: $error');
      }),
    );
  }
}
// coverage:ignore-end

class SoundEffectsService {
  SoundEffectsService({SoundEffectPlayer? player}) : _injectedPlayer = player;

  // LAZY: creating an AudioPlayer touches platform channels, and since the
  // AudioDirector refactor this service is built inside a plain provider —
  // eager construction crashed every binding-less provider test
  // ("Binding has not yet been initialized", 2026-07-22). The player spins
  // up on first play instead.
  final SoundEffectPlayer? _injectedPlayer;
  SoundEffectPlayer? _playerInstance;
  Future<void>? _readyFuture;
  Future<void>? _stopping;
  bool _stopFailed = false;
  int _playbackGeneration = 0;
  Completer<void> _interrupted = Completer<void>();
  int? _cueGeneration;
  bool _disposed = false;

  /// Native stop state for playback gates, including an unretired refusal.
  Future<void>? get stopRequest => _stopping;

  SoundEffectPlayer get _player =>
      _playerInstance ??= _injectedPlayer ?? _AudioPlayersSoundEffectPlayer();

  Future<void> get _ready {
    final player = _player;
    return _readyFuture ??= Future<void>.sync(player.prepare).onError((
      Object error,
      StackTrace stack,
    ) {
      if (identical(_playerInstance, player)) {
        _readyFuture = null;
        // Native creation can leave an AudioPlayer permanently unusable.
        // A fresh adapter also retries native preparation from scratch.
        if (_injectedPlayer == null && !_disposed) {
          _playerInstance = null;
          _stopping = null;
          _stopFailed = false;
          player.dispose();
        }
      }
      Error.throwWithStackTrace(error, stack);
    });
  }

  Uint8List? _correctBytes;
  Uint8List? _incorrectBytes;
  Uint8List? _cueBytes;
  Uint8List? _doneBytes;

  // Generates a PCM WAV file in memory — avoids the empty asset placeholders.
  Uint8List _makeBeep(
    double freqHz,
    double durationSec, {
    double volume = 0.55,
  }) {
    const sampleRate = 22050;
    final numSamples = (sampleRate * durationSec).round();
    final dataSize = numSamples * 2; // 16-bit mono
    final buf = ByteData(44 + dataSize);
    var o = 0;
    final raw = buf.buffer.asUint8List();
    // RIFF header
    raw.setRange(o, o + 4, [82, 73, 70, 70]);
    o += 4; // 'RIFF'
    buf.setUint32(o, 36 + dataSize, Endian.little);
    o += 4;
    raw.setRange(o, o + 4, [87, 65, 86, 69]);
    o += 4; // 'WAVE'
    raw.setRange(o, o + 4, [102, 109, 116, 32]);
    o += 4; // 'fmt '
    buf.setUint32(o, 16, Endian.little);
    o += 4;
    buf.setUint16(o, 1, Endian.little);
    o += 2; // PCM
    buf.setUint16(o, 1, Endian.little);
    o += 2; // mono
    buf.setUint32(o, sampleRate, Endian.little);
    o += 4;
    buf.setUint32(o, sampleRate * 2, Endian.little);
    o += 4; // byteRate
    buf.setUint16(o, 2, Endian.little);
    o += 2; // blockAlign
    buf.setUint16(o, 16, Endian.little);
    o += 2; // bitsPerSample
    raw.setRange(o, o + 4, [100, 97, 116, 97]);
    o += 4; // 'data'
    buf.setUint32(o, dataSize, Endian.little);
    o += 4;
    // PCM samples with fade-in/out envelope
    const fade = 300;
    for (var i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      final env = i < fade
          ? i / fade.toDouble()
          : (i > numSamples - fade ? (numSamples - i) / fade.toDouble() : 1.0);
      final s = (math.sin(2 * math.pi * freqHz * t) * volume * env * 32767)
          .round()
          .clamp(-32768, 32767);
      buf.setInt16(o, s, Endian.little);
      o += 2;
    }
    return raw;
  }

  /// Two sequential tones in one buffer — verdict sounds must be melodic so
  /// the ear separates them from the single-tone listen cue; with three
  /// near-identical sine beeps users hear an undifferentiated "bip bip"
  /// between cards (field report 2026-07-07: the correct-ding of card N
  /// followed by card N+1's listen cue read as "two bips").
  Uint8List _makeTwoTone(
    double f1,
    double f2,
    double durationSec, {
    double volume = 0.55,
  }) {
    final half = durationSec / 2;
    final a = _makeBeep(f1, half, volume: volume);
    final b = _makeBeep(f2, half, volume: volume);
    // Concatenate the PCM payloads under a single WAV header.
    final dataA = a.sublist(44);
    final dataB = b.sublist(44);
    final out = Uint8List(44 + dataA.length + dataB.length);
    out.setRange(0, 44, a);
    final bd = ByteData.view(out.buffer);
    bd.setUint32(4, 36 + dataA.length + dataB.length, Endian.little);
    bd.setUint32(40, dataA.length + dataB.length, Endian.little);
    out.setRange(44, 44 + dataA.length, dataA);
    out.setRange(44 + dataA.length, out.length, dataB);
    return out;
  }

  Future<void> _play(
    String label,
    Uint8List Function() bytes, {
    bool requirePlayback = false,
  }) async {
    final generation = _playbackGeneration;
    try {
      if (_disposed) throw const AudioPlaybackCancelled();
      if (!requirePlayback && _cueGeneration != null) return;
      // The native callback identifies a player, not a playback. Every cue
      // needs its own player, even after a best-effort earcon played normally.
      final stopping = requirePlayback ? _stopCurrentPlayer() : _stopping;
      if (stopping != null) {
        await stopping;
        if (generation != _playbackGeneration) {
          throw const AudioPlaybackCancelled();
        }
        if (identical(stopping, _stopping)) _stopping = null;
      }
      final player = _player;
      await _ready;
      if (generation != _playbackGeneration) {
        throw const AudioPlaybackCancelled();
      }
      sttLog('[SFX] 🎵 $label');
      await player.play(bytes(), waitForCompletion: requirePlayback);
      if (generation != _playbackGeneration) {
        throw const AudioPlaybackCancelled();
      }
    } catch (error) {
      if (requirePlayback) rethrow;
      sttLog('[SFX] optional playback failed: $error');
    }
  }

  Future<void> playCorrect() => _play(
    'playCorrect (rising chirp)',
    () => _correctBytes ??= _makeTwoTone(660, 990, 0.22),
  );

  Future<void> playIncorrect() => _play(
    'playIncorrect (falling buzz)',
    () => _incorrectBytes ??= _makeTwoTone(330, 220, 0.28),
  );

  /// Short soft cue marking the start of listening — the hands-free "your turn"
  /// earcon (paired with a haptic so it's catchable eyes-off).
  Future<void> playListenCue() async {
    _invalidatePlayback();
    final generation = _cueGeneration = _playbackGeneration;
    final interrupted = _interrupted.future;
    try {
      await Future.any<void>([
        _play(
          'playListenCue (soft tick)',
          () => _cueBytes ??= _makeBeep(620, 0.07, volume: 0.4),
          requirePlayback: true,
        ),
        interrupted.then<void>((_) => throw const AudioPlaybackCancelled()),
      ]);
    } finally {
      if (_cueGeneration == generation) _cueGeneration = null;
    }
  }

  /// Mirror of [playListenCue]: lower soft tick marking that the mic has
  /// CLOSED and the answer is being analyzed — the eyes-off signal to stop
  /// talking (hands-free protocol, user request 2026-07-08).
  Future<void> playListenDone() => _play(
    'playListenDone (soft low tick)',
    () => _doneBytes ??= _makeBeep(440, 0.07, volume: 0.4),
  );

  /// Invalidates active preparation or playback, then confirms native stop.
  Future<void> stop() async {
    _invalidatePlayback();
    if (_disposed) return;
    await _stopCurrentPlayer();
  }

  void _invalidatePlayback() {
    _playbackGeneration++;
    _interrupted.complete();
    _interrupted = Completer<void>();
  }

  Future<void>? _stopCurrentPlayer() {
    final player = _playerInstance;
    if (player != null && (_stopping == null || _stopFailed)) {
      _stopFailed = false;
      _stopping = _stopPlayer(player);
    }
    return _stopping;
  }

  Future<void> _stopPlayer(SoundEffectPlayer player) async {
    try {
      await player.stop();
    } catch (_) {
      if (identical(_playerInstance, player)) _stopFailed = true;
      rethrow;
    }
    // Events are keyed by native player ID. Rotate a stopped native player so
    // an already queued completion cannot finish a later opening cue.
    if (_injectedPlayer == null && identical(_playerInstance, player)) {
      _playerInstance = null;
      _readyFuture = null;
      player.dispose();
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _invalidatePlayback();
    unawaited(
      waitForRelease(retry: true).catchError((Object error) {
        sttLog('[SFX] disposal could not release playback: $error');
      }),
    );
  }

  /// Joins the native stop even after the Dart cue has been cancelled.
  /// Retirement starts a stop or retries a refusal through the same future.
  Future<void> waitForRelease({bool retry = false}) async {
    await (retry ? _stopCurrentPlayer() : _stopping);
    if (!_disposed) return;
    final player = _playerInstance;
    _playerInstance = null;
    player?.dispose();
  }
}
