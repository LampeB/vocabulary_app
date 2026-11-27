import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:ponderin_whisper/ponderin_whisper.dart';
import 'package:vocab_kr/services/speech/pcm_microphone.dart';
import 'package:vocab_kr/services/speech/whisper_speech_service.dart';

class _TestPaths extends PathProviderPlatform {
  _TestPaths(this.directory);
  final String directory;

  @override
  Future<String?> getTemporaryPath() async => directory;
}

class _UnusedMicrophone implements PcmMicrophone {
  @override
  Future<bool> hasPermission() async => false;
  @override
  Future<Stream<Uint8List>> startVoiceStream() => throw UnimplementedError();
  @override
  Future<void> stop() async {}
  @override
  void dispose() {}
}

class _PendingWhisper extends PonderinWhisper {
  _PendingWhisper() : super(model: PonderinWhisperModel.base);
  final started = Completer<File>();
  final result = Completer<String>();

  @override
  Future<String> transcribe({
    required String audioPath,
    required String language,
    String initialPrompt = '',
  }) async {
    final capture = File(audioPath);
    started.complete(capture);
    final response = await result.future;
    // The file must survive the entire async model load/inference operation.
    expect(await capture.exists(), isTrue);
    return response;
  }
}

void main() {
  late Directory directory;
  late PathProviderPlatform originalPaths;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('ponderin-wav-test-');
    originalPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _TestPaths(directory.path);
  });

  tearDown(() async {
    PathProviderPlatform.instance = originalPaths;
    await directory.delete(recursive: true);
  });

  for (final fails in [false, true]) {
    test(
      'capture survives pending inference and is cleaned (failure=$fails)',
      () async {
        final whisper = _PendingWhisper();
        final service = WhisperSpeechService(
          microphone: _UnusedMicrophone(),
          whisper: whisper,
          modelReady: true,
        );
        final pending = service.transcribeSegment(
          pcm16: Uint8List(6400),
          langCode: 'fr',
          promptHints: const ['pomme'],
        );
        final capture = await whisper.started.future;
        expect(await capture.exists(), isTrue);
        if (fails) {
          final assertion = expectLater(pending, throwsStateError);
          whisper.result.completeError(StateError('native inference failed'));
          await assertion;
        } else {
          whisper.result.complete('Pomme.');
          expect(await pending, 'Pomme');
        }
        expect(await capture.exists(), isFalse);
        service.dispose();
      },
    );
  }
}
