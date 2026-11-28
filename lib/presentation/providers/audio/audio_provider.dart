import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/audio/audio_player_service.dart';
import '../../../services/audio/elevenlabs_service.dart';
import '../../../services/quiz_orchestration/audio_director.dart';
import '../../../core/config/app_config.dart';
import '../settings/audio_settings_provider.dart';
import '../speech/shared_pcm_capture_provider.dart';
import '../speech/system_speech_recognition_provider.dart';

// Prefetch and playback can overlap when settings replace a player.
final _audioAssetCacheProvider = Provider((ref) => ElevenLabsService());

final audioPlayerServiceProvider = Provider.autoDispose<AudioPlayerService>((
  ref,
) {
  final (speechRate, pitch) = ref.watch(
    audioSettingsProvider.select(
      (settings) => (settings.speechRate, settings.pitch),
    ),
  );
  final service = AudioPlayerService(
    usePremium: AppConfig.enableElevenLabsTTS,
    speechRate: speechRate,
    pitch: pitch,
    assetCache: ref.watch(_audioAssetCacheProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

/// The quiz's audio-timing authority (voice-orchestration refactor, step 1).
/// Wraps the shared [AudioPlayerService], so director waits and direct
/// speak() calls observe the same channel.
final audioDirectorProvider = Provider.autoDispose<AudioDirector>((ref) {
  final retired = ref.watch(_retiredAudioDirectorsProvider);
  final director = AudioDirector(
    ref.watch(audioPlayerServiceProvider),
    waitForReplacedAudio: retired.wait,
    waitForMicrophoneRelease: () {
      // A quiz that only plays audio does not need to create a recorder.
      final releases = [
        if (ref.exists(sharedPcmCaptureProvider))
          ?ref.read(sharedPcmCaptureProvider).waitForMicrophoneRelease(),
        if (ref.exists(systemSpeechRecognitionProvider))
          ?ref.read(systemSpeechRecognitionProvider).waitForMicrophoneRelease(),
      ];
      return releases.isEmpty
          ? null
          : Future.wait<void>(releases, eagerError: true);
    },
  );
  ref.onDispose(() => retired.retire(director));
  return director;
});

// Scope the barrier to the audio channel, which survives route and settings
// changes. A replacement can itself be replaced while an earlier stop waits.
final _retiredAudioDirectorsProvider = Provider(
  (ref) => _RetiredAudioDirectors(),
);

class _RetiredAudioDirectors {
  final _pending = <AudioDirector>{};

  void retire(AudioDirector director) {
    _pending.add(director);
    director.dispose();
    // Let the speech player's own provider begin disposal before joining it.
    unawaited(
      Future<void>.microtask(
        () => _release(director, retry: false),
      ).catchError((Object _) {}),
    );
  }

  Future<void>? wait({required bool retry}) {
    if (_pending.isEmpty) return null;
    return Future.wait<void>(
      _pending.toList().map((director) => _release(director, retry: retry)),
      eagerError: true,
    );
  }

  Future<void> _release(AudioDirector director, {required bool retry}) async {
    await director.waitForPlayerRelease(retry: retry);
    _pending.remove(director);
  }
}
