import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_error.dart';

class SpeechRecognitionService {
  final _speech = stt.SpeechToText();
  bool _initialized = false;
  bool _isListening = false;

  bool get isListening => _isListening;

  Function()? onListeningDone;

  Future<bool> initialize() async {
    if (_initialized) return true;
    _initialized = await _speech.initialize(
      onError: (SpeechRecognitionError e) {
        _isListening = false;
        onListeningDone?.call();
      },
      onStatus: (status) {
        if (status == 'notListening' || status == 'done') {
          _isListening = false;
          onListeningDone?.call();
        } else if (status == 'listening') {
          _isListening = true;
        }
      },
    );
    return _initialized;
  }

  Future<bool> startListening({
    required String langCode,
    required void Function(String) onResult,
    void Function(String)? onPartial,
    Duration pauseFor = const Duration(seconds: 5),
    Duration listenFor = const Duration(seconds: 10),
  }) async {
    if (!_initialized) return false;
    if (_isListening) {
      await _speech.stop();
      _isListening = false;
      await Future.delayed(const Duration(milliseconds: 200));
    }

    try {
      await _speech.listen(
        onResult: (result) {
          if (result.finalResult) {
            onResult(result.recognizedWords);
          } else if (result.recognizedWords.isNotEmpty) {
            onPartial?.call(result.recognizedWords);
          }
        },
        localeId: langCode == 'ko' ? 'ko-KR' : 'fr-FR',
        listenOptions: stt.SpeechListenOptions(
          cancelOnError: false,
          listenMode: stt.ListenMode.search,
          partialResults: true,
        ),
        listenFor: listenFor,
        pauseFor: pauseFor,
      );
      _isListening = true;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> stopListening() async {
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
