import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/speech/shared_pcm_capture.dart';

/// App-lifetime microphone shared by the parallel STT engines (ElevenLabs
/// Scribe + on-device Whisper hear the SAME utterance).
final sharedPcmCaptureProvider = Provider<SharedPcmCapture>((ref) {
  final capture = SharedPcmCapture();
  ref.onDispose(capture.dispose);
  return capture;
});
