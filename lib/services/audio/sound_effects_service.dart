import 'dart:math' as math;
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';

class SoundEffectsService {
  final _player = AudioPlayer();
  Uint8List? _correctBytes;
  Uint8List? _incorrectBytes;

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
      _correctBytes ??= _makeBeep(880, 0.14); // high A — bright ding
      await _player.play(BytesSource(_correctBytes!));
    } catch (_) {}
  }

  Future<void> playIncorrect() async {
    try {
      _incorrectBytes ??= _makeBeep(280, 0.22); // low growl
      await _player.play(BytesSource(_incorrectBytes!));
    } catch (_) {}
  }

  void dispose() => _player.dispose();
}
