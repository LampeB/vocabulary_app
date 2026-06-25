import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _keySpeechRate = 'audio_speech_rate';
const _keyPitch      = 'audio_pitch';

class AudioSettings {
  const AudioSettings({this.speechRate = 0.85, this.pitch = 1.0});
  final double speechRate;
  final double pitch;
  AudioSettings copyWith({double? speechRate, double? pitch}) => AudioSettings(
        speechRate: speechRate ?? this.speechRate,
        pitch: pitch ?? this.pitch,
      );
}

final audioSettingsProvider =
    NotifierProvider<AudioSettingsNotifier, AudioSettings>(
  AudioSettingsNotifier.new,
);

class AudioSettingsNotifier extends Notifier<AudioSettings> {
  @override
  AudioSettings build() {
    _load();
    return const AudioSettings();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = AudioSettings(
      speechRate: prefs.getDouble(_keySpeechRate) ?? 0.85,
      pitch: prefs.getDouble(_keyPitch) ?? 1.0,
    );
  }

  Future<void> setSpeechRate(double rate) async {
    state = state.copyWith(speechRate: rate);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keySpeechRate, rate);
  }

  Future<void> setPitch(double pitch) async {
    state = state.copyWith(pitch: pitch);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyPitch, pitch);
  }
}
