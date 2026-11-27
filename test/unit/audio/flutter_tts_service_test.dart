import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/services/audio/audio_player_service.dart';
import 'package:vocab_kr/services/audio/audio_ports.dart';
import 'package:vocab_kr/services/audio/flutter_tts_service.dart';

const _channel = MethodChannel('flutter_tts');

class _NativeSpeechSlot {
  final spoken = <(String, String)>[];
  final languages = <String>[];
  Completer<int>? reply;
  Completer<int>? stopping;
  int overwrites = 0;
  int stopCalls = 0;

  Future<Object?> handle(MethodCall call) async {
    switch (call.method) {
      case 'getEngines':
        return <Object>[];
      case 'setLanguage':
        languages.add(call.arguments as String);
      case 'speak':
        spoken.add((call.arguments as String, languages.last));
        if (reply != null) overwrites++;
        return (reply = Completer<int>()).future;
      case 'stop':
        stopCalls++;
        final acknowledgement = await stopping?.future ?? 1;
        if (acknowledgement == 1) reply = null;
        return acknowledgement;
    }
    return 1;
  }

  void finish() {
    final completed = reply!;
    reply = null;
    completed.complete(1);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final calls = <MethodCall>[];
  var engines = <dynamic>['com.samsung.SMT', 'com.google.android.tts'];
  Completer<void>? speakGate;
  Completer<void>? configurationGate;
  String? delayedMethod;
  String? rejectedMethod;
  Object? speakResult;

  setUp(() {
    calls.clear();
    engines = ['com.samsung.SMT', 'com.google.android.tts'];
    speakGate = null;
    configurationGate = null;
    delayedMethod = null;
    rejectedMethod = null;
    speakResult = 1;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          calls.add(call);
          if (call.method == delayedMethod) await configurationGate!.future;
          if (call.method == 'getEngines') return engines;
          if (call.method == rejectedMethod) return 0;
          if (call.method == 'speak' && speakGate != null) {
            await speakGate!.future;
          }
          if (call.method == 'speak') return speakResult;
          return 1;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  List<String> names() => calls.map((call) => call.method).toList();

  test(
    'native speech keeps its voice and reply until the utterance ends',
    () async {
      final native = _NativeSpeechSlot();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, native.handle);
      final tts = FlutterTtsService();

      final first = tts.speak('chat', 'fr');
      final second = tts.speak('고양이', 'ko');
      await Future<void>.delayed(Duration.zero);
      expect(native.spoken, [('chat', 'fr-FR')]);
      expect(native.languages, ['fr-FR']);
      expect(tts.isSpeaking, isTrue);

      native.finish();
      await first.timeout(const Duration(seconds: 1));
      await Future<void>.delayed(Duration.zero);
      expect(native.spoken, [('chat', 'fr-FR'), ('고양이', 'ko-KR')]);
      expect(native.overwrites, 0);
      expect(tts.isSpeaking, isTrue);
      native.finish();
      await second.timeout(const Duration(seconds: 1));
      expect(tts.isSpeaking, isFalse);
    },
  );

  test(
    'confirmed stop cancels active and queued speech and releases the next generation',
    () async {
      final native = _NativeSpeechSlot()..stopping = Completer<int>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, native.handle);
      final tts = FlutterTtsService();

      final cancelled = Future.wait([
        expectLater(
          tts.speak('ancien', 'fr'),
          throwsA(isA<AudioPlaybackCancelled>()),
        ),
        expectLater(
          tts.speak('en attente', 'ko'),
          throwsA(isA<AudioPlaybackCancelled>()),
        ),
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(native.spoken, [('ancien', 'fr-FR')]);
      final lateReply = native.reply!;
      final stop = tts.stop();
      final fresh = tts.speak('nouveau', 'fr');
      await Future<void>.delayed(Duration.zero);
      expect(native.stopCalls, 1);
      expect(tts.isSpeaking, isTrue);
      expect(native.spoken, [('ancien', 'fr-FR')]);
      expect(native.languages, ['fr-FR']);

      native.stopping!.complete(1);
      await stop.timeout(const Duration(seconds: 1));
      await cancelled.timeout(const Duration(seconds: 1));
      await Future<void>.delayed(Duration.zero);
      expect(native.spoken, [('ancien', 'fr-FR'), ('nouveau', 'fr-FR')]);
      expect(native.overwrites, 0);
      expect(lateReply.isCompleted, isFalse);
      expect(tts.isSpeaking, isTrue);
      lateReply.complete(1);
      await Future<void>.delayed(Duration.zero);
      expect(tts.isSpeaking, isTrue);
      native.finish();
      await fresh.timeout(const Duration(seconds: 1));
      expect(tts.isSpeaking, isFalse);
    },
  );

  test('a fresh voice waits for an interrupted native engine switch', () async {
    final tts = FlutterTtsService();
    delayedMethod = 'setEngine';
    final engine = configurationGate = Completer<void>();
    final cancelled = expectLater(
      tts.speak('ancien', 'fr'),
      throwsA(isA<AudioPlaybackCancelled>()),
    );
    await Future<void>.delayed(Duration.zero);
    expect(names(), ['getEngines', 'setEngine']);
    await tts.stop();
    await cancelled;

    delayedMethod = null;
    final fresh = tts.speak('새로운', 'ko');
    await Future<void>.delayed(Duration.zero);
    expect(names(), ['getEngines', 'setEngine', 'stop']);
    engine.complete();
    await fresh.timeout(const Duration(seconds: 1));
    expect(
      calls.where((call) => call.method == 'speak').single.arguments,
      '새로운',
    );
    expect(tts.isSpeaking, isFalse);
  });

  test(
    'a rejected locale is retried before speak on the same locale',
    () async {
      final tts = FlutterTtsService();
      rejectedMethod = 'setLanguage';
      await expectLater(tts.speak('책', 'ko'), throwsA(isA<TtsRejected>()));
      expect(names(), isNot(contains('speak')));

      rejectedMethod = null;
      await tts.speak('책', 'ko');
      expect(names().where((name) => name == 'setLanguage'), hasLength(2));
      expect(names(), contains('speak'));
    },
  );

  test('speak zero is rejected and a completed null result is valid', () async {
    final tts = FlutterTtsService();
    rejectedMethod = 'speak';
    await expectLater(tts.speak('책', 'ko'), throwsA(isA<TtsRejected>()));
    expect(tts.isSpeaking, isFalse);

    rejectedMethod = null;
    speakResult = null;
    await tts.speak('책', 'ko');
    expect(names().where((name) => name == 'setLanguage'), hasLength(1));
  });

  test(
    'warm-up picks Samsung Korean then configures its locale and pace',
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
    },
  );

  test(
    'warm-up never repeats native configuration for the active language',
    () async {
      final tts = FlutterTtsService();

      await tts.warmUp('fr');
      final firstSetupCount = calls.length;
      await tts.warmUp('fr');

      expect(calls, hasLength(firstSetupCount));
    },
  );

  test(
    'languages without a preferred installed engine use Google when present',
    () async {
      final tts = FlutterTtsService();

      await tts.warmUp('en');

      expect(
        calls.where((c) => c.method == 'setEngine').single.arguments,
        'com.google.android.tts',
      );
      expect(
        calls.where((c) => c.method == 'setLanguage').single.arguments,
        'en-US',
      );
    },
  );

  test(
    'engine discovery failure still configures TTS with the platform default',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, (call) async {
            calls.add(call);
            if (call.method == 'getEngines') {
              throw PlatformException(code: 'offline');
            }
            return 1;
          });
      final tts = FlutterTtsService();

      await tts.warmUp('fr');

      expect(
        names(),
        containsAll(['getEngines', 'setLanguage', 'setSpeechRate']),
      );
      expect(names(), isNot(contains('setEngine')));
    },
  );

