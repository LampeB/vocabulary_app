import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/services/speech/speech_recognition_service.dart';
import 'package:vocab_kr/services/speech/system_stt_engine.dart';

class _FakeRecognizer implements SystemSpeechRecognizer {
  bool initializeResult = true;
  bool throwOnListen = false;
  bool throwOnStop = false;
  Completer<void>? pendingStop;
  var initializeCalls = 0;
  var listenCalls = 0;
  var stopCalls = 0;
  String? localeId;
  Duration? pauseFor;
  Duration? listenFor;
  bool? onDevice;
  void Function(String message, bool permanent)? onError;
  void Function(String status)? onStatus;
  void Function(double level)? onSoundLevel;
  void Function(SystemRecognitionResult result)? onResult;

  @override
  Future<bool> supportsOnDeviceRecognition() async => true;

  @override
  Future<bool> initialize({
    required void Function(String message, bool permanent) onError,
    required void Function(String status) onStatus,
  }) async {
    initializeCalls++;
    this.onError = onError;
    this.onStatus = onStatus;
    return initializeResult;
  }

  @override
  Future<void> listen({
    required void Function(double level) onSoundLevel,
    required void Function(SystemRecognitionResult result) onResult,
    required String localeId,
    required bool onDevice,
    required Duration? pauseFor,
    required Duration? listenFor,
  }) async {
    listenCalls++;
    if (throwOnListen) throw StateError('platform unavailable');
    this.onSoundLevel = onSoundLevel;
    this.onResult = onResult;
    this.localeId = localeId;
    this.onDevice = onDevice;
    this.pauseFor = pauseFor;
    this.listenFor = listenFor;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    if (throwOnStop) throw StateError('platform refused to release');
    await pendingStop?.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'initializes once and translates partial/final hypotheses with alternates',
    () async {
      final native = _FakeRecognizer();
      final service = SpeechRecognitionService(recognizer: native);
      final partials = <(String, List<String>)>[];
      final finals = <(String, List<String>)>[];

      expect(
        await service.startListening(langCode: 'ko', onResult: (_, _) {}),
        isFalse,
      );
      expect(await service.initialize(), isTrue);
      expect(await service.initialize(), isTrue);
      expect(native.initializeCalls, 1);

      expect(
        await service.startListening(
          langCode: 'ko',
          onDevice: true,
          onResult: (word, candidates) => finals.add((word, candidates)),
          onPartial: (word, candidates) => partials.add((word, candidates)),
          pauseFor: const Duration(seconds: 2),
          listenFor: const Duration(seconds: 7),
        ),
        isTrue,
      );
      expect(native.localeId, 'ko-KR');
      expect(native.onDevice, isTrue);
      expect(native.pauseFor, const Duration(seconds: 2));
      expect(native.listenFor, const Duration(seconds: 7));

      native.onResult!(
        const SystemRecognitionResult(
          words: '고양',
          isFinal: false,
          confidence: .4,
          alternates: [
            (words: '고양이', confidence: .9),
            (words: '', confidence: 0),
          ],
        ),
      );
      native.onResult!(
        const SystemRecognitionResult(
          words: '고양이',
          isFinal: true,
          confidence: .95,
          alternates: [(words: '고양', confidence: .2)],
        ),
      );

      expect(partials.single.$1, '고양');
      expect(partials.single.$2, ['고양', '고양이']);
      expect(finals.single.$1, '고양이');
      expect(finals.single.$2, ['고양이', '고양']);
    },
  );

  test(
    'deduplicates session-end statuses and handles normal versus real errors',
    () async {
      final native = _FakeRecognizer();
      var now = DateTime.utc(2026, 9, 17, 12);
      final service = SpeechRecognitionService(
        recognizer: native,
        clock: () => now,
      );
      var done = 0;
      final errors = <String>[];
      service.onListeningDone = () => done++;
      service.onError = errors.add;
      await service.initialize();

      native.onStatus!('listening');
      now = now.add(const Duration(milliseconds: 350));
      expect(service.isListening, isTrue);
      expect(service.listenElapsedMs, 350);
      native.onStatus!('notListening');
      expect(done, 0, reason: 'a native final can still arrive');
      native.onStatus!('done');
      expect(service.isListening, isFalse);
      expect(done, 1);

      await service.startListening(langCode: 'fr', onResult: (_, _) {});
      native.onError!('error_no_match', false);
      native.onError!('error_no_match', false);
      expect(errors, isEmpty);
      expect(done, 2);

      await service.startListening(langCode: 'fr', onResult: (_, _) {});
      native.onSoundLevel!(1.2);
      now = now.add(const Duration(seconds: 1));
      native.onSoundLevel!(4.8);
      native.onError!('error_audio', true);
      expect(errors, ['error_audio']);
      expect(service.lastError, 'error_audio');
      expect(done, 3);
    },
  );

