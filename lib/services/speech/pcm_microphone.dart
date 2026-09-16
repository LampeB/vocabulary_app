import 'dart:typed_data';

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
