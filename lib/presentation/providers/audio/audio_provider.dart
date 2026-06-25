import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/audio/audio_player_service.dart';
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
