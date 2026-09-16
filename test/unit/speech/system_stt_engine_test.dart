import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/services/speech/speech_recognition_service.dart';
import 'package:vocab_kr/services/speech/stt_engine.dart';
import 'package:vocab_kr/services/speech/system_stt_engine.dart';

class _FakeSystemCapture implements SystemSpeechCapture {
  _FakeSystemCapture({this.initializeResult = true});

  bool initializeResult;
  int initializations = 0;
  int stops = 0;
  int disposals = 0;
  String? language;
  void Function(String, List<String>)? finalHandler;
  void Function(String, List<String>)? partialHandler;

  @override
  void Function()? onListeningDone;

  @override
  void dispose() => disposals++;

  @override
  Future<bool> initialize() async {
    initializations++;
    return initializeResult;
  }

  @override
  Future<bool> startListening({
    required String langCode,
    required void Function(String primary, List<String> candidates) onResult,
    void Function(String primary, List<String> candidates)? onPartial,
  }) async {
    language = langCode;
    finalHandler = onResult;
    partialHandler = onPartial;
    return true;
  }

  @override
  Future<void> stopListening() async => stops++;
}

void main() {
  group('SystemSttEngine', () {
    test('prepares and adapts final and partial platform hypotheses', () async {
      final capture = _FakeSystemCapture();
      final engine = SystemSttEngine(capture, languages: {'fr', 'ko'});
      final hypotheses = <SttHypothesis>[];

      expect(engine.id, 'system');
      expect(engine.capture, SttCapture.ownsMicrophone);
      expect(engine.isReady, isFalse);
      expect(engine.supportsLanguage('fr'), isTrue);
      expect(engine.supportsLanguage('en'), isFalse);
      await engine.prepare();
      expect(engine.isReady, isTrue);
      expect(capture.initializations, 1);

      await engine.start(
        langCode: 'ko',
        promptHints: const ['고양이'],
        onHypothesis: hypotheses.add,
      );
      expect(capture.language, 'ko');
      capture.partialHandler!('고양', ['고양', '고양이']);
      capture.finalHandler!('고양이', ['고양이', '고양']);

      expect(hypotheses, hasLength(2));
      expect(hypotheses.first.confidence, 0.5);
      expect(hypotheses.first.isFinal, isFalse);
      expect(hypotheses.last.transcript, '고양이');
      expect(hypotheses.last.candidates, ['고양이', '고양']);
      expect(hypotheses.last.confidence, 0.9);
      expect(hypotheses.last.isFinal, isTrue);
    });

    test('restores the legacy done callback after stopping its own session',
        () async {
      final capture = _FakeSystemCapture();
      var legacyCalls = 0;
      capture.onListeningDone = () => legacyCalls++;
      final engine = SystemSttEngine(capture);
      var sessionEnds = 0;

      await engine.start(
        langCode: 'fr',
        promptHints: const [],
        onHypothesis: (_) {},
        onSessionEnd: () => sessionEnds++,
      );
      capture.onListeningDone!();
      expect(sessionEnds, 1);
      await engine.stop();
      expect(capture.stops, 1);
      capture.onListeningDone!();
      expect(legacyCalls, 1);
    });

    test('a stale stop cannot remove a newer session-end callback', () async {
      final capture = _FakeSystemCapture();
      final engine = SystemSttEngine(capture);
      var latestSessionEnds = 0;

      await engine.start(
        langCode: 'fr',
        promptHints: const [],
        onHypothesis: (_) {},
        onSessionEnd: () {},
      );
      // A newer race has installed its own callback before this old engine
      // receives its trailing stop signal.
      capture.onListeningDone = () => latestSessionEnds++;
      await engine.stop();

      capture.onListeningDone!();
      expect(latestSessionEnds, 1);
      engine.feed(Uint8List(8));
      engine.dispose();
      expect(capture.disposals, 1);
    });

    test('keeps not-ready state when platform initialization fails', () async {
      final capture = _FakeSystemCapture(initializeResult: false);
      final engine = SystemSttEngine(capture);

      await engine.prepare();
      expect(engine.isReady, isFalse);
      expect(capture.initializations, 1);
    });
  });
}