  test(
    'a release rejection prevents another native start until cleanup succeeds',
    () async {
      final native = _FakeRecognizer();
      final delays = <Duration>[];
      final service = SpeechRecognitionService(
        recognizer: native,
        delay: (duration) async => delays.add(duration),
      );
      await service.initialize();
      bool started = await service.startListening(
        langCode: 'en',
        onResult: (_, _) {},
      );
      expect(started, isTrue);
      native.onStatus!('notListening');
      native.throwOnStop = true;

      await expectLater(
        service.startListening(langCode: 'en', onResult: (_, _) {}),
        throwsStateError,
      );
      expect(native.stopCalls, 1);
      expect(native.listenCalls, 1);
      expect(delays, isEmpty);

      native.throwOnStop = false;
      started = await service.startListening(
        langCode: 'en',
        onResult: (_, _) {},
      );
      expect(started, isTrue);
      expect(native.stopCalls, 2);
      expect(native.listenCalls, 2);
      expect(delays, [const Duration(milliseconds: 200)]);
      await service.stopListening();
      service.dispose();
    },
  );

  test(
    'stop timeout retains the native operation through retry and dispose',
    () async {
      final native = _FakeRecognizer()..pendingStop = Completer<void>();
      final service = SpeechRecognitionService(
        recognizer: native,
        releaseTimeout: const Duration(milliseconds: 40),
      );
      await service.initialize();
      await service.startListening(langCode: 'en', onResult: (_, _) {});
      await expectLater(
        service.stopListening(),
        throwsA(isA<TimeoutException>()),
      );
      await expectLater(
        service.startListening(langCode: 'en', onResult: (_, _) {}),
        throwsA(isA<TimeoutException>()),
      );
      expect(native.stopCalls, 1);
      expect(native.listenCalls, 1);
      expect(service.isListening, isTrue);

      service.dispose();
      native.pendingStop!.complete();
      await service.stopListening();
      expect(native.stopCalls, 1);
      expect(service.isListening, isFalse);
    },
  );

  test('keeps the service unready when native initialization fails', () async {
    final native = _FakeRecognizer()..initializeResult = false;
    final service = SpeechRecognitionService(recognizer: native);

    expect(await service.initialize(), isFalse);
    expect(
      await service.startListening(langCode: 'fr', onResult: (_, _) {}),
      isFalse,
    );
  });

  testWidgets(
    'Android requests on-device speech and keeps partials provisional',
    (tester) async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const system = MethodChannel('vocab_kr/system_speech');
      const speech = MethodChannel('plugin.csdcorp.com/speech_to_text');
      var installed = false;
      messenger.setMockMethodCallHandler(system, (call) async {
        expect(call.method, 'supportsOnDeviceRecognition');
        return installed;
      });
      final listenOptions = <Map<Object?, Object?>>[];
      messenger.setMockMethodCallHandler(speech, (call) async {
        if (call.method == 'listen') {
          listenOptions.add(call.arguments as Map<Object?, Object?>);
        }
        return true;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(system, null);
        messenger.setMockMethodCallHandler(speech, null);
      });
      final engine = SystemSttEngine(
        SpeechRecognitionService(),
        onDevice: true,
      );
      await engine.prepare();
      expect(engine.isReady, isFalse);
      expect(
        await engine.start(
          langCode: 'ko',
          promptHints: const [],
          onHypothesis: (_) {},
        ),
        isFalse,
      );
      expect(listenOptions, isEmpty);

      installed = true;
      await engine.prepare();
      expect(engine.isReady, isTrue);
      final hypotheses = <bool>[];
      expect(
        await engine.start(
          langCode: 'ko',
          promptHints: const [],
          onHypothesis: (hypothesis) => hypotheses.add(hypothesis.isFinal),
        ),
        isTrue,
      );
      expect(listenOptions.single['onDevice'], isTrue);
      expect(listenOptions.single['pauseFor'], isNull);
      await messenger.handlePlatformMessage(
        speech.name,
        speech.codec.encodeMethodCall(
          MethodCall(
            'textRecognition',
            jsonEncode({
              'resultType': 0,
              'alternates': [
                {'recognizedWords': '사과가', 'confidence': .8},
              ],
            }),
          ),
        ),
        null,
      );
      expect(hypotheses, [false]);
      await engine.stop();
      await tester.pump(const Duration(seconds: 3));
      expect(
        hypotheses,
        [false],
        reason: 'the plugin must not promote the last partial to final',
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
