part of 'speech_recognition_service.dart';

/// Owns one tagged native recognizer session. A successful stop reply only
/// accepts the command. The platform's separate release event confirms that
/// this exact session has torn down its capture.
class _NativeSystemSpeechRecognizer implements SystemSpeechRecognizer {
  static const _channel = MethodChannel('vocab_kr/system_speech');
  static int _nextSessionId = 0;
  final _permissions = stt.SpeechToText();
  _NativeSpeechSession? _session;
  void Function(String, bool)? _onError;
  void Function(String)? _onStatus;

  @override
  Future<bool> supportsOnDeviceRecognition() async {
    try {
      return await _channel.invokeMethod<bool>('supportsOnDeviceRecognition') ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<bool> initialize({
    required void Function(String, bool) onError,
    required void Function(String) onStatus,
  }) {
    _onError = onError;
    _onStatus = onStatus;
    _channel.setMethodCallHandler(_handle);
    // Reuse the plugin's application permission flow. It never opens audio;
    // only the tagged native bridge below may start a mobile recording.
    return _permissions.initialize();
  }

  Future<void> _handle(MethodCall call) async {
    final args = call.arguments as Map<Object?, Object?>;
    final session = _session;
    if (session == null || args['session'] != session.id) return;
    if (call.method == 'released' || call.method == 'releaseFailed') {
      if (!session.released.isCompleted) {
        session.released.complete(call.method == 'released');
      }
      return;
    }
    if (session.releasing || session.released.isCompleted) return;
    switch (call.method) {
      case 'status':
        _onStatus?.call(args['status'] as String);
      case 'error':
        _onError?.call(args['message'] as String, false);
      case 'level':
        session.onSoundLevel((args['level'] as num).toDouble());
      case 'result':
        final alternates = [
          for (final item in args['alternates'] as List)
            (
              words: item['words'] as String,
              confidence: (item['confidence'] as num).toDouble(),
            ),
        ];
        if (alternates.isEmpty) return;
        session.onResult(
          SystemRecognitionResult(
            words: alternates.first.words,
            confidence: alternates.first.confidence,
            isFinal: args['isFinal'] == true,
            alternates: alternates,
          ),
        );
    }
  }

  @override
  Future<void> listen({
    required void Function(double) onSoundLevel,
    required void Function(SystemRecognitionResult) onResult,
    required String localeId,
    required bool onDevice,
    required Duration? pauseFor,
    required Duration? listenFor,
  }) async {
    final session = _NativeSpeechSession(
      ++_nextSessionId,
      onSoundLevel,
      onResult,
    );
    _session = session;
    final started = await _channel.invokeMethod<bool>('listen', {
      'session': session.id,
      'locale': localeId,
      'onDevice': onDevice,
    });
    if (started != true) {
      _session = null;
      throw StateError(
        'Native recognizer refused to start session ${session.id}',
      );
    }
  }

  @override
  Future<void> stop() async {
    final session = _session;
    if (session == null) return;
    session.releasing = true;
    if (!session.released.isCompleted) {
      final accepted = await _channel.invokeMethod<bool>('stop', {
        'session': session.id,
      });
      if (accepted != true) {
        throw StateError(
          'Native recognizer refused to release session ${session.id}',
        );
      }
    }
    if (!await session.released.future) {
      session.released = Completer<bool>();
      throw StateError('Native teardown failed for session ${session.id}');
    }
    _session = null;
  }
}

class _NativeSpeechSession {
  _NativeSpeechSession(this.id, this.onSoundLevel, this.onResult);

  final int id;
  final void Function(double) onSoundLevel;
  final void Function(SystemRecognitionResult) onResult;
  var released = Completer<bool>();
  bool releasing = false;
}
