import '../../core/utils/stt_debug_log.dart';
import '../../core/languages.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_error.dart';

class SpeechRecognitionService {
  final _speech = stt.SpeechToText();
  bool _initialized = false;
  bool _isListening = false;
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
      : DateTime.now().difference(_listenStartTime!).inMilliseconds;

  Function()? onListeningDone;
  // Called for genuine hardware/network errors (NOT error_no_match, which is a
  // normal "no speech recognised" result and is handled via onListeningDone).
  void Function(String)? onError;

  Future<bool> initialize() async {
    if (_initialized) return true;
    _initialized = await _speech.initialize(
      onError: (SpeechRecognitionError e) {
        sttLog(
            '[STT] ❌ onError: "${e.errorMsg}"  permanent=${e.permanent}  elapsed=${listenElapsedMs}ms');
        _isListening = false;
        lastError = e.errorMsg;
        // error_no_match = STT heard audio but found no matching words.
        // This is the normal "no recognition" outcome — not a real error.
        // Anything else (error_audio, error_network, etc.) is worth reporting.
        if (e.errorMsg != 'error_no_match') {
          sttLog(
              '[STT] ⚠️ Forwarding hardware/network error to caller: ${e.errorMsg}');
          onError?.call(e.errorMsg);
        }
        if (!_sessionDone) {
          _sessionDone = true;
          sttLog(
              '[STT] → onListeningDone (via onError, elapsed=${listenElapsedMs}ms)');
          onListeningDone?.call();
        } else {
          sttLog(
              '[STT] onError: sessionDone already set, skipping onListeningDone');
        }
      },
      onStatus: (status) {
        sttLog(
            '[STT] onStatus: "$status"  _isListening=$_isListening  elapsed=${listenElapsedMs}ms');
        if (status == 'listening') {
          _isListening = true;
          _sessionDone = false;
          _listenStartTime = DateTime.now();
          sttLog('[STT] ✅ STT now listening — timer reset');
        } else if (status == 'notListening' || status == 'done') {
          _isListening = false;
          if (!_sessionDone) {
            _sessionDone = true;
            sttLog(
                '[STT] → onListeningDone (via status="$status", elapsed=${listenElapsedMs}ms)');
            onListeningDone?.call();
          } else {
            sttLog(
                '[STT] status="$status" but sessionDone already set, skipping');
          }
        }
      },
    );
    sttLog('[STT] initialize() → $_initialized');
    return _initialized;
  }

  Future<bool> startListening({
    required String langCode,
    required void Function(String primary, List<String> candidates) onResult,
    void Function(String primary, List<String> candidates)? onPartial,
    Duration pauseFor = const Duration(seconds: 5),
    Duration listenFor = const Duration(seconds: 10),
  }) async {
    if (!_initialized) {
      sttLog('[STT] startListening() skipped — not initialised');
      return false;
    }
    if (_isListening) {
      sttLog('[STT] startListening() — stopping stale session first');
      await stopListening();
      await Future.delayed(const Duration(milliseconds: 200));
    }

    _sessionDone = false;
    lastError = null;
    final localeId = Languages.speechLocaleFor(langCode);
    sttLog('[STT] startListening() localeId=$localeId');

    // Mic energy telemetry: distinguishes "engine ignored real speech"
    // (level spikes, no hypothesis) from "signal never reached the engine"
    // (flat level) — field case 2026-07-08: short words in a noisy room
    // produced zero hypotheses, not even wrong ones.
    var rmsMin = double.infinity, rmsMax = double.negativeInfinity;
    var rmsLastLogged = DateTime.now();

    try {
      await _speech.listen(
        onSoundLevelChange: (level) {
          if (level < rmsMin) rmsMin = level;
          if (level > rmsMax) rmsMax = level;
          // One line per second keeps the trace readable at 10+ events/s.
          final now = DateTime.now();
          if (now.difference(rmsLastLogged).inMilliseconds >= 1000) {
            rmsLastLogged = now;
            sttLog(
                '[STT] 🎚 level=${level.toStringAsFixed(1)}  min=${rmsMin.toStringAsFixed(1)}  max=${rmsMax.toStringAsFixed(1)}  elapsed=${listenElapsedMs}ms');
          }
        },
        onResult: (result) {
          // Every interpretation the engine considered, with confidence —
          // the raw evidence for "what did it actually hear". The engine's
          // top pick is often NOT the right one while an alternate is
          // (field log 2026-07-06: primary "병환이" 0.87, alternate
          // "병아리" 1.00 — the user's actual word), so ALL candidates are
          // forwarded for validation.
          final alternates = [
            for (final a in result.alternates)
              '"${a.recognizedWords}"(${a.confidence.toStringAsFixed(2)})',
          ].join(' | ');
          final candidates = <String>{
            result.recognizedWords,
            for (final a in result.alternates) a.recognizedWords,
          }.where((w) => w.trim().isNotEmpty).toList();
          sttLog(
              '[STT] onResult: "${result.recognizedWords}"  final=${result.finalResult}  confidence=${result.confidence.toStringAsFixed(2)}  elapsed=${listenElapsedMs}ms  alternates=[$alternates]');
          if (result.finalResult) {
            sttLog(
                '[STT] ✅ Final result → forwarding ${candidates.length} candidate(s)');
            onResult(result.recognizedWords, candidates);
          } else if (result.recognizedWords.isNotEmpty) {
            sttLog('[STT] ⏳ Partial: "${result.recognizedWords}"');
            onPartial?.call(result.recognizedWords, candidates);
          }
        },
        listenOptions: stt.SpeechListenOptions(
          cancelOnError: false,
          listenMode: stt.ListenMode.search,
          partialResults: true,
          localeId: localeId,
          listenFor: listenFor,
          pauseFor: pauseFor,
        ),
      );
      _isListening = true;
      sttLog(
          '[STT] 🎙️ startListening() → started (locale=$localeId pauseFor=${pauseFor.inSeconds}s listenFor=${listenFor.inSeconds}s)');
      return true;
    } catch (e) {
      sttLog('[STT] 💥 startListening() exception: $e');
      return false;
    }
  }

  Future<void> stopListening() async {
    sttLog('[STT] stopListening() _isListening=$_isListening');
    // Always send the platform stop, even when its callback has already said
    // `notListening`. Samsung's remote recognizer can still own the audio
    // session after that callback; skipping this release caused a following
    // system/Whisper lane to collide with an invisible live microphone.
    // Swallow the killed session's trailing done/error events so they cannot
    // be attributed to the lane that starts next.
    _sessionDone = true;
    try {
      await _speech.stop();
    } catch (error) {
      sttLog('[STT] stopListening() platform stop failed: $error');
    }
    _isListening = false;
  }

  void dispose() {
    _speech.stop();
    _initialized = false;
    _isListening = false;
  }
}
