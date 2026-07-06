import 'dart:math' as math;
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';

class SoundEffectsService {
  SoundEffectsService() {
    // Earcons must NEVER take Android audio focus: the default (GAIN)
    // contests focus with SpeechRecognizer and kills young listen sessions
    // within tens of ms — field log 2026-07-07: every hands-free retry
    // beeped, instantly lost the mic, and the card was skipped ("it bips a
    // few times then skips"). Sonification + FOCUS_NONE plays the beep on
    // top of whatever else holds audio, without contesting it.
    _ready = _player.setAudioContext(AudioContext(
      android: const AudioContextAndroid(
        contentType: AndroidContentType.sonification,
        usageType: AndroidUsageType.assistanceSonification,
        audioFocus: AndroidAudioFocus.none,
      ),
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.ambient,
      ),
    ));
  }

  final _player = AudioPlayer();
  late final Future<void> _ready;
  Uint8List? _correctBytes;
  Uint8List? _incorrectBytes;
  Uint8List? _cueBytes;

  // Generates a PCM WAV file in memory — avoids the empty asset placeholders.
  Uint8List _makeBeep(double freqHz, double durationSec, {double volume = 0.55}) {
    const sampleRate = 22050;
    final numSamples = (sampleRate * durationSec).round();
    final dataSize = numSamples * 2; // 16-bit mono
    final buf = ByteData(44 + dataSize);
    var o = 0;
    final raw = buf.buffer.asUint8List();
    // RIFF header
    raw.setRange(o, o + 4, [82, 73, 70, 70]); o += 4; // 'RIFF'
    buf.setUint32(o, 36 + dataSize, Endian.little); o += 4;
    raw.setRange(o, o + 4, [87, 65, 86, 69]); o += 4;  // 'WAVE'
    raw.setRange(o, o + 4, [102, 109, 116, 32]); o += 4; // 'fmt '
    buf.setUint32(o, 16, Endian.little); o += 4;
    buf.setUint16(o, 1, Endian.little); o += 2;  // PCM
    buf.setUint16(o, 1, Endian.little); o += 2;  // mono
    buf.setUint32(o, sampleRate, Endian.little); o += 4;
    buf.setUint32(o, sampleRate * 2, Endian.little); o += 4; // byteRate
    buf.setUint16(o, 2, Endian.little); o += 2;  // blockAlign
    buf.setUint16(o, 16, Endian.little); o += 2; // bitsPerSample
    raw.setRange(o, o + 4, [100, 97, 116, 97]); o += 4; // 'data'
    buf.setUint32(o, dataSize, Endian.little); o += 4;
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

  Future<void> playCorrect() async {
    try {
      await _ready;
      _correctBytes ??= _makeBeep(880, 0.14); // high A — bright ding
      await _player.play(BytesSource(_correctBytes!));
    } catch (_) {}
  }

  Future<void> playIncorrect() async {
    try {
      await _ready;
      _incorrectBytes ??= _makeBeep(280, 0.22); // low growl
      await _player.play(BytesSource(_incorrectBytes!));
    } catch (_) {}
  }

  /// Short soft cue marking the start of listening — the hands-free "your turn"
  /// earcon (paired with a haptic so it's catchable eyes-off).
  Future<void> playListenCue() async {
    try {
      await _ready;
      _cueBytes ??= _makeBeep(620, 0.07, volume: 0.4);
      await _player.play(BytesSource(_cueBytes!));
    } catch (_) {}
  }

  void dispose() => _player.dispose();
}
