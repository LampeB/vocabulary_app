import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/core/utils/pcm_segmenter.dart';
import 'package:vocab_kr/core/utils/wav_writer.dart';
import 'package:vocab_kr/services/speech/whisper_speech_service.dart';

/// Pure logic of the Whisper pipeline: the segmenter IS our endpointing —
/// these tests encode the rules that vendor engines got wrong in the field
/// (short words dropped in noise, first syllables clipped).
Uint8List _tone(int ms, double amplitude, {int sampleRate = 16000}) {
  final n = sampleRate * ms ~/ 1000;
  final out = Int16List(n);
  for (var i = 0; i < n; i++) {
    out[i] = (math.sin(2 * math.pi * 300 * i / sampleRate) * amplitude * 32767)
        .round();
  }
  return out.buffer.asUint8List();
}

Uint8List _silence(int ms, {int sampleRate = 16000, double noise = 0}) {
  final n = sampleRate * ms ~/ 1000;
  final out = Int16List(n);
  if (noise > 0) {
    final rng = math.Random(42);
    for (var i = 0; i < n; i++) {
      out[i] = ((rng.nextDouble() * 2 - 1) * noise * 32767).round();
    }
  }
  return out.buffer.asUint8List();
}

void main() {
  group('PcmSegmenter', () {
    test('a short word in quiet is captured with pre-roll', () {
      final seg = PcmSegmenter();
      final segments = <PcmSegment>[
        ...seg.feed(_silence(600)),
        ...seg.feed(_tone(250, 0.4)), // ~차: a 250ms burst
        ...seg.feed(_silence(900)),
      ];
      expect(segments, hasLength(1));
      // Segment includes pre-roll + burst + trailing silence frames:
      // strictly longer than the burst itself — the first syllable killer
      // is the missing pre-roll.
      expect(segments.single.durationMs, greaterThan(400));
    });

    test('a short word above BABBLE noise still triggers', () {
      final seg = PcmSegmenter();
      final segments = <PcmSegment>[
        // noisy room: constant floor at ~5% amplitude
        ...seg.feed(_silence(800, noise: 0.05)),
        ...seg.feed(_tone(250, 0.5)),
        ...seg.feed(_silence(1000, noise: 0.05)),
      ];
      expect(segments, hasLength(1));
    });

    test('steady noise alone never produces a segment', () {
      final seg = PcmSegmenter();
      final segments = seg.feed(_silence(4000, noise: 0.05));
      expect(segments, isEmpty);
    });

    test('clicks shorter than minSpeechMs are discarded', () {
      final seg = PcmSegmenter();
      final segments = <PcmSegment>[
        ...seg.feed(_silence(600)),
        ...seg.feed(_tone(60, 0.6)), // 60ms pop
        ...seg.feed(_silence(1000)),
      ];
      expect(segments, isEmpty);
    });

    test('an utterance at max length is force-closed', () {
      final seg = PcmSegmenter(maxUtteranceMs: 2000);
      final segments = <PcmSegment>[
        ...seg.feed(_silence(600)),
        ...seg.feed(_tone(3000, 0.4)),
      ];
      expect(segments, hasLength(1));
    });

    test('flush returns an in-progress utterance', () {
      final seg = PcmSegmenter();
      seg.feed(_silence(600));
      seg.feed(_tone(400, 0.4));
      final tail = seg.flush();
      expect(tail, isNotNull);
    });
  });

  group('pcm16ToWav', () {
    test('writes a valid 44-byte header', () {
      final wav = pcm16ToWav(Uint8List(3200));
      expect(wav.length, 44 + 3200);
      expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
      final bd = ByteData.view(wav.buffer);
      expect(bd.getUint32(24, Endian.little), 16000); // sample rate
      expect(bd.getUint32(40, Endian.little), 3200); // data size
    });
  });

  group('cleanTranscript', () {
    test('strips punctuation and event tags', () {
      expect(WhisperSpeechService.cleanTranscript(' Café. '), 'Café');
      expect(WhisperSpeechService.cleanTranscript('[Musique] 차!'), '차');
      expect(WhisperSpeechService.cleanTranscript('(rires)'), isNull);
    });

    test('known hallucinations are discarded', () {
      expect(
        WhisperSpeechService.cleanTranscript(
            'Sous-titrage Société Radio-Canada'),
        isNull,
      );
      expect(
        WhisperSpeechService.cleanTranscript('Thank you for watching!'),
        isNull,
      );
      expect(WhisperSpeechService.cleanTranscript('시청해 주셔서 감사합니다'), isNull);
    });

    test('real answers pass through', () {
      expect(WhisperSpeechService.cleanTranscript('우유'), '우유');
      expect(WhisperSpeechService.cleanTranscript(' le thé '), 'le thé');
    });
  });
}
