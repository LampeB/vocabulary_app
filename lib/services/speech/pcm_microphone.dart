import 'dart:typed_data';

import 'package:record/record.dart';

/// Raw 16kHz mono PCM capture used by the speech recognition pipelines.
///
/// The native recorder is intentionally behind this port: segmentation,
/// backpressure and lifecycle rules are unit-tested without a device.
abstract interface class PcmMicrophone {
  Future<bool> hasPermission();
  Future<Stream<Uint8List>> startVoiceStream();
  Future<void> stop();
  void dispose();
}

/// The platform recorder every PCM pipeline shares: 16kHz mono PCM16 with the
/// voice-recognition source, echo cancellation and noise suppression.
// Platform binding — its configuration is validated on a device.
// coverage:ignore-start
class RecordPcmMicrophone implements PcmMicrophone {
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
// coverage:ignore-end
