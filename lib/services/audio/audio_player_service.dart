import 'package:audioplayers/audioplayers.dart';
import 'elevenlabs_service.dart';
import 'flutter_tts_service.dart';

class AudioPlayerService {
  AudioPlayerService({
    required bool usePremium,
    Map<String, String>? voiceIds,
    double speechRate = 0.85,
    double pitch = 1.0,
  })  : _elevenlabs = ElevenLabsService(voiceIds: voiceIds),
        _tts = FlutterTtsService(speechRate: speechRate, pitch: pitch),
        _usePremium = usePremium;

  final ElevenLabsService _elevenlabs;
  final FlutterTtsService _tts;
  final bool _usePremium;
  final _player = AudioPlayer();

  Future<void> speak(String text, String langCode) async {
    if (!_usePremium) {
      await _tts.speak(text, langCode);
      return;
    }
    final path = await _elevenlabs.generateAndCache(
        text, langCode, _elevenlabs.voiceIdFor(langCode));
    if (path != null) {
      await _player.play(DeviceFileSource(path));
    } else {
      await _tts.speak(text, langCode);
    }
  }

  Future<void> stop() async {
    await _player.stop();
    await _tts.stop();
  }

  Future<PlayerState> get state async => _player.state;

  /// Whether speech (TTS or premium audio) is still playing. Hands-free polls
  /// this before opening the mic so questions/corrections are never cut off
  /// or picked up by the recognizer as the user's answer.
  bool get isSpeaking =>
      _tts.isSpeaking || _player.state == PlayerState.playing;

  void dispose() {
    _player.dispose();
    _tts.dispose();
  }
}
