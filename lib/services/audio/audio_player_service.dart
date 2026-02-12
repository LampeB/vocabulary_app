import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import '../../config/app_config.dart';
import '../../config/api_config.dart';
import 'flutter_tts_service.dart';

/// Service de lecture audio (local et HTTP)
/// Supporte aussi le TTS natif Flutter quand useFreeTTS est actif
class AudioPlayerService {
  AudioPlayer? _player;
  bool _isDisposed = false;
  FlutterTtsService? _ttsService;

  Future<void> initialize() async {
    if (_player != null && !_isDisposed) return;

    _player = AudioPlayer();
    _isDisposed = false;
  }

  Future<void> _ensureInitialized() async {
    if (_player == null || _isDisposed) {
      await initialize();
    }
  }

  Future<bool> playAudioByHash(String hash) async {
    try {
      await _ensureInitialized();

      final audioService = AppConfig.createAudioService();
      final audioUrl = await audioService.getAudioUrl(hash);

      if (audioUrl == null) return false;

      return await _playFromUrl(audioUrl);
    } catch (e) {
      return false;
    }
  }

  Future<bool> _playFromUrl(String url) async {
    try {
      await _ensureInitialized();
      if (_player == null) return false;

      await _player!.stop();

      if (url.startsWith('http://') || url.startsWith('https://')) {
        await _player!.play(UrlSource(url));
      } else {
        await _player!.play(DeviceFileSource(url));
      }

      return true;
    } catch (e) {
      _isDisposed = true;
      return false;
    }
  }

  Future<void> stop() async {
    try {
      if (_player != null && !_isDisposed) {
        await _player!.stop();
      }
    } catch (_) {}
  }

  Future<void> pause() async {
    try {
      if (_player != null && !_isDisposed) {
        await _player!.pause();
      }
    } catch (_) {}
  }

  Future<void> resume() async {
    try {
      await _ensureInitialized();
      if (_player != null) {
        await _player!.resume();
      }
    } catch (_) {}
  }

  Future<bool> speakText(String text, String langCode) async {
    try {
      _ttsService ??= FlutterTtsService();
      await _ttsService!.initialize();
      return await _ttsService!.speak(text, langCode);
    } catch (e) {
      return false;
    }
  }

  Future<bool> playAudioSmart({
    String? audioHash,
    required String text,
    required String langCode,
  }) async {
    if (audioHash != null && !ApiConfig.useFreeTTS) {
      return await playAudioByHash(audioHash);
    }
    return await speakText(text, langCode);
  }

  /// Play audio smartly and wait for playback to complete before returning.
  /// Used by hands-free mode to sequence: play audio → then start listening.
  Future<void> playAudioSmartAndWait({
    String? audioHash,
    required String text,
    required String langCode,
  }) async {
    if (audioHash != null && !ApiConfig.useFreeTTS) {
      await _ensureInitialized();
      final completer = Completer<void>();
      late StreamSubscription sub;
      sub = _player!.onPlayerComplete.listen((_) {
        if (!completer.isCompleted) completer.complete();
        sub.cancel();
      });

      final success = await playAudioByHash(audioHash);
      if (!success) {
        sub.cancel();
        if (!completer.isCompleted) completer.complete();
        return;
      }

      await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () { sub.cancel(); },
      );
    } else {
      _ttsService ??= FlutterTtsService();
      await _ttsService!.initialize();
      await _ttsService!.speakAndWait(text, langCode);
    }
  }

  Future<void> stopTts() async {
    if (_ttsService != null) {
      await _ttsService!.stop();
    }
  }

  void dispose() {
    if (_player != null && !_isDisposed) {
      _player!.dispose();
      _player = null;
      _isDisposed = true;
    }
    _ttsService?.dispose();
    _ttsService = null;
  }
}
