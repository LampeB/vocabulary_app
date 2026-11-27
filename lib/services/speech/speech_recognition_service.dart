import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../core/utils/stt_debug_log.dart';
import '../../core/languages.dart';
import 'stt_engine.dart';

/// Platform recognizer capabilities consumed by [SystemSttEngine].
abstract interface class SystemSpeechCapture {
  void Function()? get onListeningDone;
  set onListeningDone(void Function()? callback);
  Future<bool> initialize();
  Future<bool> supportsOnDeviceRecognition();
  Future<bool> startListening({
    required String langCode,
    bool onDevice = false,
    required void Function(String primary, List<String> candidates) onResult,
    void Function(String primary, List<String> candidates)? onPartial,
  });
  Future<void> stopListening();
  void dispose();
}

/// A platform-neutral recognition result. It keeps the service testable while
/// preserving every alternate hypothesis for the answer validator.
class SystemRecognitionResult {
  const SystemRecognitionResult({
    required this.words,
    required this.isFinal,
    required this.confidence,
    this.alternates = const [],
  });

  final String words;
  final bool isFinal;
  final double confidence;
  final List<({String words, double confidence})> alternates;
}

/// Port for the Android/iOS recognizer. The production implementation maps
/// `speech_to_text`; unit tests supply deterministic status/error callbacks.
abstract interface class SystemSpeechRecognizer {
  Future<bool> supportsOnDeviceRecognition();
  Future<bool> initialize({
    required void Function(String message, bool permanent) onError,
    required void Function(String status) onStatus,
  });
  Future<void> listen({
    required void Function(double level) onSoundLevel,
    required void Function(SystemRecognitionResult result) onResult,
    required String localeId,
    required bool onDevice,
    required Duration? pauseFor,
    required Duration? listenFor,
  });
  Future<void> stop();
}

// coverage:ignore-start
// Thin device-plugin adapter; the protocol above is exhaustively unit-tested.
class _SpeechToTextRecognizer implements SystemSpeechRecognizer {
  _SpeechToTextRecognizer() : _speech = stt.SpeechToText();

  final stt.SpeechToText _speech;