  test(
    'speak tracks its active lifetime and stop reaches every initialized voice',
    () async {
      final tts = FlutterTtsService();
      await tts.warmUp('fr');
      await tts.warmUp('ko');
      calls.clear();
      speakGate = Completer<void>();

      final speaking = tts.speak('bonjour', 'fr');
      final cancelled = expectLater(
        speaking,
        throwsA(isA<AudioPlaybackCancelled>()),
      );
      await Future<void>.delayed(Duration.zero);
      expect(tts.isSpeaking, isTrue);
      await tts.stop();
      expect(names().where((name) => name == 'stop'), hasLength(2));
      await cancelled;
      expect(tts.isSpeaking, isFalse);
      speakGate!.complete();
    },
  );

  for (final lateReply in [false, true]) {
    test(
      'confirmed stop retires unanswered speech (late reply: $lateReply)',
      () async {
        final previous = Completer<int>();
        final next = Completer<int>();
        final firstSpeak = Completer<void>();
        final secondSpeak = Completer<void>();
        final stops = <Completer<int>>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(_channel, (call) async {
              switch (call.method) {
                case 'getEngines':
                  return <Object>[];
                case 'speak':
                  if (call.arguments == 'ancien') {
                    firstSpeak.complete();
                    return previous.future;
                  }
                  secondSpeak.complete();
                  return next.future;
                case 'stop':
                  final reply = Completer<int>();
                  stops.add(reply);
                  return reply.future;
              }
              return 1;
            });

        final tts = FlutterTtsService();
        final interrupted = expectLater(
          tts.speak('ancien', 'fr'),
          throwsA(isA<AudioPlaybackCancelled>()),
        );
        await firstSpeak.future;
        final refusal = expectLater(tts.stop(), throwsA(isA<TtsRejected>()));
        expect(stops, hasLength(1));
        expect(tts.isSpeaking, isTrue);
        stops.single.complete(0);
        await refusal;
        expect(tts.isSpeaking, isTrue);

        final release = tts.stop();
        expect(identical(tts.stop(), release), isTrue);
        expect(stops, hasLength(2));
        expect(tts.isSpeaking, isTrue);
        stops.last.complete(1);
        await release;
        await interrupted.timeout(const Duration(seconds: 1));
        expect(previous.isCompleted, isFalse);
        expect(tts.isSpeaking, isFalse);

        final fresh = tts.speak('nouveau', 'fr');
        await secondSpeak.future;
        expect(tts.isSpeaking, isTrue);
        if (lateReply) {
          previous.completeError(PlatformException(code: 'LateOldSpeechError'));
          await Future<void>.delayed(Duration.zero);
          expect(tts.isSpeaking, isTrue);
        }
        next.complete(1);
        await fresh.timeout(const Duration(seconds: 1));
        expect(tts.isSpeaking, isFalse);
      },
    );
  }

