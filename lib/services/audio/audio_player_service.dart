import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import '../../core/utils/stt_debug_log.dart';
import 'elevenlabs_service.dart';
import 'flutter_tts_service.dart';
import 'audio_ports.dart';
import 'native_playback_player.dart';

class _FilePlayerRetirementFailed implements Exception {
  const _FilePlayerRetirementFailed(this.cause);

  final Object cause;

  @override
  String toString() => 'Could not release the previous file player: $cause';
}

// coverage:ignore-start
// Thin third-party adapter; behavior is exercised through [FileAudioPlayer]
// fakes in AudioPlayerService tests. Native plugin calls need device coverage.
class _AudioplayersFilePlayer implements FileAudioPlayer {
  NativePlaybackPlayer? _player;
  Future<void>? _retiring;
  bool _needsReplacement = false;
  bool _waitingForCompletion = false;
  int _generation = 0;
  double _rate = 1;

  @override
  Future<void> setPlaybackRate(double rate) async => _rate = rate;

  @override
  Future<void> playFile(String path, {bool waitForCompletion = false}) async {
    if (_waitingForCompletion && !waitForCompletion) return;
    final generation = ++_generation;
    _waitingForCompletion = waitForCompletion;
    bool stillCurrent() {
      if (generation == _generation) return true;
      if (waitForCompletion) throw const AudioPlaybackCancelled();
      return false;
    }

    try {
      if (waitForCompletion || _needsReplacement) {
        try {
          await _replacePlayer();
        } catch (error) {
          throw _FilePlayerRetirementFailed(error);
        }
      }
      if (!stillCurrent()) return;
      final player = _player ??= NativePlaybackPlayer();
      await player.setPlaybackRate(_rate);
      if (!stillCurrent()) return;
      final source = DeviceFileSource(path);
      if (waitForCompletion) {
        await player.playToEnd(source);
      } else {
        await player.play(source);
      }
    } finally {
      if (generation == _generation) _waitingForCompletion = false;
    }
  }

  @override
  Future<void> stop() async {
    _generation++;
    _waitingForCompletion = false;
    if (_needsReplacement) {
      await _replacePlayer();
    } else {
      await _player?.stop();
    }
  }

  @override
  Future<PlayerState> get state async => _player?.state ?? PlayerState.stopped;

  @override
  bool get isPlaying => _player?.state == PlayerState.playing;

  @override
  Future<void> release() async {
    _generation++;
    _waitingForCompletion = false;
    await _replacePlayer();
  }

  @override
  Future<void> dispose() async => _player?.dispose();

  Future<void> _replacePlayer() async {
    final player = _player;
    if (player == null) return;
    await (_retiring ??= _releasePlayer(
      player,
    ).whenComplete(() => _retiring = null));
  }

  Future<void> _releasePlayer(NativePlaybackPlayer player) async {
    _needsReplacement = true;
    await player.releaseForDisposal();
    _player = null;
    _needsReplacement = false;
    unawaited(player.dispose().catchError(_logFileCleanupError));
  }
}
// coverage:ignore-end

void _logFileCleanupError(Object error) {
  sttLog('[TTS] released file player cleanup failed: $error');
}

class AudioPlayerService {
  AudioPlayerService({
    required bool usePremium,
    Map<String, String>? voiceIds,
    double speechRate = 0.85,
    double pitch = 1.0,
    AudioAssetCache? assetCache,
    DeviceSpeech? tts,
    FileAudioPlayer? filePlayer,
  }) : _assetCache = assetCache ?? ElevenLabsService(voiceIds: voiceIds),
       _tts = tts ?? FlutterTtsService(speechRate: speechRate, pitch: pitch),
       _player = filePlayer ?? _AudioplayersFilePlayer(),
       _speechRate = speechRate,
       _usePremium = usePremium {
    if (usePremium) _assetCache.scheduleIdleCacheCleanup();
  }

