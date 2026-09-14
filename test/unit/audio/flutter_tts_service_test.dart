import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/services/audio/flutter_tts_service.dart';

const _channel = MethodChannel('flutter_tts');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final calls = <MethodCall>[];
  var engines = <dynamic>['com.samsung.SMT', 'com.google.android.tts'];
  Completer<void>? speakGate;

  setUp(() {
    calls.clear();
    engines = ['com.samsung.SMT', 'com.google.android.tts'];
    speakGate = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      calls.add(call);
      if (call.method == 'getEngines') return engines;
      if (call.method == 'speak' && speakGate != null) {
        await speakGate!.future;
      }
      return 1;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  List<String> names() => calls.map((call) => call.method).toList();

  test('warm-up picks Samsung Korean then configures its locale and pace',
      () async {
    final tts = FlutterTtsService(speechRate: .7, pitch: 1.1);

    await tts.warmUp('ko');

    expect(names(), [
      'getEngines',
      'setEngine',
      'setVolume',
      'awaitSpeakCompletion',
      'setLanguage',
      'setSpeechRate',
      'setPitch',
    ]);
    expect(calls[1].arguments, 'com.samsung.SMT');
    expect(calls[4].arguments, 'ko-KR');
    expect(calls[5].arguments, .7);
    expect(calls[6].arguments, 1.1);
  });

  test('warm-up never repeats native configuration for the active language',
      () async {
    final tts = FlutterTtsService();

    await tts.warmUp('fr');
    final firstSetupCount = calls.length;
    await tts.warmUp('fr');

    expect(calls, hasLength(firstSetupCount));
  });

  test('languages without a preferred installed engine use Google when present',
      () async {
    final tts = FlutterTtsService();

    await tts.warmUp('en');

    expect(calls.where((c) => c.method == 'setEngine').single.arguments,
        'com.google.android.tts');
    expect(calls.where((c) => c.method == 'setLanguage').single.arguments,
        'en-US');
  });

  test(
      'engine discovery failure still configures TTS with the platform default',
      () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      calls.add(call);
      if (call.method == 'getEngines') throw PlatformException(code: 'offline');
      return 1;
    });
    final tts = FlutterTtsService();

    await tts.warmUp('fr');

    expect(
        names(), containsAll(['getEngines', 'setLanguage', 'setSpeechRate']));
    expect(names(), isNot(contains('setEngine')));
  });

  test(
      'speak tracks its active lifetime and stop reaches every initialized voice',
      () async {
    final tts = FlutterTtsService();
    await tts.warmUp('fr');
    await tts.warmUp('ko');
    calls.clear();
    speakGate = Completer<void>();

    final speaking = tts.speak('bonjour', 'fr');
    await Future<void>.delayed(Duration.zero);
    expect(tts.isSpeaking, isTrue);
    await tts.stop();
    expect(names().where((name) => name == 'stop'), hasLength(2));
    speakGate!.complete();
    await speaking;
    expect(tts.isSpeaking, isFalse);
  });

  test('dispose stops every created native voice', () async {
    final tts = FlutterTtsService();
    await tts.warmUp('fr');
    await tts.warmUp('ko');
    calls.clear();

    tts.dispose();
    await Future<void>.delayed(Duration.zero);

    expect(names().where((name) => name == 'stop'), hasLength(2));
  });
}
