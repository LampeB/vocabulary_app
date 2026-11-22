import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/core/utils/pcm_segmenter.dart';
import 'package:vocab_kr/services/speech/phone_pcm_recognizer.dart';
import 'package:vocab_kr/services/speech/phone_stt_engine.dart';
import 'package:vocab_kr/services/speech/stt_engine.dart';

class _FakeRecognizer implements PhonePcmRecognizer {
  bool supported = true;
  List<String> reply = const [];
  Object? error;
  final calls = <(Uint8List, String)>[];
  Completer<void>? gate;

  @override
  Future<bool> isSupported() async => supported;

  @override
  Future<List<String>> recognize(Uint8List pcm16, String locale) async {
    calls.add((pcm16, locale));
    if (gate != null) await gate!.future;
    if (error != null) throw error!;
    return reply;
  }
}

PcmSegment _seg() => PcmSegment(Uint8List(64), 2, 0);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PhoneSttEngine', () {
    test('is a shared, network engine, ready only when supported', () async {
      final rec = _FakeRecognizer()..supported = false;
      final engine = PhoneSttEngine(rec);
      expect(engine.id, 'phone');
      expect(engine.capture, SttCapture.sharedPcm);
      expect(engine.requiresNetwork, isTrue);
      expect(engine.isReady, isFalse);
      await engine.prepare();
      expect(engine.isReady, isFalse);
      rec.supported = true;
      await engine.prepare();
      expect(engine.isReady, isTrue);
    });

    test(
        'sends the utterance with the speech locale; every alternative is '
        'a candidate', () async {
      final rec = _FakeRecognizer()..reply = ['꽃비', '커피'];
      final engine = PhoneSttEngine(rec);
      final h = await engine
          .recognize(_seg(), langCode: 'ko', promptHints: const ['커피']);
      expect(rec.calls.single.$2, 'ko-KR');
      expect(h!.engineId, 'phone');
      expect(h.transcript, '꽃비');
      expect(h.candidates, ['꽃비', '커피'],
          reason: 'the right answer is often an alternate');
    });

    test('nothing understood is null; a platform error throws', () async {
      final rec = _FakeRecognizer();
      final engine = PhoneSttEngine(rec);
      expect(
          await engine.recognize(_seg(), langCode: 'fr', promptHints: const []),
          isNull);
      rec.error = PlatformException(code: 'error_2');
      expect(engine.recognize(_seg(), langCode: 'fr', promptHints: const []),
          throwsA(isA<PlatformException>()));
    });

    test('one recognition at a time; a failure does not jam the queue',
        () async {
      final rec = _FakeRecognizer()..reply = ['thé'];
      final engine = PhoneSttEngine(rec);
      rec.gate = Completer<void>();
      final first =
          engine.recognize(_seg(), langCode: 'fr', promptHints: const []);
      final second =
          engine.recognize(_seg(), langCode: 'fr', promptHints: const []);
      await Future<void>.delayed(Duration.zero);
      expect(rec.calls.length, 1, reason: 'second waits for the first');
      rec.gate!.complete();
      expect((await first)!.transcript, 'thé');
      expect((await second)!.transcript, 'thé');
      expect(rec.calls.length, 2);
    });

    test('start/stop are no-ops for a shared engine', () async {
      final engine = PhoneSttEngine(_FakeRecognizer());
      expect(
          await engine.start(
              langCode: 'fr', promptHints: const [], onHypothesis: (_) {}),
          isTrue);
      await engine.stop();
      engine.dispose();
    });
  });

  group('MethodChannelPhonePcmRecognizer', () {
    const channel = MethodChannel('vocab_kr/pcm_speech');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    test('maps the native reply and arguments', () async {
      MethodCall? seen;
      messenger.setMockMethodCallHandler(channel, (call) async {
        seen = call;
        if (call.method == 'isSupported') return true;
        return {
          'texts': ['물', '몰'],
          'confidences': <double>[],
          'elapsedMs': 700,
        };
      });
      const rec = MethodChannelPhonePcmRecognizer();
      expect(await rec.isSupported(), isTrue);
      final pcm = Uint8List(32);
      expect(await rec.recognize(pcm, 'ko-KR'), ['물', '몰']);
      expect(seen!.method, 'recognize');
      expect(seen!.arguments['locale'], 'ko-KR');
      expect(seen!.arguments['sampleRate'], 16000);
      expect(seen!.arguments['pcm'], pcm);
    });

    test('no platform implementation (iOS, tests) means unsupported', () async {
      const rec = MethodChannelPhonePcmRecognizer();
      expect(await rec.isSupported(), isFalse);
    });
  });
}