  final AudioAssetCache _assetCache;
  final DeviceSpeech _tts;
  final double _speechRate;
  final bool _usePremium;
  final FileAudioPlayer _player;
  int _playbackEpoch = 0;
  Completer<void> _interrupted = Completer<void>();
  int _requiredPromptGeneration = 0;
  bool _requiredPromptInProgress = false;
  int _filePlaybackGeneration = 0;
  bool _fileNeedsRelease = false;
  String? _failedAudioPath;
  Future<void>? _recoveringFile;
  Future<void>? _disposal;
  Future<void>? _fileRelease;
  Future<void>? _speechDisposal;
  bool _disposalRefused = false;

  // A visible silent gap is worse than a temporary device-TTS voice. Storage
  // downloads keep filling the cache after this budget expires, so following
  // repetitions still use the rendered recording.
  static const _premiumStartBudget = Duration(milliseconds: 500);

  Future<void> speak(
    String text,
    String langCode, {
    String? audioPath,
    bool requirePlayback = false,
  }) async {
    if (_disposal != null) {
      if (requirePlayback) throw const AudioPlaybackCancelled();
      return;
    }
    if (!requirePlayback && _requiredPromptInProgress) return;
    if (requirePlayback) {
      _requiredPromptGeneration++;
      _requiredPromptInProgress = true;
    }
    final epoch = _playbackEpoch;
    final promptGeneration = _requiredPromptGeneration;
    bool isCurrent() =>
        epoch == _playbackEpoch &&
        promptGeneration == _requiredPromptGeneration;
    final interrupted = _interrupted.future;
    final playing = _play(
      text,
      langCode,
      audioPath,
      requirePlayback,
      isCurrent,
    );
    if (!requirePlayback) return playing;
    try {
      await Future.any<void>([
        playing,
        interrupted.then<void>((_) => throw const AudioPlaybackCancelled()),
      ]);
      if (!isCurrent()) throw const AudioPlaybackCancelled();
    } finally {
      if (isCurrent()) _requiredPromptInProgress = false;
    }
  }

  Future<void> _play(
    String text,
    String langCode,
    String? audioPath,
    bool requirePlayback,
    bool Function() isCurrent,
  ) async {
    if (_fileNeedsRelease) {
      await _recoverFilePlayer();
      if (!isCurrent()) return;
    }
    if (!_usePremium || audioPath == null) {
      await _speakOnDevice(text, langCode, requirePlayback);
      return;
    }
    final path = await _assetCache
        .downloadAndCache(audioPath)
        .timeout(_premiumStartBudget, onTimeout: () => null);
    if (!isCurrent()) return;
    if (path != null) {
      // The speech-speed setting used to apply only to device TTS. Most
      // production playback comes from ElevenLabs, so it was always played
      // at 1.0× even when the learner chose a slower pedagogical pace.
      await _player.setPlaybackRate(_premiumRateFor(langCode));
      if (!isCurrent()) return;
      if (_fileNeedsRelease) await _recoverFilePlayer();
      if (!isCurrent()) return;
      final generation = ++_filePlaybackGeneration;
      try {
        await _player.playFile(path, waitForCompletion: requirePlayback);
        return;
      } on AudioPlaybackCancelled {
        if (requirePlayback) rethrow;
        return;
      } catch (error) {
        if (!isCurrent() || generation != _filePlaybackGeneration) return;
        _fileNeedsRelease = true;
        // Failure to free a previous player did not test this clip.
        if (error is _FilePlayerRetirementFailed) rethrow;
        sttLog('[TTS] cached playback failed: $error');
        _failedAudioPath = audioPath;
      }
    }
    if (_fileNeedsRelease) await _recoverFilePlayer();
    if (!isCurrent()) return;
    await _speakOnDevice(text, langCode, requirePlayback);
  }

