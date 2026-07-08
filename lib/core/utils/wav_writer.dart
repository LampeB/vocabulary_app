import 'dart:typed_data';

/// Wraps raw PCM16 mono samples in a minimal WAV container — whisper.cpp's
/// file-based API needs a header, the mic stream has none.
Uint8List pcm16ToWav(Uint8List pcm, {int sampleRate = 16000}) {
  final out = Uint8List(44 + pcm.length);
  final bd = ByteData.view(out.buffer);
  out.setRange(0, 4, [82, 73, 70, 70]); // RIFF
  bd.setUint32(4, 36 + pcm.length, Endian.little);
  out.setRange(8, 12, [87, 65, 86, 69]); // WAVE
  out.setRange(12, 16, [102, 109, 116, 32]); // 'fmt '
  bd.setUint32(16, 16, Endian.little);
  bd.setUint16(20, 1, Endian.little); // PCM
  bd.setUint16(22, 1, Endian.little); // mono
  bd.setUint32(24, sampleRate, Endian.little);
  bd.setUint32(28, sampleRate * 2, Endian.little); // byte rate
  bd.setUint16(32, 2, Endian.little); // block align
  bd.setUint16(34, 16, Endian.little); // bits/sample
  out.setRange(36, 40, [100, 97, 116, 97]); // data
  bd.setUint32(40, pcm.length, Endian.little);
  out.setRange(44, out.length, pcm);
  return out;
}
