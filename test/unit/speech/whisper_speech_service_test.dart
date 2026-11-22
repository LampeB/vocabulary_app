import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/services/speech/pcm_microphone.dart';
import 'package:vocab_kr/services/speech/whisper_speech_service.dart';

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
  const _TranscriptionCall(this.pcm16, this.langCode, this.prompt);

  final Uint8List pcm16;
  final String langCode;
  final String prompt;
}

class _FakeTranscriber {
  _FakeTranscriber({this.response, this.error, this.pendingResponse});

  final String? response;
  final Object? error;
  final Future<String>? pendingResponse;
  final calls = <_TranscriptionCall>[];

  Future<String> call({
    required Uint8List pcm16,
    required String langCode,
    required String prompt,
  }) async {
    calls.add(_TranscriptionCall(pcm16, langCode, prompt));
    if (error != null) throw error!;
    if (pendingResponse != null) return pendingResponse!;
    return response!;
  }
}

Uint8List _pcmFrame(int value) {
  final samples = Int16List(480); // 30ms of mono 16kHz PCM16.
  samples.fillRange(0, samples.length, value);
  return samples.buffer.asUint8List();
}

void _emitUtterance(_FakeMicrophone microphone) {
  microphone.stream.add(_pcmFrame(0)); // establish room noise floor
  for (var i = 0; i < 7; i++) {
    microphone.stream.add(_pcmFrame(2000));
  }
  for (var i = 0; i < 24; i++) {
    microphone.stream.add(_pcmFrame(0));
  }
}

