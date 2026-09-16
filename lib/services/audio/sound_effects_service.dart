import 'dart:async' show unawaited;
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';

import '../../core/utils/stt_debug_log.dart';

/// The tiny boundary around the platform audio player used for earcons.
///
/// Keeping byte generation in [SoundEffectsService] deterministic lets it be
/// verified without a device, while this adapter remains the only code that
/// crosses into the audioplayers plugin.
abstract interface class SoundEffectPlayer {
  Future<void> prepare();
  Future<void> play(Uint8List bytes);
  Future<void> stop();
  void dispose();
}

// coverage:ignore-start
// Device adapter: Android/iOS audio-focus routing is exercised in hands-free
// device smoke tests; its deterministic caller is unit-tested through the port.
class _AudioPlayersSoundEffectPlayer implements SoundEffectPlayer {
  _AudioPlayersSoundEffectPlayer() : _player = AudioPlayer();

  final AudioPlayer _player;

  @override
  Future<void> prepare() => _player.setAudioContext(AudioContext(
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
      ));

  @override
  Future<void> play(Uint8List bytes) => _player.play(BytesSource(bytes));

  @override
  Future<void> stop() => _player.stop();

  @override
  void dispose() => _player.dispose();
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

  SoundEffectPlayer get _player {
    if (_playerInstance == null) {
      final p = _injectedPlayer ?? _AudioPlayersSoundEffectPlayer();
      _playerInstance = p;
      _readyFuture = p.prepare();
    }
    return _playerInstance!;
  }

  Future<void> get _ready {
    _player; // ensure created + configured
    return _readyFuture!;
  }

  Uint8List? _correctBytes;
  Uint8List? _incorrectBytes;
  Uint8List? _cueBytes;
  Uint8List? _doneBytes;

  // Generates a PCM WAV file in memory — avoids the empty asset placeholders.
  Uint8List _makeBeep(double freqHz, double durationSec,
      {double volume = 0.55}) {
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
  Uint8List _makeTwoTone(double f1, double f2, double durationSec,
      {double volume = 0.55}) {
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

  Future<void> playCorrect() async {
    try {
      await _ready;
      _correctBytes ??= _makeTwoTone(660, 990, 0.22); // rising chirp
      sttLog('[SFX] 🎵 playCorrect (rising chirp)');
      await _player.play(_correctBytes!);
    } catch (_) {}
  }

  Future<void> playIncorrect() async {
    try {
      await _ready;
      _incorrectBytes ??= _makeTwoTone(330, 220, 0.28); // falling low buzz
      sttLog('[SFX] 🎵 playIncorrect (falling buzz)');
      await _player.play(_incorrectBytes!);
    } catch (_) {}
  }

  /// Short soft cue marking the start of listening — the hands-free "your turn"
  /// earcon (paired with a haptic so it's catchable eyes-off).
  Future<void> playListenCue() async {
    try {
      await _ready;
      _cueBytes ??= _makeBeep(620, 0.07, volume: 0.4);
      sttLog('[SFX] 🎵 playListenCue (soft tick)');
      await _player.play(_cueBytes!);
    } catch (_) {}
  }

  /// Mirror of [playListenCue]: lower soft tick marking that the mic has
  /// CLOSED and the answer is being analyzed — the eyes-off signal to stop
  /// talking (hands-free protocol, user request 2026-07-08).
  Future<void> playListenDone() async {
    try {
      await _ready;
      _doneBytes ??= _makeBeep(440, 0.07, volume: 0.4);
      sttLog('[SFX] 🎵 playListenDone (soft low tick)');
      await _player.play(_doneBytes!);
    } catch (_) {}
  }

  /// Stops an in-flight earcon without disposing the player. Used when the
  /// app backgrounds: a cue must never keep playing after the quiz is paused.
  Future<void> stop() async {
    try {
      await _playerInstance?.stop();
    } catch (_) {}
  }

  void dispose() {
    unawaited(stop());
    _playerInstance?.dispose();
  }
}
