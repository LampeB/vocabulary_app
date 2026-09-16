import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/services/speech/stt_corpus_recorder.dart';

class _FakeRecorder implements CorpusAudioRecorder {
  bool permission = true;
  bool writeCapture = true;
  String? returnedPath;
  String? startedPath;
  var permissionCalls = 0;
  var stopCalls = 0;
  var disposeCalls = 0;

  @override
  Future<bool> hasPermission() async {
    permissionCalls++;
    return permission;
  }

  @override
  Future<void> start(config, {required String path}) async {
    startedPath = path;
  }

  @override
  Future<String?> stop() async {
    stopCalls++;
    final path = returnedPath ?? startedPath;
    if (writeCapture && path != null) {
      await File(path).writeAsBytes(const [1, 2, 3]);
    }
    return path;
  }

  @override
  void dispose() => disposeCalls++;
}

void main() {
  const recordedAt = '2026-09-13T12:00:00.000Z';

  SttCorpusSample sample() => SttCorpusSample(
        id: 'sample_fr',
        word: 'bonjour',
        langCode: 'fr',
        path: '/tmp/sample.wav',
        recordedAt: DateTime.parse(recordedAt),
      );

  test('keeps an OpenAI result when a Whisper result is saved afterwards', () {
    final withOpenAi = sample().withOpenAiResult(
      transcript: 'Bonjour.',
      durationMs: 800,
    );
    final withElevenLabs = withOpenAi.withElevenLabsResult(
      transcript: 'bonjour',
      durationMs: 600,
    );
    final updated = withElevenLabs.withWhisperResult(
      transcript: 'bonjour',
      durationMs: 2300,
    );

    expect(updated.openAiTranscript, 'Bonjour.');
    expect(updated.openAiDurationMs, 800);
    expect(updated.elevenLabsTranscript, 'bonjour');
    expect(updated.elevenLabsDurationMs, 600);
    expect(updated.whisperTranscript, 'bonjour');
    expect(updated.whisperDurationMs, 2300);
  });

  Future<Directory> tempDirectory() =>
      Directory.systemTemp.createTemp('stt-corpus-test-');

  test('captures a labelled WAV then persists all benchmark results', () async {
    final directory = await tempDirectory();
    addTearDown(() => directory.delete(recursive: true));
    final native = _FakeRecorder();
    final capturedAt = DateTime.utc(2026, 9, 16, 12);
    final recorder = SttCorpusRecorder(
      recorder: native,
      documentsDirectory: () async => directory,
      clock: () => capturedAt,
    );

    expect(
        await recorder.start(
          word: '  안녕하세요  ',
          langCode: 'ko',
          listId: 'food',
          conceptId: 'hello',
        ),
        isTrue);
    expect(recorder.isRecording, isTrue);
    expect(native.startedPath, endsWith('_ko.wav'));

    final saved = await recorder.stop();
    expect(saved, isNotNull);
    expect(saved!.word, '안녕하세요');
    expect(saved.listId, 'food');
    expect(saved.conceptId, 'hello');
    expect(recorder.isRecording, isFalse);

    await recorder.saveWhisperResult(
        sampleId: saved.id, transcript: '안녕하세요', durationMs: 2100);
    await recorder.saveOpenAiResult(
        sampleId: saved.id, transcript: '안녕하세요', durationMs: 700);
    await recorder.saveElevenLabsResult(
        sampleId: saved.id, transcript: '안녕하세요', durationMs: 280);

    final loaded = await recorder.samples();
    expect(loaded, hasLength(1));
    expect(loaded.single.whisperDurationMs, 2100);
    expect(loaded.single.openAiDurationMs, 700);
    expect(loaded.single.elevenLabsDurationMs, 280);
    expect(loaded.single.elevenLabsTranscript, '안녕하세요');
  });

  test('rejects empty words, denied permission, and overlapping captures',
      () async {
    final directory = await tempDirectory();
    addTearDown(() => directory.delete(recursive: true));
    final native = _FakeRecorder();
    final recorder = SttCorpusRecorder(
      recorder: native,
      documentsDirectory: () async => directory,
    );

    expect(await recorder.samples(), isEmpty);
    expect(await recorder.start(word: ' ', langCode: 'fr'), isFalse);
    expect(native.permissionCalls, 0);
    native.permission = false;
    expect(await recorder.start(word: 'bonjour', langCode: 'fr'), isFalse);
    native.permission = true;
    expect(await recorder.start(word: 'bonjour', langCode: 'fr'), isTrue);
    expect(await recorder.start(word: 'encore', langCode: 'fr'), isFalse);
    expect(native.permissionCalls, 2);
  });

  test('does not add a sample when native stop returns no usable file',
      () async {
    final directory = await tempDirectory();
    addTearDown(() => directory.delete(recursive: true));
    final native = _FakeRecorder()..writeCapture = false;
    final recorder = SttCorpusRecorder(
      recorder: native,
      documentsDirectory: () async => directory,
    );

    expect(await recorder.stop(), isNull);
    await recorder.start(word: 'bonjour', langCode: 'fr');
    expect(await recorder.stop(), isNull);
    expect(await recorder.samples(), isEmpty);
  });

  test(
      'returns an empty corpus for a malformed manifest and disposes native audio',
      () async {
    final directory = await tempDirectory();
    addTearDown(() => directory.delete(recursive: true));
    final corpus =
        Directory('${directory.path}${Platform.pathSeparator}stt_corpus');
    await corpus.create();
    await File('${corpus.path}${Platform.pathSeparator}manifest.json')
        .writeAsString('{not json');
    final native = _FakeRecorder();
    final recorder = SttCorpusRecorder(
      recorder: native,
      documentsDirectory: () async => directory,
    );

    expect(await recorder.samples(), isEmpty);
    recorder.dispose();
    expect(native.disposeCalls, 1);
  });

  test('serializes sample metadata with null benchmark fields', () {
    final decoded =
        jsonDecode(jsonEncode(sample().toJson())) as Map<String, dynamic>;
    final restored = SttCorpusSample.fromJson(decoded);
    expect(restored.id, 'sample_fr');
    expect(restored.whisperTranscript, isNull);
    expect(restored.elevenLabsTestedAt, isNull);
  });
}
