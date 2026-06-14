import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/config/app_config.dart';
import '../../core/constants/app_constants.dart';

class WhisperSttService {
  final _recorder = AudioRecorder();
  bool _isRecording = false;

  bool get isRecording => _isRecording;

  /// Records a single utterance (VAD-based) and transcribes via Whisper.
  /// [expectedWord] is passed as the prompt to bias Whisper toward the expected answer.
  Future<WhisperResult?> transcribeUtterance({
    required String langCode,
    required String expectedWord,
    Duration maxDuration = const Duration(milliseconds: AppConstants.sttMaxRecordingMs),
    Duration silenceThreshold = const Duration(milliseconds: AppConstants.sttSilenceThresholdMs),
  }) async {
    final path = await _startRecording();
    if (path == null) return null;

    try {
      await _waitForSpeechEnd(silenceThreshold, maxDuration);
      final audioBytes = await _stopRecording(path);
      if (audioBytes == null || audioBytes.isEmpty) return null;
      return await _transcribe(audioBytes, langCode, expectedWord);
    } catch (_) {
      await _stopRecording(path);
      return null;
    }
  }

  Future<String?> _startRecording() async {
    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) return null;

      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/whisper_clip.m4a';

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: AppConstants.audioSampleRate,
          numChannels: 1,
          bitRate: 64000,
        ),
        path: path,
      );
      _isRecording = true;
      return path;
    } catch (_) {
      return null;
    }
  }

  Future<void> _waitForSpeechEnd(
      Duration silenceThreshold, Duration maxDuration) async {
    final deadline = DateTime.now().add(maxDuration);
    DateTime? lastAmplitudeAboveGate;

    while (DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(milliseconds: 100));
      final amp = await _recorder.getAmplitude();
      if (amp.current > AppConstants.sttAmplitudeGateDbfs) {
        lastAmplitudeAboveGate = DateTime.now();
      } else if (lastAmplitudeAboveGate != null) {
        final silent =
            DateTime.now().difference(lastAmplitudeAboveGate) >= silenceThreshold;
        if (silent) break;
      }
    }
  }

  Future<Uint8List?> _stopRecording(String path) async {
    try {
      await _recorder.stop();
      _isRecording = false;
      final file = File(path);
      if (!file.existsSync()) return null;
      final bytes = await file.readAsBytes();
      await file.delete();
      return bytes;
    } catch (_) {
      _isRecording = false;
      return null;
    }
  }

  Future<WhisperResult?> _transcribe(
      Uint8List audioBytes, String langCode, String expectedWord) async {
    try {
      final base64Audio = base64Encode(audioBytes);
      final res = await http.post(
        Uri.parse(AppConfig.whisperEdgeFunctionUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'audio_base64': base64Audio,
          'language': langCode,
          'expected_word': expectedWord,
        }),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return WhisperResult(
        text: (data['text'] as String? ?? '').trim(),
        confidence: (data['confidence'] as num?)?.toDouble(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> cancelRecording() async {
    if (_isRecording) {
      await _recorder.stop();
      _isRecording = false;
    }
  }

  void dispose() {
    _recorder.dispose();
  }
}

class WhisperResult {
  const WhisperResult({required this.text, this.confidence});
  final String text;
  final double? confidence;
}
