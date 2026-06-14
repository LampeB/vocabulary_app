abstract interface class AudioService {
  Future<void> speak(String text, String langCode, {String? voiceId});
  Future<void> stop();
  Future<bool> isAvailable();
  void dispose();
}
