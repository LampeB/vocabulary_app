import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/services/speech/elevenlabs_stt_engine.dart';
import 'package:vocab_kr/services/speech/stt_engine.dart';

class _FakeCapture implements CloudSpeechCapture {
  bool startResult = true;
  String? lang;
  List<String>? hints;
  void Function(String, int)? finalHandler;
  void Function()? sessionEnd;
  var stopped = 0;
  var disposed = 0;

  @override
  Future<bool> startListening(
      {required String langCode,
      required List<String> promptHints,
      required void Function(String, int) onFinal,
      void Function()? onSessionEnd}) async {
    lang = langCode;
    hints = promptHints;
    finalHandler = onFinal;
    sessionEnd = onSessionEnd;
    return startResult;
  }

  @override
  Future<void> stopListening() async => stopped++;

  @override
  void dispose() => disposed++;
}

void main() {
  test('adapts a Scribe transcript into a final high-confidence hypothesis',
      () async {
    final capture = _FakeCapture();
    final engine = ElevenLabsSttEngine(capture);
    SttHypothesis? result;
    var ended = false;

    expect(
        await engine.start(
            langCode: 'ko',
            promptHints: ['안녕하세요'],
            onHypothesis: (value) => result = value,
            onSessionEnd: () => ended = true),
        isTrue);
    capture.finalHandler!('안녕하세요', 520);
    capture.sessionEnd!();

    expect(engine.id, 'elevenlabs');
    expect(engine.capture, SttCapture.ownsMicrophone);
    expect(engine.supportsLanguage('ko'), isTrue);
    expect(engine.supportsLanguage('xx'), isFalse);
    expect(capture.lang, 'ko');
    expect(capture.hints, ['안녕하세요']);
    expect(result!.transcript, '안녕하세요');
    expect(result!.candidates, ['안녕하세요']);
    expect(result!.confidence, .95);
    expect(result!.isFinal, isTrue);
    expect(ended, isTrue);
  });

  test('delegates stop and disposal; PCM feed is intentionally ignored',
      () async {
    final capture = _FakeCapture()..startResult = false;
    final engine = ElevenLabsSttEngine(capture);
    await engine.prepare();
    expect(engine.isReady, isTrue);
    expect(
        await engine.start(
            langCode: 'fr', promptHints: const [], onHypothesis: (_) {}),
        isFalse);
    engine.feed(Uint8List.fromList([0, 1]));
    await engine.stop();
    engine.dispose();
    expect(capture.stopped, 1);
    expect(capture.disposed, 1);
  });
}
