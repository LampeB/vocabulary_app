import 'package:audioplayers/audioplayers.dart' show PlayerState;

/// The immutable-asset cache used by premium playback.
///
/// Keeping this port separate from the Storage implementation lets the quiz
/// playback policy be tested without network or disk plugins.
abstract interface class AudioAssetCache {
  Future<String?> downloadAndCache(String audioPath);
  void scheduleIdleCacheCleanup();
}

/// Device text-to-speech surface used when a rendered clip is unavailable.
abstract interface class DeviceSpeech {
  Future<void> speak(String text, String langCode);
  Future<void> warmUp(String langCode);
  Future<void> stop();
  bool get isSpeaking;
  void dispose();
}

/// Local file player surface for pre-rendered audio assets.
abstract interface class FileAudioPlayer {
  Future<void> setPlaybackRate(double rate);
  Future<void> playFile(String path);
  Future<void> stop();
  Future<PlayerState> get state;
  bool get isPlaying;
  void dispose();
}
