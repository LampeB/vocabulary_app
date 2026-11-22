import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/speech/elevenlabs_speech_service.dart';

/// App-lifetime cloud STT capture service. It has no provider key: the phone
/// calls the authenticated Supabase proxy and the provider secret stays there.
final elevenLabsSpeechProvider = Provider<ElevenLabsSpeechService>((ref) {
  final service = ElevenLabsSpeechService();
  ref.onDispose(service.dispose);
  return service;
});
