import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/services/speech/speech_recognition_service.dart';

class _FakeRecognizer implements SystemSpeechRecognizer {
  bool initializeResult = true;
  bool throwOnListen = false;
  bool throwOnStop = false;
  var initializeCalls = 0;
  var stopCalls = 0;
  String? localeId;
  Duration? pauseFor;
  Duration? listenFor;
  void Function(String message, bool permanent)? onError;
  void Function(String status)? onStatus;
  void Function(double level)? onSoundLevel;
  void Function(SystemRecognitionResult result)? onResult;

  @override
  Future<bool> initialize({
    required void Function(String message, bool permanent) onError,
    required void Function(String status) onStatus,
  }) async {
    initializeCalls++;
    this.onError = onError;
    this.onStatus = onStatus;
    return initializeResult;
  }

  @override
  Future<void> listen({
    required void Function(double level) onSoundLevel,
    required void Function(SystemRecognitionResult result) onResult,
    required String localeId,
    required Duration pauseFor,
    required Duration listenFor,
  }) async {
    if (throwOnListen) throw StateError('platform unavailable');
    this.onSoundLevel = onSoundLevel;
    this.onResult = onResult;
    this.localeId = localeId;
    this.pauseFor = pauseFor;
    this.listenFor = listenFor;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    if (throwOnStop) throw StateError('already released');
  }
}

void main() {
  test(
      'initializes once and translates partial/final hypotheses with alternates',
      () async {
    final native = _FakeRecognizer();
    final service = SpeechRecognitionService(recognizer: native);
    final partials = <(String, List<String>)>[];
    final finals = <(String, List<String>)>[];

    expect(await service.startListening(langCode: 'ko', onResult: (_, __) {}),
        isFalse);
    expect(await service.initialize(), isTrue);
    expect(await service.initialize(), isTrue);
    expect(native.initializeCalls, 1);

    expect(
        await service.startListening(
          langCode: 'ko',
          onResult: (word, candidates) => finals.add((word, candidates)),
          onPartial: (word, candidates) => partials.add((word, candidates)),
          pauseFor: const Duration(seconds: 2),
          listenFor: const Duration(seconds: 7),
        ),
        isTrue);
    expect(native.localeId, 'ko-KR');
    expect(native.pauseFor, const Duration(seconds: 2));
    expect(native.listenFor, const Duration(seconds: 7));

    native.onResult!(const SystemRecognitionResult(
      words: '고양',
      isFinal: false,
      confidence: .4,
      alternates: [(words: '고양이', confidence: .9), (words: '', confidence: 0)],
    ));
    native.onResult!(const SystemRecognitionResult(
      words: '고양이',
      isFinal: true,
      confidence: .95,
      alternates: [(words: '고양', confidence: .2)],
    ));

    expect(partials.single.$1, '고양');
    expect(partials.single.$2, ['고양', '고양이']);
    expect(finals.single.$1, '고양이');
    expect(finals.single.$2, ['고양이', '고양']);
  });

  test(
      'deduplicates session-end statuses and handles normal versus real errors',
      () async {
    final native = _FakeRecognizer();
    var now = DateTime.utc(2026, 9, 17, 12);
    final service = SpeechRecognitionService(
      recognizer: native,
      clock: () => now,
    );
    var done = 0;
    final errors = <String>[];
    service.onListeningDone = () => done++;
    service.onError = errors.add;
    await service.initialize();

    native.onStatus!('listening');
    now = now.add(const Duration(milliseconds: 350));
    expect(service.isListening, isTrue);
    expect(service.listenElapsedMs, 350);
    native.onStatus!('notListening');
    native.onStatus!('done');
    expect(service.isListening, isFalse);
    expect(done, 1);

    await service.startListening(langCode: 'fr', onResult: (_, __) {});
    native.onError!('error_no_match', false);
    native.onError!('error_no_match', false);
    expect(errors, isEmpty);
    expect(done, 2);

    await service.startListening(langCode: 'fr', onResult: (_, __) {});
    native.onSoundLevel!(1.2);
    now = now.add(const Duration(seconds: 1));
    native.onSoundLevel!(4.8);
    native.onError!('error_audio', true);
    expect(errors, ['error_audio']);
    expect(service.lastError, 'error_audio');
    expect(done, 3);
  });

  test('releases a stale session, absorbs platform failures, and disposes',
      () async {
    final native = _FakeRecognizer();
    final delays = <Duration>[];
    final service = SpeechRecognitionService(
      recognizer: native,
      delay: (duration) async => delays.add(duration),
    );
    await service.initialize();
    native.onStatus!('listening');
    native.throwOnStop = true;
    native.throwOnListen = true;

    expect(await service.startListening(langCode: 'en', onResult: (_, __) {}),
        isFalse);
    expect(native.stopCalls, 1);
    expect(delays, [const Duration(milliseconds: 200)]);
    expect(service.isListening, isFalse);

    native.throwOnStop = false;
    service.dispose();
    await Future<void>.delayed(Duration.zero);
    expect(native.stopCalls, 2);
    expect(service.isListening, isFalse);
  });

  test('keeps the service unready when native initialization fails', () async {
    final native = _FakeRecognizer()..initializeResult = false;
    final service = SpeechRecognitionService(recognizer: native);

    expect(await service.initialize(), isFalse);
    expect(await service.startListening(langCode: 'fr', onResult: (_, __) {}),
        isFalse);
  });
}
