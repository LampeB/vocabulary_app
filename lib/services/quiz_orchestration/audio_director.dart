import 'dart:async' show TimeoutException, unawaited;

import '../audio/audio_player_service.dart';
import '../audio/audio_ports.dart';
import '../audio/sound_effects_service.dart';
import '../../core/utils/stt_debug_log.dart';

enum StudyPromptResult { completed, cancelled, failed }

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
  AudioDirector(
    this._audio, {
    SoundEffectsService? sfx,
    DateTime Function()? clock,
    this._waitForReplacedAudio,
    this._waitForMicrophoneRelease,
  }) : _sfx = sfx ?? SoundEffectsService(),
       _clock = clock ?? DateTime.now;

  final AudioPlayerService _audio;
  final SoundEffectsService _sfx;
  final DateTime Function() _clock;
  final Future<void>? Function({required bool retry})? _waitForReplacedAudio;
  final Future<void>? Function()? _waitForMicrophoneRelease;
  Future<void>? _stopping;
  bool _stopRefused = false;
  bool _disposed = false;
  int _playbackGeneration = 0;
  int _cueGeneration = 0;

  /// Poll cadence for the quiet checks — 100ms mirrors the historical loops.
  static const _poll = Duration(milliseconds: 100);
  static const releaseTimeout = audioReleaseTimeout;
  static const _openingCueTimeout = Duration(seconds: 2);

  bool get isSpeaking => _audio.isSpeaking;

  Future<void> speak(
    String text,
    String langCode, {
    String? audioPath,
    bool requirePlayback = false,
    bool Function()? keepGoing,
  }) => _playWhenReleased(
    (isCurrent) => _audio.speak(
      text,
      langCode,
      audioPath: audioPath,
      requirePlayback: requirePlayback,
      keepGoing: isCurrent,
    ),
    requirePlayback: requirePlayback,
    keepGoing: keepGoing,
  );

  Future<void> prefetch(String text, String langCode, {String? audioPath}) =>
      _audio.prefetch(text, langCode, audioPath: audioPath);

  Future<void> warmUp(String langCode) => _audio.warmUp(langCode);

  Future<void> stop() {
    _playbackGeneration++;
    if (!_stopRefused && _stopping != null) return _stopping!;
    _stopRefused = false;
    return _stopping = Future<void>.sync(_audio.stop).then<void>(
      (_) => _stopping = null,
      onError: (Object error, StackTrace stack) {
        _stopRefused = true;
        Error.throwWithStackTrace(error, stack);
      },
    );
  }

  /// Waits for a retired director's separate native players. Keep the raw
  /// futures so a caller timing out cannot retire an unconfirmed release.
  Future<void> waitForPlayerRelease({bool retry = false}) => Future.wait<void>([
    retry ? _audio.retryDisposal() : _audio.stop(),
    _sfx.waitForRelease(retry: retry),
  ], eagerError: true);

  /// Joins release of both current and retired players. The caller's deadline
  /// never discards the native stop, and a refusal stays visible until an
  /// explicit stop retries it.
  Future<void> waitForAudioRelease({bool retryReplaced = false}) =>
      _releaseBarrier(retryReplaced: retryReplaced) ?? Future.value();

  Future<void>? _releaseBarrier({bool retryReplaced = false}) {
    final stops = [
      ?_stopping,
      ?_sfx.stopRequest,
      ?_waitForReplacedAudio?.call(retry: retryReplaced),
    ];
    if (stops.isEmpty) return null;
    return Future.wait<void>(stops, eagerError: true).timeout(releaseTimeout);
  }

  Future<void> _playWhenReleased(
    Future<void> Function(bool Function()) play, {
    bool requirePlayback = false,
    bool Function()? keepGoing,
  }) async {
    final generation = _playbackGeneration;
    bool isCurrent() =>
        !_disposed &&
        generation == _playbackGeneration &&
        (keepGoing?.call() ?? true);
    try {
      final stopping = _releaseBarrier();
      if (stopping != null) await stopping;
      if (isCurrent()) {
        final releasingMic = _waitForMicrophoneRelease?.call();
        if (releasingMic != null) await releasingMic;
      }
    } catch (error) {
      if (requirePlayback) rethrow;
      sttLog('[AUDIO] playback skipped after release failure: $error');
      return;
    }
    if (!isCurrent()) {
      if (requirePlayback) throw const AudioPlaybackCancelled();
      return;
    }
    await play(isCurrent);
  }

  /// Stops both speech and the separate earcon player. Unlike [stop], this is
  /// for a lifecycle interruption, where no sound may survive in background.
  Future<void> stopAll() => _stopSpeechAndEarcons();

  Future<void> _stopSpeechAndEarcons() async {
    _cueGeneration++;
    await Future.wait([stop(), _sfx.stop()]).timeout(releaseTimeout);
  }

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
  Future<void> speakWhenQuiet(
    String text,
    String langCode, {
    Duration timeout = const Duration(seconds: 5),
    String? audioPath,
    bool Function()? keepGoing,
    bool requirePlayback = false,
  }) async {
    if (!(keepGoing?.call() ?? true)) return;
    await quiet(timeout: timeout);
    if (!(keepGoing?.call() ?? true)) return;
    await speak(
      text,
      langCode,
      audioPath: audioPath,
      requirePlayback: requirePlayback,
      keepGoing: keepGoing,
    );
  }

  /// Plays the localized grammar instruction and then the drill word with
  /// its target-language voice. Resolves when both utterances have finished.
  Future<StudyPromptResult> speakGrammarPrompt({
    required String instruction,
    required String instructionLang,
    required String word,
    required String wordLang,
    required bool Function() keepGoing,
    Future<void>? previousSpeech,
  }) => _speakStudyPrompt(
    previousSpeech: previousSpeech,
    keepGoing: keepGoing,
    lines: [(instruction, instructionLang, null), (word, wordLang, null)],
  );

  /// Resolves after the word is heard, including voice setup or file playback.
  Future<StudyPromptResult> speakVocabularyPrompt({
    required String word,
    required String wordLang,
    required bool Function() keepGoing,
    String? audioPath,
    Future<void>? previousSpeech,
  }) => _speakStudyPrompt(
    previousSpeech: previousSpeech,
    keepGoing: keepGoing,
    lines: [(word, wordLang, audioPath)],
  );

  Future<StudyPromptResult> _speakStudyPrompt({
    required Future<void>? previousSpeech,
    required bool Function() keepGoing,
    required List<(String, String, String?)> lines,
  }) async {
    const deadline = Duration(seconds: 15);
    try {
      await previousSpeech?.timeout(deadline);
      for (final (text, language, audioPath) in lines) {
        if (!keepGoing()) return StudyPromptResult.cancelled;
        await speak(
          text,
          language,
          audioPath: audioPath,
          requirePlayback: true,
          keepGoing: keepGoing,
        ).timeout(deadline);
      }
      return keepGoing()
          ? StudyPromptResult.completed
          : StudyPromptResult.cancelled;
    } on AudioPlaybackCancelled {
      return StudyPromptResult.cancelled;
    } catch (error) {
      sttLog('[TTS] study prompt failed: $error');
      if (keepGoing()) {
        try {
          await stop().timeout(releaseTimeout);
        } catch (error) {
          sttLog('[TTS] study prompt stop failed: $error');
        }
      }
      return StudyPromptResult.failed;
    }
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
      final startDeadline = _clock().add(
        cycle == 0 ? firstStartWindow : nextStartWindow,
      );
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

  // ── Earcons / verdict sounds (step 2: SFX ownership) ───────────────────────

  Future<void> playCorrect() => _playWhenReleased((_) => _sfx.playCorrect());
  Future<void> playIncorrect() =>
      _playWhenReleased((_) => _sfx.playIncorrect());
  Future<void> playListenCue() =>
      _playWhenReleased((_) => _sfx.playListenCue(), requirePlayback: true);
  Future<void> playListenDone() =>
      _playWhenReleased((_) => _sfx.playListenDone());

  /// Releases the audio channel to the microphone.
  ///
  /// This is deliberately a strict hand-off: the speech and earcon players
  /// confirm release of their tracks before the settling beat.
  /// Merely firing `stop()` and waiting a fixed delay let a late audio buffer
  /// (or a slow Samsung focus release) overlap the first STT frames, so some
  /// cards appeared to reject speech before the learner could answer.
  Future<void> handOffToMic({
    Duration focusBeat = const Duration(milliseconds: 450),
  }) async {
    await Future.wait([
      _stopSpeechAndEarcons(),
      waitForAudioRelease(retryReplaced: true),
    ], eagerError: true);
    await Future.delayed(focusBeat);
  }

  /// "Your turn" earcon followed by a clearance beat, so the recognizer never
  /// transcribes the earcon itself as an answer (double-bip field log
  /// 2026-07-07). Resolves when it is safe to open the mic.
  Future<void> listenCue({
    Duration clearance = const Duration(milliseconds: 100),
  }) async {
    final generation = ++_cueGeneration;
    await waitForAudioRelease();
    if (_disposed || generation != _cueGeneration) {
      throw const AudioPlaybackCancelled();
    }
    await _sfx.playListenCue().timeout(
      _openingCueTimeout,
      onTimeout: () {
        if (generation != _cueGeneration) throw const AudioPlaybackCancelled();
        // Invalidate and stop the old signal before the next attempt. A
        // pending or refused native stop remains a barrier to a new signal.
        unawaited(
          Future<void>.sync(_sfx.stop).catchError((Object error) {
            sttLog('[SFX] timed-out cue stop failed: $error');
          }),
        );
        throw TimeoutException(
          'Opening cue did not finish',
          _openingCueTimeout,
        );
      },
    );
    await Future.delayed(clearance);
    if (generation != _cueGeneration) throw const AudioPlaybackCancelled();
  }

  /// Frees the director-owned SFX player. The [AudioPlayerService] belongs to
  /// its own provider and is NOT disposed here.
  void dispose() {
    _disposed = true;
    _playbackGeneration++;
    _cueGeneration++;
    _sfx.dispose();
  }
}
