import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// A labelled, local-only WAV capture used to benchmark speech recognition.
/// The audio stays in the app sandbox until a developer explicitly extracts it
/// from a debug device; it is never uploaded by this service.
class SttCorpusSample {
  const SttCorpusSample({
    required this.id,
    required this.word,
    required this.langCode,
    required this.path,
    required this.recordedAt,
    this.listId,
    this.conceptId,
    this.whisperTranscript,
    this.whisperDurationMs,
    this.whisperTestedAt,
  });

  final String id;
  final String word;
  final String langCode;
  final String path;
  final DateTime recordedAt;

  /// Optional origin for a paired capture from a vocabulary list.
  final String? listId;
  final String? conceptId;
  final String? whisperTranscript;
  final int? whisperDurationMs;
  final DateTime? whisperTestedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'word': word,
        'langCode': langCode,
        'path': path,
        'recordedAt': recordedAt.toIso8601String(),
        'listId': listId,
        'conceptId': conceptId,
        'whisperTranscript': whisperTranscript,
        'whisperDurationMs': whisperDurationMs,
        'whisperTestedAt': whisperTestedAt?.toIso8601String(),
      };

  factory SttCorpusSample.fromJson(Map<String, dynamic> json) =>
      SttCorpusSample(
        id: json['id'] as String,
        word: json['word'] as String,
        langCode: json['langCode'] as String,
        path: json['path'] as String,
        recordedAt: DateTime.parse(json['recordedAt'] as String),
        listId: json['listId'] as String?,
        conceptId: json['conceptId'] as String?,
        whisperTranscript: json['whisperTranscript'] as String?,
        whisperDurationMs: json['whisperDurationMs'] as int?,
        whisperTestedAt: json['whisperTestedAt'] == null
            ? null
            : DateTime.parse(json['whisperTestedAt'] as String),
      );

  SttCorpusSample withWhisperResult({
    required String? transcript,
    required int? durationMs,
  }) =>
      SttCorpusSample(
        id: id,
        word: word,
        langCode: langCode,
        path: path,
        recordedAt: recordedAt,
        listId: listId,
        conceptId: conceptId,
        whisperTranscript: transcript,
        whisperDurationMs: durationMs,
        whisperTestedAt: DateTime.now(),
      );
}

/// Saves a small labelled corpus for an on-device STT bake-off.
///
/// WAV/16 kHz/mono is intentional: it is the exact format used by the
/// on-device Whisper pipeline, so the files can be replayed through an engine
/// without a lossy conversion or a second microphone capture.
class SttCorpusRecorder {
  final _recorder = AudioRecorder();
  SttCorpusSample? _pending;

  bool get isRecording => _pending != null;

  Future<List<SttCorpusSample>> samples() async {
    final manifest = await _manifest();
    if (!await manifest.exists()) return const [];
    try {
      final decoded = jsonDecode(await manifest.readAsString()) as List;
      return decoded
          .cast<Map<String, dynamic>>()
          .map(SttCorpusSample.fromJson)
          .where((sample) => File(sample.path).existsSync())
          .toList()
        ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    } catch (_) {
      return const [];
    }
  }

  Future<bool> start({
    required String word,
    required String langCode,
    String? listId,
    String? conceptId,
  }) async {
    if (word.trim().isEmpty || isRecording) return false;
    if (!await _recorder.hasPermission()) return false;
    final directory = await _directory();
    final now = DateTime.now();
    final id = '${now.millisecondsSinceEpoch}_$langCode';
    final pending = SttCorpusSample(
      id: id,
      word: word.trim(),
      langCode: langCode,
      path: '${directory.path}${Platform.pathSeparator}$id.wav',
      recordedAt: now,
      listId: listId,
      conceptId: conceptId,
    );
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
        autoGain: true,
        echoCancel: true,
        noiseSuppress: true,
        androidConfig: AndroidRecordConfig(
          audioSource: AndroidAudioSource.voiceRecognition,
        ),
      ),
      path: pending.path,
    );
    _pending = pending;
    return true;
  }

  Future<SttCorpusSample?> stop() async {
    final pending = _pending;
    if (pending == null) return null;
    _pending = null;
    final path = await _recorder.stop();
    if (path == null || !await File(path).exists()) return null;
    final all = await samples();
    final manifest = await _manifest();
    await manifest.writeAsString(jsonEncode([
      pending.toJson(),
      ...all.map((sample) => sample.toJson()),
    ]));
    return pending;
  }

  /// Persists a local Whisper benchmark alongside the capture label.
  Future<void> saveWhisperResult({
    required String sampleId,
    required String? transcript,
    required int? durationMs,
  }) async {
    final all = await samples();
    final updated = all
        .map((sample) => sample.id == sampleId
            ? sample.withWhisperResult(
                transcript: transcript,
                durationMs: durationMs,
              )
            : sample)
        .toList();
    final manifest = await _manifest();
    await manifest.writeAsString(jsonEncode(
      updated.map((sample) => sample.toJson()).toList(),
    ));
  }

  Future<Directory> _directory() async {
    final docs = await getApplicationDocumentsDirectory();
    final directory =
        Directory('${docs.path}${Platform.pathSeparator}stt_corpus');
    if (!await directory.exists()) await directory.create(recursive: true);
    return directory;
  }

  Future<File> _manifest() async {
    final directory = await _directory();
    return File('${directory.path}${Platform.pathSeparator}manifest.json');
  }

  void dispose() => _recorder.dispose();
}
