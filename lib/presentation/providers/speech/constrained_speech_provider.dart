import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/speech/constrained_speech_service.dart';

/// App-lifetime holder for the constrained (Vosk) recognition engine.
/// Deliberately NOT autoDispose: loaded models are tens of MB and take
/// seconds to initialise — they must survive quiz screen re-entries.
final constrainedSpeechProvider = Provider<ConstrainedSpeechService>((ref) {
  final service = ConstrainedSpeechService();
  ref.onDispose(service.dispose);
  return service;
});
