import 'package:audioplayers/audioplayers.dart';

/// Service for playing short UI feedback sounds (correct/incorrect).
/// Uses its own AudioPlayer instance so it never conflicts with
/// the main word-audio player.
class SoundEffectsService {
  AudioPlayer? _player;
  bool _isDisposed = false;

  Future<void> _ensureInitialized() async {
    if (_player == null || _isDisposed) {
      _player = AudioPlayer();
      _isDisposed = false;
    }
  }

  Future<void> playCorrect() async {
    await _ensureInitialized();
    try {
      await _player!.stop();
      await _player!.play(AssetSource('sounds/correct.wav'));
    } catch (_) {}
  }

  Future<void> playIncorrect() async {
    await _ensureInitialized();
    try {
      await _player!.stop();
      await _player!.play(AssetSource('sounds/incorrect.wav'));
    } catch (_) {}
  }

  void dispose() {
    _player?.dispose();
    _player = null;
    _isDisposed = true;
  }
}
