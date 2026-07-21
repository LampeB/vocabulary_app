import '../audio/audio_player_service.dart';

/// Step 1 of the voice-orchestration refactor
/// (docs/refactor-voice-orchestration.md): the single owner of "when is the
/// audio channel free" during a quiz. The three hand-rolled `isSpeaking`
/// polling loops (screen chain-wait, provider speak-when-quiet, provider
/// advance-after-audio) collapse into this class, so their timing rules live
/// — and are tested — in exactly one place.
///
/// Later steps move earcons/SFX and the mic hand-off here too, then the
/// VoiceTurnMachine consumes this as its audio command surface.
class AudioDirector {
  AudioDirector(this._audio, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final AudioPlayerService _audio;
  final DateTime Function() _clock;

  /// Poll cadence for the quiet checks — 100ms mirrors the historical loops.
  static const _poll = Duration(milliseconds: 100);

  bool get isSpeaking => _audio.isSpeaking;

  Future<void> speak(String text, String langCode) =>
      _audio.speak(text, langCode);

  Future<void> prefetch(String text, String langCode) =>
      _audio.prefetch(text, langCode);

  Future<void> warmUp(String langCode) => _audio.warmUp(langCode);

  Future<void> stop() => _audio.stop();

  /// Resolves once nothing is playing, or after [timeout] — a stuck
  /// `isSpeaking` must never wedge the quiz (utterances have finite length;
  /// the cap only trips on platform bugs).
  Future<void> quiet({Duration timeout = const Duration(seconds: 5)}) async {
    final deadline = _clock().add(timeout);
    while (_audio.isSpeaking && _clock().isBefore(deadline)) {
      await Future.delayed(_poll);
    }
  }

  /// Speaks [text] after the current audio finishes (bounded by [timeout]) —
  /// the provider's historical `_speakWhenQuiet`.
  Future<void> speakWhenQuiet(String text, String langCode,
      {Duration timeout = const Duration(seconds: 5)}) async {
    await quiet(timeout: timeout);
    await _audio.speak(text, langCode);
  }

  /// Waits out a speech CHAIN — utterances queuing behind each other (a
  /// correction replay with the question queued next). A single start→end
  /// wait latched onto the first utterance and the mic path then cut off the
  /// queued question (field log 2026-07-10: 'fruit' truncated mid-word).
  ///
  /// Up to [cycles] rounds of [wait-for-start → wait-for-end]; a round where
  /// nothing new starts ends the chain. The first round waits
  /// [firstStartWindow] for speech to spin up; follow-ups only
  /// [nextStartWindow] (a full-length recheck added dead air to every card —
  /// field log 2026-07-10 01:20). [keepGoing] lets the caller abort (e.g. on
  /// unmount); checked every poll.
  Future<void> chainQuiet({
    int cycles = 3,
    Duration firstStartWindow = const Duration(milliseconds: 2500),
    Duration nextStartWindow = const Duration(milliseconds: 400),
    Duration utteranceCap = const Duration(seconds: 8),
    bool Function()? keepGoing,
  }) async {
    bool go() => keepGoing?.call() ?? true;
    for (var cycle = 0; cycle < cycles; cycle++) {
      final startDeadline =
          _clock().add(cycle == 0 ? firstStartWindow : nextStartWindow);
      while (go() && !_audio.isSpeaking && _clock().isBefore(startDeadline)) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      if (!_audio.isSpeaking) break; // chain over — nothing new started
      final endDeadline = _clock().add(utteranceCap);
      while (go() && _audio.isSpeaking && _clock().isBefore(endDeadline)) {
        await Future.delayed(_poll);
      }
    }
  }
}