void main() {
  group('WhisperSpeechService', () {
    test('does not touch the microphone until the model is ready', () async {
      final mic = _FakeMicrophone();
      final service = WhisperSpeechService(microphone: mic);

      expect(
        await service.startListening(
          langCode: 'fr',
          onFinal: (_, __) {},
        ),
        isFalse,
      );
      expect(mic.starts, 0);
      mic.stream.close();
    });

    test('handles denied permission and a failed microphone start', () async {
      for (final mic in [
        _FakeMicrophone(permissionGranted: false),
        _FakeMicrophone(startError: StateError('microphone busy')),
      ]) {
        final service = WhisperSpeechService(
          microphone: mic,
          modelReady: true,
          segmentTranscriber: _FakeTranscriber(response: 'pomme').call,
        );
        expect(
          await service.startListening(
            langCode: 'fr',
            onFinal: (_, __) {},
          ),
          isFalse,
        );
        expect(service.isListening, isFalse);
        mic.stream.close();
      }
    });

    test('segments speech, exposes onset, and returns a cleaned transcript',
        () async {
      final mic = _FakeMicrophone();
      final transcriber = _FakeTranscriber(response: '  pomme! ');
      final service = WhisperSpeechService(
        microphone: mic,
        modelReady: true,
        segmentTranscriber: transcriber.call,
      );
      final transcript = Completer<(String, int)>();
      var speechOnsets = 0;
      var segments = 0;

      expect(
        await service.startListening(
          langCode: 'fr',
          promptHints: const ['pomme / une pomme'],
          onSpeechStart: () => speechOnsets++,
          onSegment: () => segments++,
          onFinal: (text, durationMs) =>
              transcript.complete((text, durationMs)),
        ),
        isTrue,
      );
      _emitUtterance(mic);

      final result =
          await transcript.future.timeout(const Duration(seconds: 1));
      expect(result.$1, 'pomme');
      expect(result.$2, greaterThanOrEqualTo(900));
      expect(speechOnsets, 1);
      expect(segments, 1);
      expect(transcriber.calls, hasLength(1));
      expect(transcriber.calls.single.langCode, 'fr');
      expect(transcriber.calls.single.prompt, 'pomme, une pomme');
      expect(transcriber.calls.single.pcm16, isNotEmpty);

      await service.stopListening();
      mic.stream.close();
    });

    test('drops stale, blank and failed native results', () async {
      final delayed = Completer<String>();
      final mic = _FakeMicrophone();
      final service = WhisperSpeechService(
        microphone: mic,
        modelReady: true,
        segmentTranscriber:
            _FakeTranscriber(pendingResponse: delayed.future).call,
      );
      var finals = 0;
      await service.startListening(
        langCode: 'ko',
        onFinal: (_, __) => finals++,
      );
      _emitUtterance(mic);
      await Future<void>.delayed(Duration.zero);
      await service.stopListening();
      delayed.complete('고양이');
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(finals, 0);
      mic.stream.close();

      for (final transcriber in [
        _FakeTranscriber(response: ' [music] '),
        _FakeTranscriber(error: StateError('native failure')),
      ]) {
        final nextMic = _FakeMicrophone();
        final nextService = WhisperSpeechService(
          microphone: nextMic,
          modelReady: true,
          segmentTranscriber: transcriber.call,
        );
        await nextService.startListening(
          langCode: 'fr',
          onFinal: (_, __) => fail('invalid output must not be graded'),
        );
        _emitUtterance(nextMic);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        await nextService.stopListening();
        nextMic.stream.close();
      }
    });

    test('bounds a backlogged inference queue and disposes safely', () async {
      final pending = Completer<String>();
      final mic = _FakeMicrophone(stopError: StateError('already closed'));
      final transcriber = _FakeTranscriber(pendingResponse: pending.future);
      final service = WhisperSpeechService(
        microphone: mic,
        modelReady: true,
        segmentTranscriber: transcriber.call,
      );
      await service.startListening(langCode: 'fr', onFinal: (_, __) {});

      for (var i = 0; i < 4; i++) {
        _emitUtterance(mic);
      }
      await Future<void>.delayed(Duration.zero);
      expect(transcriber.calls, hasLength(1));

      pending.complete('pomme');
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(transcriber.calls, hasLength(3));

      await service.stopListening();
      expect(service.isListening, isFalse);
      service.dispose();
      expect(mic.disposals, 1);
      mic.stream.close();
    });
  });

  group('WhisperSpeechService.transcribeSegment (shared capture)', () {
    test('cleans the transcript and builds the prompt from the hints',
        () async {
      final transcriber = _FakeTranscriber(response: ' Pomme. ');
      final service = WhisperSpeechService(
        microphone: _FakeMicrophone(),
        modelReady: true,
        segmentTranscriber: transcriber.call,
      );
      final text = await service.transcribeSegment(
          pcm16: Uint8List(64),
          langCode: 'fr',
          promptHints: const ['pomme / fruit']);
      expect(text, 'Pomme');
      expect(transcriber.calls.single.langCode, 'fr');
      expect(transcriber.calls.single.prompt, 'pomme, fruit');
    });

    test('hallucinations come back as null, not as an answer', () async {
      final service = WhisperSpeechService(
        microphone: _FakeMicrophone(),
        modelReady: true,
        segmentTranscriber:
            _FakeTranscriber(response: 'Sous-titres réalisés par Amara.org')
                .call,
      );
      expect(
          await service.transcribeSegment(
              pcm16: Uint8List(64), langCode: 'fr', promptHints: const []),
          isNull);
    });

    test('refuses to run before the model is ready', () async {
      final service = WhisperSpeechService(microphone: _FakeMicrophone());
      expect(
          service.transcribeSegment(
              pcm16: Uint8List(64), langCode: 'fr', promptHints: const []),
          throwsStateError);
    });

    test('inferences run one at a time; a failure does not jam the queue',
        () async {
      final gate = Completer<String>();
      var active = 0;
      var maxActive = 0;
      var calls = 0;
      Future<String> transcriber({
        required Uint8List pcm16,
        required String langCode,
        required String prompt,
      }) async {
        calls++;
        active++;
        maxActive = active > maxActive ? active : maxActive;
        try {
          if (calls == 1) return await gate.future;
          if (calls == 2) throw StateError('native crash');
          return 'thé';
        } finally {
          active--;
        }
      }

      final service = WhisperSpeechService(
          microphone: _FakeMicrophone(),
          modelReady: true,
          segmentTranscriber: transcriber);
      Future<String?> run() => service.transcribeSegment(
          pcm16: Uint8List(64), langCode: 'fr', promptHints: const []);
      final first = run();
      final second = run();
      final third = run();
      gate.complete('café');
      expect(await first, 'café');
      await expectLater(second, throwsStateError);
      expect(await third, 'thé');
      expect(maxActive, 1);
    });
  });
}
