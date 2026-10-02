import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/core/utils/pcm_segmenter.dart';
import 'package:vocab_kr/services/speech/shared_pcm_capture.dart';
import 'package:vocab_kr/services/speech/stt_engine.dart';
import 'package:vocab_kr/services/speech/stt_race.dart';
import 'package:vocab_kr/services/speech/stt_race_status.dart';

PcmSegment _seg([int ms = 800]) => PcmSegment(Uint8List(ms * 32), ms, 5000);

class _FakeSession implements PcmCaptureSession {
  _FakeSession(this._onSpeechChange, this._onSegment);
  final void Function(bool) _onSpeechChange;
  final void Function(PcmSegment) _onSegment;
  bool speaking = false;
  bool closed = false;
  bool flushed = false;

  void startSpeaking() {
    speaking = true;
    _onSpeechChange(true);
  }

  void finishUtterance([int ms = 800]) {
    speaking = false;
    _onSpeechChange(false);
    _onSegment(_seg(ms));
  }

  @override
  bool get inSpeech => speaking && !closed;

  @override
  Future<PcmSegment?> close({bool flush = false}) async {
    if (closed) return null;
    closed = true;
    if (flush && speaking) {
      flushed = true;
      speaking = false;
      return _seg(1200);
    }
    return null;
  }
}

class _FakeSource implements PcmCaptureSource {
  bool openResult = true;
  int opens = 0;
  _FakeSession? session;

  @override
  Future<PcmCaptureSession?> open({
    required void Function(bool inSpeech) onSpeechChange,
    required void Function(PcmSegment segment) onSegment,
  }) async {
    opens++;
    if (!openResult) return null;
    return session = _FakeSession(onSpeechChange, onSegment);
  }
}

/// A shared engine whose transcriptions the test resolves by hand.
class _SharedEngine implements SttEngine {
  _SharedEngine(this.id, {this.requiresNetwork = false, this.confidence = .9});

  @override
  final String id;
  @override
  final bool requiresNetwork;
  final double confidence;
  final calls = <Completer<String?>>[];
  final segments = <PcmSegment>[];
  bool stopped = false;
  bool started = false;

  @override
  SttCapture get capture => SttCapture.sharedPcm;
  @override
  bool get isReady => true;
  @override
  bool supportsLanguage(String langCode) => true;
  @override
  Future<void> prepare() async {}

  @override
  Future<bool> start({
    required String langCode,
    required List<String> promptHints,
    required void Function(SttHypothesis) onHypothesis,
    void Function()? onSessionEnd,
  }) async =>
      started = true;

  @override
  Future<SttHypothesis?> recognize(PcmSegment segment,
      {required String langCode, required List<String> promptHints}) async {
    segments.add(segment);
    final c = Completer<String?>();
    calls.add(c);
    final text = await c.future;
    return text == null
        ? null
        : SttHypothesis(
            engineId: id,
            transcript: text,
            candidates: [text],
            confidence: confidence);
  }

  void answer(String? text, {int call = -1}) =>
      calls[call < 0 ? calls.length + call : call].complete(text);
  void fail({int call = -1}) => calls[call < 0 ? calls.length + call : call]
      .completeError(Exception('offline'));

  @override
  Future<void> stop() async => stopped = true;
  @override
  void dispose() {}
}

Future<void> _pump() => Future<void>.delayed(Duration.zero);
Future<void> _wait(int ms) => Future<void>.delayed(Duration(milliseconds: ms));