  Future<void> _recoverFilePlayer() =>
      _recoveringFile ??= Future<void>.sync(_player.release)
          .then((_) async {
            final path = _failedAudioPath;
            if (path != null) {
              try {
                await _assetCache.invalidate(path);
              } catch (error) {
                sttLog('[TTS] cache eviction failed: $error');
              }
            }
            _failedAudioPath = null;
            _fileNeedsRelease = false;
          })
          .whenComplete(() => _recoveringFile = null);

  Future<void> _speakOnDevice(
    String text,
    String langCode,
    bool requirePlayback,
  ) async {
    try {
      await _tts.speak(text, langCode);
    } on AudioPlaybackCancelled {
      if (requirePlayback) rethrow;
    } on TtsRejected catch (error) {
      if (requirePlayback) rethrow;
      sttLog('[TTS] optional playback failed: $error');
    }
  }

  /// Pre-loads [langCode]'s TTS voice so the next speak() starts instantly.
  /// No audio is produced. (Premium/ElevenLabs plays cached files, so the
  /// device TTS warm-up is the only one that matters.)
  Future<void> warmUp(String langCode) => _tts.warmUp(langCode);

  /// Downloads [audioPath] without playing it. This is intentionally a
  /// Storage-only operation: no quiz can create a paid TTS render.
  Future<void> prefetch(
    String text,
    String langCode, {
    String? audioPath,
  }) async {
    if (!_usePremium || audioPath == null) return;
    await _assetCache.downloadAndCache(audioPath);
  }

  Future<void> stop() async {
    final disposal = _disposal;
    if (disposal != null) return disposal;
    _invalidatePlayback();
    await Future.wait([
      _fileNeedsRelease ? _recoverFilePlayer() : _player.stop(),
      _tts.stop(),
    ]);
  }

  /// A learner retry reissues only native release calls that were refused.
  /// Pending and confirmed releases keep their original futures.
  Future<void> retryDisposal() => _disposalRefused ? _releasePlayers() : stop();

  Future<void> _releasePlayers() {
    _disposalRefused = false;
    return _disposal =
        Future.wait<void>([
          _fileRelease ??= _releaseFilePlayer().onError((
            Object error,
            StackTrace stack,
          ) {
            _fileRelease = null;
            Error.throwWithStackTrace(error, stack);
          }),
          _speechDisposal ??= Future<void>.sync(_tts.dispose).onError((
            Object error,
            StackTrace stack,
          ) {
            _speechDisposal = null;
            Error.throwWithStackTrace(error, stack);
          }),
        ], eagerError: true).then<void>(
          (_) {},
          onError: (Object error, StackTrace stack) {
            _disposalRefused = true;
            Error.throwWithStackTrace(error, stack);
          },
        );
  }

  Future<void> _releaseFilePlayer() async {
    if (_fileNeedsRelease) {
      await _recoverFilePlayer();
    } else {
      await _player.release();
    }
    unawaited(
      Future<void>.sync(_player.dispose).catchError(_logFileCleanupError),
    );
  }

  void _invalidatePlayback() {
    _playbackEpoch++;
    _requiredPromptInProgress = false;
    _interrupted.complete();
    _interrupted = Completer<void>();
  }

  /// Korean synthesized voices keep a much denser natural cadence than French
  /// or English. Slow them a little further for word-by-word learning while
  /// preserving the learner's chosen global speed for every language.
  double _premiumRateFor(String langCode) =>
      _speechRate * (langCode == 'ko' ? 0.82 : 1.0);

  Future<PlayerState> get state async => _player.state;

  /// Whether speech (TTS or premium audio) is still playing. Hands-free polls
  /// this before opening the mic so questions/corrections are never cut off
  /// or picked up by the recognizer as the user's answer.
  bool get isSpeaking => _tts.isSpeaking || _player.isPlaying;

  void dispose() {
    if (_disposal != null) return;
    _invalidatePlayback();
    unawaited(
      _releasePlayers().catchError((Object error) {
        sttLog('[TTS] disposal could not release playback: $error');
      }),
    );
  }
}
