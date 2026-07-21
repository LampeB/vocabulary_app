import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/audio/audio_player_service.dart';
import '../../../services/quiz_orchestration/audio_director.dart';
import '../../../core/config/app_config.dart';
import '../settings/audio_settings_provider.dart';

final audioPlayerServiceProvider = Provider.autoDispose<AudioPlayerService>((ref) {
  final settings = ref.watch(audioSettingsProvider);
  final service = AudioPlayerService(
    usePremium: AppConfig.enableElevenLabsTTS,
    speechRate: settings.speechRate,
    pitch: settings.pitch,
  );
  ref.onDispose(service.dispose);
  return service;
});

/// The quiz's audio-timing authority (voice-orchestration refactor, step 1).
/// Wraps the shared [AudioPlayerService], so director waits and direct
/// speak() calls observe the same channel.
final audioDirectorProvider = Provider.autoDispose<AudioDirector>((ref) {
  return AudioDirector(ref.watch(audioPlayerServiceProvider));
});
