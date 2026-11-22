import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/core/utils/pcm_segmenter.dart';
import 'package:vocab_kr/services/speech/pcm_microphone.dart';
import 'package:vocab_kr/services/speech/shared_pcm_capture.dart';

class _FakeMicrophone implements PcmMicrophone {
  bool permissionGranted = true;
  Object? startError;
  var stream = StreamController<Uint8List>.broadcast(sync: true);
  int starts = 0;
  int stops = 0;
  int disposals = 0;

  @override
  Future<bool> hasPermission() async => permissionGranted;

  @override
  Future<Stream<Uint8List>> startVoiceStream() async {
    starts++;
    if (startError != null) throw startError!;
    return stream.stream;
  }

  @override
  Future<void> stop() async => stops++;

  @override
  void dispose() => disposals++;
}

Uint8List _tone(int ms, double amplitude) {
  final n = 16000 * ms ~/ 1000;
  final out = Int16List(n);
  for (var i = 0; i < n; i++) {
    out[i] =
        (math.sin(2 * math.pi * 300 * i / 16000) * amplitude * 32767).round();
  }
  return out.buffer.asUint8List();
}

Uint8List _silence(int ms) => Uint8List(16000 * ms ~/ 1000 * 2);

void main() {
  group('SharedPcmCapture', () {
    test('reports speech onset/end and delivers the whole utterance', () async {
      final mic = _FakeMicrophone();
      final capture = SharedPcmCapture(microphone: mic);
      final changes = <bool>[];
      final segments = <PcmSegment>[];
      final session = await capture.open(
          onSpeechChange: changes.add, onSegment: segments.add);
      expect(session, isNotNull);

      mic.stream.add(_silence(300));
      mic.stream.add(_tone(400, .4));
      expect(session!.inSpeech, isTrue);
      mic.stream.add(_silence(700));

      expect(changes, [true, false]);
      expect(segments.length, 1);
      expect(segments.single.durationMs, greaterThanOrEqualTo(400));
      await session.close();
      expect(mic.stops, 1);
    });

    test('closing mid-answer with flush keeps the answer', () async {
      final mic = _FakeMicrophone();
      final capture = SharedPcmCapture(microphone: mic);
      final session = await capture.open(
          onSpeechChange: (_) {}, onSegment: (_) => fail('not ended yet'));
      mic.stream.add(_silence(300));
      mic.stream.add(_tone(500, .4));

      final tail = await session!.close(flush: true);
      expect(tail, isNotNull);
      expect(tail!.durationMs, greaterThanOrEqualTo(500));
      expect(await session.close(flush: true), isNull, reason: 'idempotent');
    });

    test('closing without flush drops a half-spoken answer', () async {
      final mic = _FakeMicrophone();
      final session = await SharedPcmCapture(microphone: mic)
          .open(onSpeechChange: (_) {}, onSegment: (_) {});
      mic.stream.add(_silence(300));
      mic.stream.add(_tone(500, .4));
      expect(await session!.close(), isNull);
    });

    test('a stale window closing late never stops the newer window\'s mic',
        () async {
      final mic = _FakeMicrophone();
      final capture = SharedPcmCapture(microphone: mic);
      final first =
          await capture.open(onSpeechChange: (_) {}, onSegment: (_) {});
      final heard = <PcmSegment>[];
      final second =
          await capture.open(onSpeechChange: (_) {}, onSegment: heard.add);
      final stopsAfterSecondOpen = mic.stops;
      await first!.close();
      expect(mic.stops, stopsAfterSecondOpen,
          reason: 'the first window was already closed by the second open');

      mic.stream.add(_silence(300));
      mic.stream.add(_tone(400, .4));
      mic.stream.add(_silence(700));
      expect(heard.length, 1, reason: 'only the live window hears audio');
      await second!.close();
    });

    test('permission denied or a busy mic opens nothing', () async {
      final denied = _FakeMicrophone()..permissionGranted = false;
      expect(
          await SharedPcmCapture(microphone: denied)
              .open(onSpeechChange: (_) {}, onSegment: (_) {}),
          isNull);
      expect(denied.starts, 0);
      final busy = _FakeMicrophone()..startError = StateError('busy');
      expect(
          await SharedPcmCapture(microphone: busy)
              .open(onSpeechChange: (_) {}, onSegment: (_) {}),
          isNull);
    });

    test('dispose releases the recorder', () async {
      final mic = _FakeMicrophone();
      final capture = SharedPcmCapture(microphone: mic);
      await capture.open(onSpeechChange: (_) {}, onSegment: (_) {});
      capture.dispose();
      await Future<void>.delayed(Duration.zero);
      expect(mic.disposals, 1);
      expect(mic.stops, 1);
    });
  });
}
