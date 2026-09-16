import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:record/record.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/utils/pcm_segmenter.dart';
import '../../core/utils/stt_debug_log.dart';
import 'whisper_speech_service.dart';
import 'elevenlabs_stt_engine.dart';

/// The one microphone capability the cloud capture pipeline needs.
///
/// Keeping the native recorder behind this port lets the timing-sensitive
/// segmentation and request lifecycle be tested without a physical device.
abstract interface class PcmMicrophone {
  Future<bool> hasPermission();
  Future<Stream<Uint8List>> startVoiceStream();
  Future<void> stop();
  void dispose();
}

/// Authenticated server-side Scribe invocation. The client never owns the
/// ElevenLabs key; this boundary is deliberately narrow for deterministic
/// tests of the capture pipeline.
abstract interface class CloudTranscriber {
  Future<String?> transcribe({
    required Uint8List pcm16,
    required String langCode,
    required String expectedWord,
  });
}

// Platform and Supabase bindings need device tests.
// coverage:ignore-start
class _RecordPcmMicrophone implements PcmMicrophone {
  final _recorder = AudioRecorder();

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();

  @override
  Future<Stream<Uint8List>> startVoiceStream() => _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
          autoGain: true,
          echoCancel: true,
          noiseSuppress: true,
          androidConfig: AndroidRecordConfig(
            audioSource: AndroidAudioSource.voiceRecognition,
          ),
        ),
      );

  @override
  Future<void> stop() => _recorder.stop();

  @override
  void dispose() => _recorder.dispose();
}

class _SupabaseCloudTranscriber implements CloudTranscriber {
  @override
  Future<String?> transcribe({
    required Uint8List pcm16,
    required String langCode,
    required String expectedWord,
  }) async {
    final response = await Supabase.instance.client.functions
        .invoke('elevenlabs-stt-proxy', body: {
      'audio_base64': base64Encode(pcm16),
      'audio_format': 'pcm_s16le_16',
      'language': langCode,
      'expected_word': expectedWord,
    }).timeout(const Duration(seconds: 5));
    final data = response.data;
    return data is Map ? data['text'] as String? : null;
  }
}
// coverage:ignore-end

/// Captures a short answer locally, then sends the completed WAV to the
/// authenticated ElevenLabs Scribe proxy. The ElevenLabs key never reaches
/// the phone; Supabase owns it and validates the user's session first.
///
/// This deliberately mirrors Whisper's capture/VAD contract: the same
/// pre-roll, echo cancellation and endpointing are used regardless of which
/// recognizer wins. On an unavailable network the engine ends promptly, so
/// the quiz can reopen the mic for its offline Whisper rescue lane.
class ElevenLabsSpeechService implements CloudSpeechCapture {
  static const _sampleRate = 16000;
  // Scribe's 38/38 corpus result lets this cloud-only end-of-speech delay be
  // shorter than the conservative offline Whisper setting (700ms). 450ms
  // retains vowel/fricative tails while removing ~250ms of perceived wait.
  static const _silenceEndMs = 450;

  ElevenLabsSpeechService({
    PcmMicrophone? microphone,
    CloudTranscriber? transcriber,
  })  : _microphone = microphone ?? _RecordPcmMicrophone(),
        _transcriber = transcriber ?? _SupabaseCloudTranscriber();

  final PcmMicrophone _microphone;
  final CloudTranscriber _transcriber;
  StreamSubscription<dynamic>? _micSub;
  PcmSegmenter? _segmenter;
  bool _isListening = false;
  int _serial = 0;
  int _pendingRequests = 0;
  Future<void> _requestChain = Future.value();

  bool get isListening => _isListening;

  @override
  Future<bool> startListening({
    required String langCode,
    required List<String> promptHints,
    required void Function(String text, int segmentMs) onFinal,
    void Function()? onSessionEnd,
  }) async {
    if (_isListening) await stopListening();
    if (!await _microphone.hasPermission()) return false;
    final serial = ++_serial;
    try {
      _segmenter = PcmSegmenter(
        sampleRate: _sampleRate,
        silenceEndMs: _silenceEndMs,
        maxUtteranceMs: 3000,
      );
      final stream = await _microphone.startVoiceStream();
      _micSub = stream.listen((chunk) {
        final segments = _segmenter!.feed(chunk);
        for (final segment in segments) {
          _enqueue(
            segment: segment,
            langCode: langCode,
            promptHints: promptHints,
            serial: serial,
            onFinal: onFinal,
            onServiceFailure: onSessionEnd,
          );
        }
      });
      _isListening = true;
      sttLog('[ELS] mic open lang=$langCode');
      return true;
    } catch (error) {
      sttLog('[ELS] mic start failed: $error');
      _isListening = false;
      return false;
    }
  }

  void _enqueue({
    required PcmSegment segment,
    required String langCode,
    required List<String> promptHints,
    required int serial,
    required void Function(String text, int segmentMs) onFinal,
    required void Function()? onServiceFailure,
  }) {
    if (_pendingRequests >= 2) {
      sttLog('[ELS] request queue full — dropping ${segment.durationMs}ms');
      return;
    }
    _pendingRequests++;
    _requestChain = _requestChain.then((_) async {
      _pendingRequests--;
      if (serial != _serial) return;
      final stopwatch = Stopwatch()..start();
      try {
        // Scribe accepts raw PCM16/16kHz. Avoiding a temporary WAV file and
        // its encode/read cycle removes local I/O from every quiz answer.
        final raw = await _transcriber.transcribe(
          pcm16: segment.bytes,
          langCode: langCode,
          expectedWord: promptHints.isEmpty ? '' : promptHints.first,
        );
        final transcript =
            raw == null ? null : WhisperSpeechService.cleanTranscript(raw);
        sttLog('[ELS] ${segment.durationMs}ms captured, '
            '${stopwatch.elapsedMilliseconds}ms cloud: '
            '"${transcript ?? '<empty>'}"');
        if (serial != _serial) return;
        if (transcript == null) {
          onServiceFailure?.call();
          return;
        }
        onFinal(transcript, segment.durationMs);
      } catch (error) {
        sttLog('[ELS] cloud transcription failed: $error');
        if (serial == _serial) onServiceFailure?.call();
      }
    });
  }

  @override
  Future<void> stopListening() async {
    if (!_isListening) return;
    _isListening = false;
    _serial++;
    try {
      await _micSub?.cancel();
      _micSub = null;
      await _microphone.stop();
    } catch (error) {
      sttLog('[ELS] mic stop failed: $error');
    }
  }

  @override
  void dispose() {
    unawaited(stopListening());
    _microphone.dispose();
  }
}
