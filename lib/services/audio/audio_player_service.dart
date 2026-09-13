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
        _speechRate = speechRate,
        _usePremium = usePremium {
    if (usePremium) _elevenlabs.scheduleIdleCacheCleanup();
  }

  final ElevenLabsService _elevenlabs;
  final FlutterTtsService _tts;
  final double _speechRate;
  final bool _usePremium;
  final _player = AudioPlayer();

  // A visible silent gap is worse than a temporary device-TTS voice. Storage
  // downloads keep filling the cache after this budget expires, so following
  // repetitions still use the rendered recording.
  static const _premiumStartBudget = Duration(milliseconds: 500);

  Future<void> speak(String text, String langCode, {String? audioPath}) async {
    if (!_usePremium || audioPath == null) {
      await _tts.speak(text, langCode);
      return;
    }
    final path = await _elevenlabs
        .downloadAndCache(audioPath)
        .timeout(_premiumStartBudget, onTimeout: () => null);
    if (path != null) {
      // The speech-speed setting used to apply only to device TTS. Most
      // production playback comes from ElevenLabs, so it was always played
      // at 1.0× even when the learner chose a slower pedagogical pace.
      await _player.setPlaybackRate(_premiumRateFor(langCode));
      await _player.play(DeviceFileSource(path));
    } else {
      await _tts.speak(text, langCode);
    }
  }

  /// Pre-loads [langCode]'s TTS voice so the next speak() starts instantly.
  /// No audio is produced. (Premium/ElevenLabs plays cached files, so the
  /// device TTS warm-up is the only one that matters.)
  Future<void> warmUp(String langCode) => _tts.warmUp(langCode);

  /// Downloads [audioPath] without playing it. This is intentionally a
  /// Storage-only operation: no quiz can create a paid TTS render.
  Future<void> prefetch(String text, String langCode, {String? audioPath}) async {
    if (!_usePremium || audioPath == null) return;
    await _elevenlabs.downloadAndCache(audioPath);
  }

  Future<void> stop() async {
    await _player.stop();
    await _tts.stop();
  }

  /// Korean synthesized voices keep a much denser natural cadence than French
  /// or English. Slow them a little further for word-by-word learning while
  /// preserving the learner's chosen global speed for every language.
  double _premiumRateFor(String langCode) =>
      _speechRate * (langCode == 'ko' ? 0.82 : 1.0);

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
