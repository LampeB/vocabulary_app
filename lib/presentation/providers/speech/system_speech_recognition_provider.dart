import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/speech/speech_recognition_service.dart';

/// Retains the system recognizer and its native release across quiz routes.
final systemSpeechRecognitionProvider = Provider<SpeechRecognitionService>((
  ref,
) {
  final service = SpeechRecognitionService();
  ref.onDispose(service.dispose);
  return service;
});
