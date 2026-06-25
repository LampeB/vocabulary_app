import 'package:flutter/foundation.dart';
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
        debugPrint('[STT] ❌ onError: "${e.errorMsg}"  permanent=${e.permanent}  elapsed=${listenElapsedMs}ms');
        _isListening = false;
        lastError = e.errorMsg;
        // error_no_match = STT heard audio but found no matching words.
        // This is the normal "no recognition" outcome — not a real error.
        // Anything else (error_audio, error_network, etc.) is worth reporting.
        if (e.errorMsg != 'error_no_match') {
          debugPrint('[STT] ⚠️ Forwarding hardware/network error to caller: ${e.errorMsg}');
          onError?.call(e.errorMsg);
        }
        if (!_sessionDone) {
          _sessionDone = true;
          debugPrint('[STT] → onListeningDone (via onError, elapsed=${listenElapsedMs}ms)');
          onListeningDone?.call();
        } else {
          debugPrint('[STT] onError: sessionDone already set, skipping onListeningDone');
        }
      },
      onStatus: (status) {
        debugPrint('[STT] onStatus: "$status"  _isListening=$_isListening  elapsed=${listenElapsedMs}ms');
        if (status == 'listening') {
          _isListening = true;
          _sessionDone = false;
          _listenStartTime = DateTime.now();
          debugPrint('[STT] ✅ STT now listening — timer reset');
        } else if (status == 'notListening' || status == 'done') {
          _isListening = false;
          if (!_sessionDone) {
            _sessionDone = true;
            debugPrint('[STT] → onListeningDone (via status="$status", elapsed=${listenElapsedMs}ms)');
            onListeningDone?.call();
          } else {
            debugPrint('[STT] status="$status" but sessionDone already set, skipping');
          }
        }
      },
    );
    debugPrint('[STT] initialize() → $_initialized');
    return _initialized;
  }

  Future<bool> startListening({
    required String langCode,
    required void Function(String) onResult,
    void Function(String)? onPartial,
    Duration pauseFor = const Duration(seconds: 5),
    Duration listenFor = const Duration(seconds: 10),
  }) async {
    if (!_initialized) {
      debugPrint('[STT] startListening() skipped — not initialised');
      return false;
    }
    if (_isListening) {
      debugPrint('[STT] startListening() — stopping stale session first');
      await _speech.stop();
      _isListening = false;
      await Future.delayed(const Duration(milliseconds: 200));
    }

    _sessionDone = false;
    lastError = null;
    final localeId = langCode == 'ko' ? 'ko-KR' : 'fr-FR';
    debugPrint('[STT] startListening() localeId=$localeId');

    try {
      await _speech.listen(
        onResult: (result) {
          debugPrint('[STT] onResult: "${result.recognizedWords}"  final=${result.finalResult}  confidence=${result.confidence}  elapsed=${listenElapsedMs}ms');
          if (result.finalResult) {
            debugPrint('[STT] ✅ Final result → forwarding "${result.recognizedWords}"');
            onResult(result.recognizedWords);
          } else if (result.recognizedWords.isNotEmpty) {
            debugPrint('[STT] ⏳ Partial: "${result.recognizedWords}"');
            onPartial?.call(result.recognizedWords);
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
      debugPrint('[STT] 🎙️ startListening() → started (locale=$localeId pauseFor=${pauseFor.inSeconds}s listenFor=${listenFor.inSeconds}s)');
      return true;
    } catch (e) {
      debugPrint('[STT] 💥 startListening() exception: $e');
      return false;
    }
  }

  Future<void> stopListening() async {
    debugPrint('[STT] stopListening() _isListening=$_isListening');
    if (_isListening) {
      await _speech.stop();
      _isListening = false;
    }
  }

  void dispose() {
    _speech.stop();
    _initialized = false;
    _isListening = false;
  }
}
