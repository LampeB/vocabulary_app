import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/speech/whisper_speech_service.dart';

/// App-lifetime holder for the Whisper recognition engine — the loaded
/// model is ~142MB and takes seconds to initialise; it must survive quiz
/// screen re-entries.
final whisperSpeechProvider = Provider<WhisperSpeechService>((ref) {
  final service = WhisperSpeechService();
  ref.onDispose(service.dispose);
  return service;
});
