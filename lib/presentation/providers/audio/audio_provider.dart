import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/audio/audio_player_service.dart';
import '../../../core/config/app_config.dart';

final audioPlayerServiceProvider = Provider.autoDispose<AudioPlayerService>((ref) {
  final service = AudioPlayerService(usePremium: AppConfig.enableElevenLabsTTS);
  ref.onDispose(service.dispose);
  return service;
});