void main() {
  group('SttRace — shared capture (parallel engines)', () {
    test('every shared engine hears the same utterance; first correct wins',
        () async {
      final source = _FakeSource();
      final scribe = _SharedEngine('elevenlabs', requiresNetwork: true);
      final whisper = _SharedEngine('whisper');
      final future = SttRace([scribe, whisper], capture: source)
          .run(langCode: 'ko', acceptedAnswers: ['가다']);
      await _pump();

      source.session!.startSpeaking();
      source.session!.finishUtterance();
      await _pump();
      expect(scribe.segments.length, 1);
      expect(whisper.segments.length, 1);
      expect(
          identical(scribe.segments.single, whisper.segments.single), isTrue);

      scribe.answer('가다');
      final outcome = await future;
      expect(outcome.matched, isTrue);
      expect(outcome.winnerEngineId, 'elevenlabs');
      expect(source.session!.closed, isTrue);
      expect(source.opens, 1, reason: 'one mic for all engines');
    });

    test(
        'a correct result arriving AFTER the window still wins — never '
        'dropped (field 2026-10-02: "가다" landed 0.7s after the cutoff)',
        () async {
      final source = _FakeSource();
      final scribe = _SharedEngine('elevenlabs');
      final future = SttRace([scribe], capture: source).run(
        langCode: 'ko',
        acceptedAnswers: ['가다'],
        timeout: const Duration(milliseconds: 40),
      );
      await _pump();
      source.session!.startSpeaking();
      source.session!.finishUtterance();
      await _wait(80); // window long over, request still in flight
      expect(source.session!.closed, isTrue);
      scribe.answer('가다');

      final outcome = await future;
      expect(outcome.matched, isTrue);
    });

    test('the window never cuts a learner mid-answer: it waits for the end',
        () async {
      final source = _FakeSource();
      final scribe = _SharedEngine('elevenlabs');
      final future = SttRace([scribe], capture: source).run(
        langCode: 'fr',
        acceptedAnswers: ['livre'],
        timeout: const Duration(milliseconds: 40),
        maxSpeechOverrun: const Duration(seconds: 2),
      );
      await _pump();
      source.session!.startSpeaking();
      await _wait(70); // deadline passes while speaking
      expect(source.session!.closed, isFalse, reason: 'still speaking');

      source.session!.finishUtterance();
      await _pump();
      expect(source.session!.closed, isTrue);
      scribe.answer('livre');
      expect((await future).matched, isTrue);
    });

    test('speech running past the overrun is flushed and still analysed',
        () async {
      final source = _FakeSource();
      final scribe = _SharedEngine('elevenlabs');
      final future = SttRace([scribe], capture: source).run(
        langCode: 'fr',
        acceptedAnswers: ['lire'],
        timeout: const Duration(milliseconds: 30),
        maxSpeechOverrun: const Duration(milliseconds: 30),
      );
      await _pump();
      source.session!.startSpeaking();
      await _wait(90);
      expect(source.session!.flushed, isTrue);
      expect(scribe.segments.single.durationMs, 1200);
      scribe.answer('lire');
      expect((await future).matched, isTrue);
    });

    test('silence resolves at the deadline as a real, empty window', () async {
      final source = _FakeSource();
      final future = SttRace([_SharedEngine('whisper')], capture: source).run(
        langCode: 'fr',
        acceptedAnswers: ['thé'],
        timeout: const Duration(milliseconds: 30),
      );
      final outcome = await future;
      expect(outcome.matched, isFalse);
      expect(outcome.bestTranscript, isNull);
      expect(outcome.hadRealSession, isTrue);
    });

    test('a mic that cannot open is not a real window', () async {
      final source = _FakeSource()..openResult = false;
      final outcome = await SttRace([_SharedEngine('whisper')], capture: source)
          .run(langCode: 'fr', acceptedAnswers: ['thé']);
      expect(outcome.matched, isFalse);
      expect(outcome.hadRealSession, isFalse);
    });

    test(
        'a wrong answer keeps the mic open for a self-correction; at the end '
        'the most confident transcript is reported', () async {
      final source = _FakeSource();
      final scribe = _SharedEngine('elevenlabs', confidence: .95);
      final whisper = _SharedEngine('whisper', confidence: .7);
      final future = SttRace([scribe, whisper], capture: source).run(
        langCode: 'ko',
        acceptedAnswers: ['와'],
        timeout: const Duration(milliseconds: 60),
      );
      await _pump();
      source.session!.startSpeaking();
      source.session!.finishUtterance();
      whisper.answer('과');
      scribe.answer('고');
      await _pump();
      expect(source.session!.closed, isFalse, reason: 'still listening');

      final outcome = await future;
      expect(outcome.matched, isFalse);
      expect(outcome.bestTranscript, '고');
    });

    test('a self-correction in a second utterance wins', () async {
      final source = _FakeSource();
      final scribe = _SharedEngine('elevenlabs');
      final future = SttRace([scribe], capture: source)
          .run(langCode: 'fr', acceptedAnswers: ['étudier']);
      await _pump();
      source.session!.startSpeaking();
      source.session!.finishUtterance();
      scribe.answer('réviser');
      await _pump();
      source.session!.startSpeaking();
      source.session!.finishUtterance();
      scribe.answer('étudier');
      expect((await future).matched, isTrue);
    });

    test('one engine failing does not stop another from winning', () async {
      final source = _FakeSource();
      final scribe = _SharedEngine('elevenlabs');
      final whisper = _SharedEngine('whisper');
      final statuses = <SttRaceStatus>[];
      final future = SttRace([scribe, whisper], capture: source).run(
          langCode: 'fr', acceptedAnswers: ['thé'], onStatus: statuses.add);
      await _pump();
      source.session!.startSpeaking();
      source.session!.finishUtterance();
      scribe.fail();
      await _pump();
      expect(
          statuses.last.engines
              .firstWhere((e) => e.engineId == 'elevenlabs')
              .state,
          SttEngineState.failed);
      whisper.answer('thé');
      final outcome = await future;
      expect(outcome.matched, isTrue);
      expect(outcome.winnerEngineId, 'whisper');
    });

    test('a hung engine is marked failed after the analysis timeout', () async {
      final source = _FakeSource();
      final whisper = _SharedEngine('whisper');
      final statuses = <SttRaceStatus>[];
      final future = SttRace([whisper], capture: source).run(
        langCode: 'fr',
        acceptedAnswers: ['thé'],
        timeout: const Duration(milliseconds: 20),
        analysisTimeout: const Duration(milliseconds: 40),
        onStatus: statuses.add,
      );
      await _pump();
      source.session!.startSpeaking();
      source.session!.finishUtterance();
      final outcome = await future;
      expect(outcome.matched, isFalse);
      expect(statuses.last.engines.single.state, SttEngineState.failed);
    });

    test(
        'status walks starting → listening → speaking → analyzing → done, '
        'with per-engine chips', () async {
      final source = _FakeSource();
      final scribe = _SharedEngine('elevenlabs', requiresNetwork: true);
      final statuses = <SttRaceStatus>[];
      final future = SttRace([scribe], capture: source)
          .run(langCode: 'ko', acceptedAnswers: ['책'], onStatus: statuses.add);
      await _pump();
      source.session!.startSpeaking();
      source.session!.finishUtterance();
      await _pump();
      scribe.answer('책');
      await future;

      final phases = statuses.map((s) => s.phase).toList();
      expect(phases.first, SttPhase.starting);
      expect(
          phases.toSet().toList(),
          containsAllInOrder([
            SttPhase.starting,
            SttPhase.listening,
            SttPhase.speaking,
            SttPhase.analyzing,
            SttPhase.done,
          ]));
      final chip = statuses.last.engines.single;
      expect(chip.engineId, 'elevenlabs');
      expect(chip.requiresNetwork, isTrue);
      expect(chip.state, SttEngineState.heard);
      expect(chip.transcript, '책');
      expect(chip.matched, isTrue);
    });

    test('mic closing with analyses in flight reports a pending verdict',
        () async {
      final source = _FakeSource();
      final scribe = _SharedEngine('elevenlabs');
      var pending = 0;
      final future = SttRace([scribe], capture: source).run(
        langCode: 'fr',
        acceptedAnswers: ['thé'],
        timeout: const Duration(milliseconds: 20),
        onMicClosedPending: () => pending++,
      );
      await _pump();
      source.session!.startSpeaking();
      source.session!.finishUtterance();
      await _wait(50);
      expect(pending, 1);
      scribe.answer('thé');
      expect((await future).matched, isTrue);
    });
  });

  group('SttRace.cancel — a superseded listen must not touch the next one', () {
    test(
        'cancel resolves the race, closes its own mic window, and never '
        'stops the shared engines (field 2026-10-02: the previous turn\'s '
        'timer cut the next turn 38ms after it opened)', () async {
      final source = _FakeSource();
      final scribe = _SharedEngine('elevenlabs');
      final race = SttRace([scribe], capture: source);
      final future = race.run(
          langCode: 'fr',
          acceptedAnswers: ['thé'],
          timeout: const Duration(milliseconds: 30));
      await _pump();
      race.cancel();
      final outcome = await future;
      expect(outcome.cancelled, isTrue);
      expect(source.session!.closed, isTrue);
      expect(scribe.stopped, isFalse);
    });

    test('a cancelled race ignores later results', () async {
      final source = _FakeSource();
      final scribe = _SharedEngine('elevenlabs');
      final statuses = <SttRaceStatus>[];
      final race = SttRace([scribe], capture: source);
      final future = race.run(
          langCode: 'fr', acceptedAnswers: ['thé'], onStatus: statuses.add);
      await _pump();
      source.session!.startSpeaking();
      source.session!.finishUtterance();
      race.cancel();
      final count = statuses.length;
      scribe.answer('thé');
      await _pump();
      expect((await future).matched, isFalse);
      expect(statuses.length, count, reason: 'no status after cancel');
    });
  });
}
