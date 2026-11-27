import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/audio/audio_player_service.dart';
import '../../../services/quiz_orchestration/audio_director.dart';
import '../../../core/config/app_config.dart';
import '../settings/audio_settings_provider.dart';

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
  );
  ref.onDispose(service.dispose);
  return service;
});

/// The quiz's audio-timing authority (voice-orchestration refactor, step 1).
/// Wraps the shared [AudioPlayerService], so director waits and direct
/// speak() calls observe the same channel.
final audioDirectorProvider = Provider.autoDispose<AudioDirector>((ref) {
  final director = AudioDirector(ref.watch(audioPlayerServiceProvider));
  ref.onDispose(director.dispose); // frees the director-owned SFX player
  return director;
});
