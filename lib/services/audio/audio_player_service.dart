import 'package:audioplayers/audioplayers.dart';
import 'elevenlabs_service.dart';
import 'flutter_tts_service.dart';

class AudioPlayerService {
  AudioPlayerService({
    required bool usePremium,
    String? frVoiceId,
    String? koVoiceId,
    double speechRate = 0.85,
    double pitch = 1.0,
  })  : _elevenlabs = ElevenLabsService(
          frVoiceId: frVoiceId ?? 'Charlotte',
          koVoiceId: koVoiceId ?? 'Elli',
        ),
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
    final voiceId = langCode == 'ko' ? _elevenlabs.koVoiceId : _elevenlabs.frVoiceId;
    final path = await _elevenlabs.generateAndCache(text, langCode, voiceId);
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

  void dispose() {
    _player.dispose();
    _tts.dispose();
  }
}
