import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/services/speech/elevenlabs_speech_service.dart';
import 'package:vocab_kr/services/speech/pcm_microphone.dart';

class _FakeMicrophone implements PcmMicrophone {
  _FakeMicrophone({
    this.permissionGranted = true,
    this.startError,
    this.stopError,
  });

  final bool permissionGranted;
  final Object? startError;
  final Object? stopError;
  final stream = StreamController<Uint8List>.broadcast(sync: true);
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
  Future<void> stop() async {
    stops++;
    if (stopError != null) throw stopError!;
  }

  @override
  void dispose() => disposals++;
}

class _TranscriptionCall {
  const _TranscriptionCall(this.pcm16, this.langCode, this.expectedWord);

  final Uint8List pcm16;
  final String langCode;
  final String expectedWord;
}

class _FakeTranscriber implements CloudTranscriber {
  _FakeTranscriber({this.response, this.error, this.pendingResponse});

  final String? response;
  final Object? error;
  final Future<String?>? pendingResponse;
  final calls = <_TranscriptionCall>[];

  @override
  Future<String?> transcribe({
    required Uint8List pcm16,
    required String langCode,
    required String expectedWord,
  }) async {
    calls.add(_TranscriptionCall(pcm16, langCode, expectedWord));
    if (error != null) throw error!;
    if (pendingResponse != null) return pendingResponse!;
    return response;
  }
}

Uint8List _pcmFrame(int value) {
  final samples = Int16List(480); // 30ms of mono 16kHz PCM16.
  samples.fillRange(0, samples.length, value);
  return samples.buffer.asUint8List();
}

/// Feeds one utterance that clears the service's 200ms speech and 450ms
/// silence endpointing rules.
void _emitUtterance(_FakeMicrophone microphone) {
  // Seed a quiet room baseline before speaking; this mirrors the live stream
  // and lets the adaptive VAD distinguish the following voiced frames.
  microphone.stream.add(_pcmFrame(0));
  for (var i = 0; i < 7; i++) {
    microphone.stream.add(_pcmFrame(2000));
  }
  for (var i = 0; i < 15; i++) {
    microphone.stream.add(_pcmFrame(0));
  }
}

void main() {
  group('ElevenLabsSpeechService', () {
    test('does not open the microphone without permission', () async {
      final mic = _FakeMicrophone(permissionGranted: false);
      final service = ElevenLabsSpeechService(microphone: mic);

      expect(
        await service.startListening(
          langCode: 'fr',
          promptHints: const ['thé'],
          onFinal: (_, __) {},
        ),
        isFalse,
      );
      expect(mic.starts, 0);
      expect(service.isListening, isFalse);
      mic.stream.close();
    });

    test('returns unavailable when the microphone cannot start', () async {
      final mic = _FakeMicrophone(startError: StateError('microphone busy'));
      final service = ElevenLabsSpeechService(microphone: mic);

      expect(
        await service.startListening(
          langCode: 'fr',
          promptHints: const [],
          onFinal: (_, __) {},
        ),
        isFalse,
      );
      expect(service.isListening, isFalse);
      mic.stream.close();
    });

    test('segments speech and sends cleaned Scribe text to the quiz', () async {
      final mic = _FakeMicrophone();
      final cloud = _FakeTranscriber(response: '  pomme! ');
      final service = ElevenLabsSpeechService(
        microphone: mic,
        transcriber: cloud,
      );
      final received = Completer<(String, int)>();

      expect(
        await service.startListening(
          langCode: 'fr',
          promptHints: const ['pomme', 'une pomme'],
          onFinal: (text, durationMs) => received.complete((text, durationMs)),
        ),
        isTrue,
      );
      _emitUtterance(mic);

      final result = await received.future.timeout(const Duration(seconds: 1));
      expect(result.$1, 'pomme');
      expect(result.$2, greaterThanOrEqualTo(600));
      expect(cloud.calls, hasLength(1));
      expect(cloud.calls.single.langCode, 'fr');
      expect(cloud.calls.single.expectedWord, 'pomme');
      expect(cloud.calls.single.pcm16, isNotEmpty);

      await service.stopListening();
      mic.stream.close();
    });

    test('reports blank and failed cloud transcriptions to the race', () async {
      for (final cloud in [
        _FakeTranscriber(response: ' [music] '),
        _FakeTranscriber(error: StateError('offline')),
      ]) {
        final mic = _FakeMicrophone();
        final service = ElevenLabsSpeechService(
          microphone: mic,
          transcriber: cloud,
        );
        final sessionEnded = Completer<void>();

        await service.startListening(
          langCode: 'ko',
          promptHints: const [],
          onFinal: (_, __) => fail('a bad transcript must not be final'),
          onSessionEnd: sessionEnded.complete,
        );
        _emitUtterance(mic);
        await sessionEnded.future.timeout(const Duration(seconds: 1));

        await service.stopListening();
        mic.stream.close();
      }
    });

    test(
        'stops an existing capture before opening the next one and disposes it',
        () async {
      final mic = _FakeMicrophone();
      final service = ElevenLabsSpeechService(microphone: mic);

      await service.startListening(
        langCode: 'en',
        promptHints: const [],
        onFinal: (_, __) {},
      );
      await service.startListening(
        langCode: 'ko',
        promptHints: const [],
        onFinal: (_, __) {},
      );
      expect(mic.starts, 2);
      expect(mic.stops, 1);

      service.dispose();
      await Future<void>.delayed(Duration.zero);
      expect(mic.stops, 2);
      expect(mic.disposals, 1);
      mic.stream.close();
    });

    test('drops excess completed segments while cloud work is backlogged',
        () async {
      final mic = _FakeMicrophone();
      final pending = Completer<String?>();
      final cloud = _FakeTranscriber(pendingResponse: pending.future);
      final service = ElevenLabsSpeechService(
        microphone: mic,
        transcriber: cloud,
      );
      await service.startListening(
        langCode: 'fr',
        promptHints: const [],
        onFinal: (_, __) {},
      );

      _emitUtterance(mic);
      _emitUtterance(mic);
      _emitUtterance(mic);
      await Future<void>.delayed(Duration.zero);
      expect(cloud.calls, hasLength(1));

      pending.complete('pomme');
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(cloud.calls, hasLength(2));
      await service.stopListening();
      mic.stream.close();
    });

    test('swallows a microphone stop error', () async {
      final mic = _FakeMicrophone(stopError: StateError('already closed'));
      final service = ElevenLabsSpeechService(microphone: mic);
      await service.startListening(
        langCode: 'fr',
        promptHints: const [],
        onFinal: (_, __) {},
      );

      await service.stopListening();
      expect(service.isListening, isFalse);
      expect(mic.stops, 1);
      mic.stream.close();
    });
  });
}
