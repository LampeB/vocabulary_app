import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/services/speech/stt_engine.dart';
import 'package:vocab_kr/services/speech/whisper_speech_service.dart';
import 'package:vocab_kr/services/speech/whisper_stt_engine.dart';

class _FakeWhisperCapture implements WhisperSpeechCapture {
  _FakeWhisperCapture({this.ready = true, this.startResult = true});

  bool ready;
  bool startResult;
  int prepares = 0;
  int stops = 0;
  int disposals = 0;
  String? language;
  List<String>? hints;
  void Function(String text, int segmentMs)? finalHandler;

  @override
  bool get isReady => ready;

  @override
  void dispose() => disposals++;

  @override
  Future<void> ensureModel() async => prepares++;

  @override
  Future<bool> startListening({
    required String langCode,
    required void Function(String text, int segmentMs) onFinal,
    void Function()? onSpeechStart,
    void Function()? onSegment,
    List<String> promptHints = const [],
  }) async {
    language = langCode;
    hints = promptHints;
    finalHandler = onFinal;
    return startResult;
  }

  @override
  Future<void> stopListening({bool keepPendingTranscripts = false}) async {
    stops++;
  }
}

void main() {
  group('WhisperSttEngine', () {
    test('adapts local Whisper transcripts into final hypotheses', () async {
      final capture = _FakeWhisperCapture();
      final engine = WhisperSttEngine(capture);
      final hypotheses = <SttHypothesis>[];

      expect(engine.id, 'whisper');
      expect(engine.capture, SttCapture.ownsMicrophone);
      expect(engine.isReady, isTrue);
      expect(engine.supportsLanguage('fr'), isTrue);
      expect(engine.supportsLanguage('ko'), isTrue);
      expect(engine.supportsLanguage('xx'), isFalse);
      expect(
        await engine.start(
          langCode: 'ko',
          promptHints: const ['고양이', 'cat'],
          onHypothesis: hypotheses.add,
        ),
        isTrue,
      );
      expect(capture.language, 'ko');
      expect(capture.hints, ['고양이', 'cat']);

      capture.finalHandler!('고양이', 610);
      expect(hypotheses, hasLength(1));
      expect(hypotheses.single.engineId, 'whisper');
      expect(hypotheses.single.transcript, '고양이');
      expect(hypotheses.single.candidates, ['고양이']);
      expect(hypotheses.single.confidence, 0.7);
      expect(hypotheses.single.isFinal, isTrue);
    });

    test('prepares, stops and disposes the local engine', () async {
      final capture = _FakeWhisperCapture(ready: false, startResult: false);
      final engine = WhisperSttEngine(capture);

      expect(engine.isReady, isFalse);
      await engine.prepare();
      expect(capture.prepares, 1);
      expect(
        await engine.start(
          langCode: 'fr',
          promptHints: const [],
          onHypothesis: (_) {},
        ),
        isFalse,
      );
      engine.feed(Uint8List(32));
      await engine.stop();
      engine.dispose();
      expect(capture.stops, 1);
      expect(capture.disposals, 1);
    });
  });
}
