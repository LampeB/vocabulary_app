import 'package:audioplayers/audioplayers.dart';

class SoundEffectsService {
  final _player = AudioPlayer();

  Future<void> playCorrect() async {
    try {
      await _player.play(AssetSource('sounds/correct.wav'));
    } catch (_) {}
  }

  Future<void> playIncorrect() async {
    try {
      await _player.play(AssetSource('sounds/incorrect.wav'));
    } catch (_) {}
  }

  void dispose() => _player.dispose();
}