  for (final required in [false, true]) {
    test(
      'player handles interrupted device speech (required: $required)',
      () async {
        final tts = FlutterTtsService();
        final audio = AudioPlayerService(usePremium: false, tts: tts);
        speakGate = Completer<void>();
        final playback = audio.speak(
          'bonjour',
          'fr',
          requirePlayback: required,
        );
        final result = required
            ? expectLater(playback, throwsA(isA<AudioPlaybackCancelled>()))
            : playback;
        await Future<void>.delayed(Duration.zero);
        expect(audio.isSpeaking, isTrue);
        await tts.stop();
        await result.timeout(const Duration(seconds: 1));
        expect(speakGate!.isCompleted, isFalse);
        expect(audio.isSpeaking, isFalse);
      },
    );
  }

  test('dispose stops every created native voice', () async {
    final tts = FlutterTtsService();
    await tts.warmUp('fr');
    await tts.warmUp('ko');
    calls.clear();

    await tts.dispose();

    expect(names().where((name) => name == 'stop'), hasLength(2));
  });

  for (final dispose in [false, true]) {
    for (final method in ['getEngines', 'setLanguage']) {
      test(
        '${dispose ? 'dispose' : 'stop'} cancels speak waiting for $method',
        () async {
          final tts = FlutterTtsService();
          if (method == 'setLanguage') {
            await tts.warmUp('fr');
            await tts.warmUp('ko');
            calls.clear();
          }
          delayedMethod = method;
          final gate = configurationGate = Completer<void>();
          final speaking = tts.speak('bonjour', 'fr');
          final cancelled = expectLater(
            speaking,
            throwsA(isA<AudioPlaybackCancelled>()),
          );
          await Future<void>.delayed(Duration.zero);
          expect(names(), [method]);

          if (dispose) {
            await tts.dispose();
          } else {
            await tts.stop();
          }
          await cancelled.timeout(const Duration(seconds: 1));
          gate.complete();
          await Future<void>.delayed(Duration.zero);
          expect(names().where((name) => name != 'stop'), [method]);
          expect(tts.isSpeaking, isFalse);

          calls.clear();
          await tts.speak('안녕', 'ko');
          if (dispose) {
            expect(names(), isEmpty);
          } else {
            // A cancelled language switch left the native language unknown.
            expect(names(), containsAll(['setLanguage', 'speak']));
          }
        },
      );
    }
  }
}