  @override
  Future<bool> supportsOnDeviceRecognition() async {
    if (kIsWeb) return false;
    // On iOS the plugin checks each locale and requires a local request.
    if (defaultTargetPlatform == TargetPlatform.iOS) return true;
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    // Without a guaranteed Android on-device service, speech_to_text 7.4
    // silently uses the default recognizer, even with onDevice enabled.
    const channel = MethodChannel('vocab_kr/system_speech');
    try {
      return await channel.invokeMethod<bool>('supportsOnDeviceRecognition') ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<bool> initialize({
    required void Function(String message, bool permanent) onError,
    required void Function(String status) onStatus,
  }) {
    // The plugin is a singleton and skips listener installation after its
    // first initialization. Route future events to this quiz's adapter.
    _speech.errorListener = (error) => onError(error.errorMsg, error.permanent);
    _speech.statusListener = onStatus;
    return _speech.initialize(
      onError: _speech.errorListener,
      onStatus: onStatus,
      // The plugin otherwise promotes its last partial to a synthetic final.
      finalTimeout: Duration.zero,
    );
  }

  @override
  Future<void> listen({
    required void Function(double level) onSoundLevel,
    required void Function(SystemRecognitionResult result) onResult,
    required String localeId,
    required bool onDevice,
    required Duration? pauseFor,
    required Duration? listenFor,
  }) => _speech.listen(
    onSoundLevelChange: onSoundLevel,
    onResult: (result) => onResult(
      SystemRecognitionResult(
        words: result.recognizedWords,
        isFinal: result.finalResult,
        confidence: result.confidence,
        alternates: [
          for (final alternate in result.alternates)
            (
              words: alternate.recognizedWords,
              confidence: alternate.confidence,
            ),
        ],
      ),
    ),
    listenOptions: stt.SpeechListenOptions(
      cancelOnError: false,
      listenMode: stt.ListenMode.search,
      partialResults: true,
      onDevice: onDevice,
      localeId: localeId,
      listenFor: listenFor,
      pauseFor: pauseFor,
    ),
  );

  @override
  Future<void> stop() => _speech.stop();
}
// coverage:ignore-end

class SpeechRecognitionService implements SystemSpeechCapture {
  SpeechRecognitionService({
    SystemSpeechRecognizer? recognizer,
    DateTime Function()? clock,
    Future<void> Function(Duration duration)? delay,
    this.releaseTimeout = sttMicReleaseTimeout,
  }) : _speech = recognizer ?? _SpeechToTextRecognizer(),
       _clock = clock ?? DateTime.now,
       _delay = delay ?? Future<void>.delayed;

  final SystemSpeechRecognizer _speech;
  final DateTime Function() _clock;
  final Future<void> Function(Duration duration) _delay;
  final Duration releaseTimeout;
  bool _initialized = false;
  bool _disposed = false;
  Future<bool>? _initializing;
  bool _isListening = false;
  // Platform status is for the UI and endpointing. Only the native stop
  // acknowledgement releases ownership for another turn or route.
  bool _nativeMayOwnMic = false;
  Future<void>? _nativeStart;
  Future<void>? _nativeStop;
  int _listenGeneration = 0;
  // Guards against duplicate onListeningDone calls within a single session.
  // Android fires notListening → done → possibly error_no_match in sequence;
  // without this flag each one would re-trigger the quiz state machine.
  bool _sessionDone = false;
  DateTime? _listenStartTime;
  // The most recent STT error code; reset at the start of each session.
  // Exposed so the caller can distinguish permanent errors (error_client)
  // from normal no-speech endings when deciding whether to retry.
  String? lastError;

  bool get isListening => _isListening;
  // Milliseconds elapsed since the current listen session started.
  // Used by the caller to detect audio-focus races (session stops too fast).
  int get listenElapsedMs => _listenStartTime == null
      ? 0
      : _clock().difference(_listenStartTime!).inMilliseconds;

  @override
  void Function()? onListeningDone;
  // Called for genuine hardware/network errors (NOT error_no_match, which is a
  // normal "no speech recognised" result and is handled via onListeningDone).
  void Function(String)? onError;

  @override
  Future<bool> supportsOnDeviceRecognition() =>
      _speech.supportsOnDeviceRecognition();

  @override
  Future<bool> initialize() {
    if (_disposed) return Future.value(false);
    if (_initialized) return Future.value(true);
    return _initializing ??= _initialize().whenComplete(() {
      _initializing = null;
    });
  }

  Future<bool> _initialize() async {
    final initialized = await _speech.initialize(
      onError: (message, permanent) {
        if (_disposed || (_sessionDone && _nativeStop != null)) return;
        sttLog(
          '[STT] ❌ onError: "$message"  permanent=$permanent  elapsed=${listenElapsedMs}ms',
        );
        _isListening = false;
        lastError = message;
        // error_no_match = STT heard audio but found no matching words.
        // This is the normal "no recognition" outcome — not a real error.
        // Anything else (error_audio, error_network, etc.) is worth reporting.
        if (message != 'error_no_match') {
          sttLog(
            '[STT] ⚠️ Forwarding hardware/network error to caller: $message',
          );
          onError?.call(message);
        }
        if (!_sessionDone) {
          _sessionDone = true;
          sttLog(
            '[STT] → onListeningDone (via onError, elapsed=${listenElapsedMs}ms)',
          );
          onListeningDone?.call();
        } else {
          sttLog(
            '[STT] onError: sessionDone already set, skipping onListeningDone',
          );
        }
      },
      onStatus: (status) {
        if (_disposed) return;
        sttLog(
          '[STT] onStatus: "$status"  _isListening=$_isListening  elapsed=${listenElapsedMs}ms',
        );
        if (status == 'listening') {
          if (_sessionDone) return;
          _isListening = true;
          _listenStartTime = _clock();
          sttLog('[STT] ✅ STT now listening — timer reset');
        } else if (status == 'notListening') {
          // The microphone ended, but the final recognition may still arrive.
          _isListening = false;
        } else if (status == 'done') {
          _isListening = false;
          if (!_sessionDone) {
            _sessionDone = true;
            sttLog(
              '[STT] → onListeningDone (via status="$status", elapsed=${listenElapsedMs}ms)',
            );
            onListeningDone?.call();
          } else {
            sttLog(
              '[STT] status="$status" but sessionDone already set, skipping',
            );
          }
        }
      },
    );
    _initialized = initialized && !_disposed;
    sttLog('[STT] initialize() → $_initialized');
    return _initialized;
  }

  @override
  Future<bool> startListening({
    required String langCode,
    bool onDevice = false,
    required void Function(String primary, List<String> candidates) onResult,
    void Function(String primary, List<String> candidates)? onPartial,
    // Quiz deadlines belong to SttRace, so speech_to_text never starts a
    // second, untracked Dart stop timer for the same microphone.
    Duration? pauseFor,
    Duration? listenFor,
  }) async {
    if (!_initialized) {
      sttLog('[STT] startListening() skipped — not initialised');
      return false;
    }
    if (_nativeMayOwnMic) {
      sttLog('[STT] startListening() — stopping stale session first');
      final stopping = stopListening();
      final generation = _listenGeneration;
      await stopping;
      await _delay(const Duration(milliseconds: 200));
      if (generation != _listenGeneration || _disposed) return false;
    }

    final generation = ++_listenGeneration;
    _nativeMayOwnMic = true;
    _sessionDone = false;
    lastError = null;
    final localeId = Languages.speechLocaleFor(langCode);
    sttLog('[STT] startListening() localeId=$localeId');

    // Mic energy telemetry: distinguishes "engine ignored real speech"
    // (level spikes, no hypothesis) from "signal never reached the engine"
    // (flat level) — field case 2026-07-08: short words in a noisy room
    // produced zero hypotheses, not even wrong ones.
    var rmsMin = double.infinity, rmsMax = double.negativeInfinity;
    var rmsLastLogged = _clock();

    try {
      final starting = _nativeStart = Future<void>.microtask(() async {
        if (generation != _listenGeneration) return;
        await _speech.listen(
          onSoundLevel: (level) {
            if (generation != _listenGeneration) return;
            if (level < rmsMin) rmsMin = level;
            if (level > rmsMax) rmsMax = level;
            // One line per second keeps the trace readable at 10+ events/s.
            final now = _clock();
            if (now.difference(rmsLastLogged).inMilliseconds >= 1000) {
              rmsLastLogged = now;
              sttLog(
                '[STT] 🎚 level=${level.toStringAsFixed(1)}  min=${rmsMin.toStringAsFixed(1)}  max=${rmsMax.toStringAsFixed(1)}  elapsed=${listenElapsedMs}ms',
              );
            }
          },
          onResult: (result) {
            if (generation != _listenGeneration) return;
            // Every interpretation the engine considered, with confidence —
            // the raw evidence for "what did it actually hear". The engine's
            // top pick is often NOT the right one while an alternate is
            // (field log 2026-07-06: primary "병환이" 0.87, alternate
            // "병아리" 1.00 — the user's actual word), so ALL candidates are
            // forwarded for validation.
            final alternates = [
              for (final a in result.alternates)
                '"${a.words}"(${a.confidence.toStringAsFixed(2)})',
            ].join(' | ');
            final candidates = <String>{
              result.words,
              for (final a in result.alternates) a.words,
            }.where((w) => w.trim().isNotEmpty).toList();
            sttLog(
              '[STT] onResult: "${result.words}"  final=${result.isFinal}  confidence=${result.confidence.toStringAsFixed(2)}  elapsed=${listenElapsedMs}ms  alternates=[$alternates]',
            );
            if (result.isFinal) {
              sttLog(
                '[STT] ✅ Final result → forwarding ${candidates.length} candidate(s)',
              );
              onResult(result.words, candidates);
            } else if (result.words.isNotEmpty) {
              sttLog('[STT] ⏳ Partial: "${result.words}"');
              onPartial?.call(result.words, candidates);
            }
          },
          localeId: localeId,
          onDevice: onDevice,
          listenFor: listenFor,
          pauseFor: pauseFor,
        );
      });
      await starting;
      if (generation != _listenGeneration) return false;
      if (!_sessionDone) _isListening = true;
      sttLog(
        '[STT] 🎙️ startListening() → started (locale=$localeId pauseFor=$pauseFor listenFor=$listenFor)',
      );
      return true;
    } catch (e) {
      sttLog('[STT] 💥 startListening() exception: $e');
      return false;
    }
  }

  @override
  Future<void> stopListening() {
    sttLog('[STT] stopListening() _isListening=$_isListening');
    _listenGeneration++;
    _sessionDone = true;
    if (!_nativeMayOwnMic) return Future.value();
    // A caller can time out while the underlying stop is still running.
    // Subsequent callers join that request until it really settles.
    return (_nativeStop ??= _release()).timeout(releaseTimeout);
  }

  Future<void> _release() async {
    try {
      // A transition during native startup must stop AFTER that request.
      // A failed startup can still have dispatched work on the platform.
      try {
        await _nativeStart;
      } catch (_) {}
      await _speech.stop();
      _nativeMayOwnMic = false;
      _isListening = false;
    } finally {
      _nativeStart = null;
      _nativeStop = null;
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _initialized = false;
    onListeningDone = null;
    onError = null;
    unawaited(
      stopListening().catchError((Object error) {
        sttLog('[STT] disposal could not release the microphone: $error');
      }),
    );
  }
}
