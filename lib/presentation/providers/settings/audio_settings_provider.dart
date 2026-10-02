import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/answer_validator.dart';

const _keySpeechRate = 'audio_speech_rate';
const _keyPitch = 'audio_pitch';
const _keyVoiceStrictness = 'voice_strictness';
const _keyListenSeconds = 'audio_listen_seconds';

class AudioSettings {
  const AudioSettings({
    this.speechRate = 0.85,
    this.pitch = 1.0,
    this.voiceStrictness = AppConstants.fuzzyThresholdDriving,
    this.listenSeconds = defaultListenSeconds,
  });

  static const defaultListenSeconds = 7;
  static const minListenSeconds = 3;
  static const maxListenSeconds = 15;
  final double speechRate;
  final double pitch;

  /// Spoken-answer acceptance threshold (user-tunable): how close the
  /// transcription must be to count as correct.
  final double voiceStrictness;

  /// How long a voice-quiz attempt listens for the learner to START
  /// answering (user-tunable slider, 2026-10-02). An answer already being
  /// spoken at the deadline is never cut off.
  final int listenSeconds;

  static int clampListen(int seconds) =>
      seconds.clamp(minListenSeconds, maxListenSeconds);

  AudioSettings copyWith({
    double? speechRate,
    double? pitch,
    double? voiceStrictness,
    int? listenSeconds,
  }) =>
      AudioSettings(
        speechRate: speechRate ?? this.speechRate,
        pitch: pitch ?? this.pitch,
        voiceStrictness: voiceStrictness ?? this.voiceStrictness,
        listenSeconds: listenSeconds ?? this.listenSeconds,
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
      voiceStrictness: prefs.getDouble(_keyVoiceStrictness) ??
          AppConstants.fuzzyThresholdDriving,
      listenSeconds: AudioSettings.clampListen(
          prefs.getInt(_keyListenSeconds) ??
              AudioSettings.defaultListenSeconds),
    );
    // The validator is static (used across layers) — push the loaded value.
    AnswerValidator.drivingThreshold = state.voiceStrictness;
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

  Future<void> setVoiceStrictness(double threshold) async {
    state = state.copyWith(voiceStrictness: threshold);
    AnswerValidator.drivingThreshold = threshold;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyVoiceStrictness, threshold);
  }

  Future<void> setListenSeconds(int seconds) async {
    final value = AudioSettings.clampListen(seconds);
    state = state.copyWith(listenSeconds: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyListenSeconds, value);
  }
}
