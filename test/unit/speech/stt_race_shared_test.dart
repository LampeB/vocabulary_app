import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/core/utils/pcm_segmenter.dart';
import 'package:vocab_kr/services/speech/elevenlabs_speech_service.dart';
import 'package:vocab_kr/services/speech/elevenlabs_stt_engine.dart';
import 'package:vocab_kr/services/speech/pcm_microphone.dart';
import 'package:vocab_kr/services/speech/phone_pcm_recognizer.dart';
import 'package:vocab_kr/services/speech/phone_stt_engine.dart';
import 'package:vocab_kr/services/speech/shared_pcm_capture.dart';
import 'package:vocab_kr/services/speech/stt_engine.dart';
import 'package:vocab_kr/services/speech/stt_race.dart';
import 'package:vocab_kr/services/speech/stt_race_status.dart';
import 'package:vocab_kr/services/speech/whisper_speech_service.dart';
import 'package:vocab_kr/services/speech/whisper_stt_engine.dart';

PcmSegment _seg([int ms = 800]) => PcmSegment(Uint8List(ms * 32), ms, 5000);

class _FakeSession implements PcmCaptureSession {
  _FakeSession(this._onSpeechChange, this._onSegment);
  final void Function(bool) _onSpeechChange;
  final void Function(PcmSegment) _onSegment;
  bool speaking = false;
  bool closed = false;
  bool flushed = false;
  Completer<PcmSegment?>? delayedClose;

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
    if (delayedClose != null) return delayedClose!.future;
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
    required void Function(Object) onInterruption,
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
  }) async => started = true;

  @override
  Future<SttHypothesis?> recognize(
    PcmSegment segment, {
    required String langCode,
    required List<String> promptHints,
  }) async {
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
            confidence: confidence,
          );
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

class _UnusedMicrophone extends Fake implements PcmMicrophone {}

class _HeldTranscriber implements CloudTranscriber {
  final firstRequest = Completer<String?>();
  int calls = 0;

  @override
  Future<String?> transcribe({
    required Uint8List pcm16,
    required String langCode,
    required String expectedWord,
  }) async {
    calls++;
    return calls == 1 ? firstRequest.future : expectedWord;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SttRace — shared capture (local before cloud)', () {
    test(
      'a record event channel error ends the race after native stop',
      () async {
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        const channel = MethodChannel('com.llfbandit.record/messages');
        MethodChannel? events;
        MethodChannel? states;
        final recordingOpened = Completer<void>();
        final stopRequested = Completer<void>();
        final release = Completer<void>();
        messenger.setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'create':
              final id = call.arguments['recorderId'] as String;
              events = MethodChannel('com.llfbandit.record/eventsRecord/$id');
              states = MethodChannel('com.llfbandit.record/events/$id');
              messenger.setMockMethodCallHandler(events!, (_) async => null);
              messenger.setMockMethodCallHandler(states!, (_) async => null);
            case 'hasPermission':
              return true;
            case 'stop':
              stopRequested.complete();
              await release.future;
          }
          return null;
        });
        final capture = SharedPcmCapture();
        addTearDown(() async {
          capture.dispose();
          await _pump();
          messenger.setMockMethodCallHandler(channel, null);
          if (events != null) messenger.setMockMethodCallHandler(events!, null);
          if (states != null) messenger.setMockMethodCallHandler(states!, null);
        });
        final decoder = _SharedEngine('whisper');
        var finished = false;
        final race = SttRace([decoder], capture: capture)
            .run(
              langCode: 'en',
              acceptedAnswers: ['cat'],
              onStatus: (status) {
                if (status.phase == SttPhase.listening) {
                  recordingOpened.complete();
                }
              },
            )
            .then((outcome) {
              finished = true;
              return outcome;
            });
        await recordingOpened.future.timeout(const Duration(seconds: 2));
        await messenger.handlePlatformMessage(
          events!.name,
          const StandardMethodCodec().encodeErrorEnvelope(
            code: 'record_failed',
          ),
          null,
        );
        await stopRequested.future.timeout(const Duration(seconds: 2));
        expect(finished, isFalse);

        release.complete();
        final outcome = await race;
        expect(outcome.captureInterrupted, isTrue);
        expect(outcome.micReleaseFailed, isFalse);
        expect(outcome.matched, isFalse);
        expect(outcome.hadRealSession, isFalse);
        expect(decoder.segments, isEmpty);
      },
    );

    test('English cap cannot win the shared race for cat', () async {
      final source = _FakeSource();
      final decoder = _SharedEngine('whisper');
      final result = SttRace([decoder], capture: source).run(
        langCode: 'en',
        acceptedAnswers: ['cat'],
        timeout: const Duration(milliseconds: 70),
      );
      await _pump();
      source.session!.finishUtterance();
      decoder.answer('cap');
      final outcome = await result;
      expect(outcome.matched, isFalse);
      expect(outcome.bestTranscript, 'cap');
    });

    test('a locally valid answer never uploads the capture to cloud', () async {
      final source = _FakeSource();
      final scribe = _SharedEngine('elevenlabs', requiresNetwork: true);
      final whisper = _SharedEngine('whisper');
      final future = SttRace([
        scribe,
        whisper,
      ], capture: source).run(langCode: 'ko', acceptedAnswers: ['가다']);
      await _pump();

      source.session!.startSpeaking();
      source.session!.finishUtterance();
      await _pump();
      expect(scribe.segments, isEmpty);
      expect(whisper.segments.length, 1);
      whisper.answer('가다');
      final outcome = await future;
      expect(outcome.matched, isTrue);
      expect(outcome.winnerEngineId, 'whisper');
      expect(source.session!.closed, isTrue);
      expect(source.opens, 1, reason: 'one mic for all engines');
      expect(scribe.segments, isEmpty);
    });

    test('cloud receives the same capture only after local failure', () async {
      final source = _FakeSource();
      final local = _SharedEngine('local');
      final cloud = _SharedEngine('cloud', requiresNetwork: true);
      final future = SttRace([cloud, local], capture: source).run(
        langCode: 'fr',
        acceptedAnswers: ['livre'],
        timeout: const Duration(milliseconds: 30),
      );
      await _pump();
      source.session!.finishUtterance();
      await _pump();
      expect(cloud.calls, isEmpty);
      local.answer(null);
      await _wait(70);
      expect(source.session!.closed, isTrue);
      expect(identical(local.segments.single, cloud.segments.single), isTrue);
      cloud.answer('livre');
      expect((await future).winnerEngineId, 'cloud');
    });

    test('cloud-only rescue serializes successive utterances', () async {
      final source = _FakeSource();
      final cloud = _SharedEngine('cloud', requiresNetwork: true);
      final future = SttRace([
        cloud,
      ], capture: source).run(langCode: 'fr', acceptedAnswers: ['livre']);
      await _pump();
      source.session!.finishUtterance();
      source.session!.finishUtterance();
      await _pump();
      expect(cloud.calls, hasLength(1));
      cloud.answer(null);
      await _pump();
      expect(cloud.calls, hasLength(2));
      cloud.answer('livre');
      expect((await future).matched, isTrue);
    });

    for (final hasLocalEngine in [false, true]) {
      test('a timed-out Scribe request abandons the rest of the cloud queue '
          '(local fallback: $hasLocalEngine)', () async {
        final source = _FakeSource();
        final http = _HeldTranscriber();
        final cloud = ElevenLabsSttEngine(
          ElevenLabsSpeechService(
            microphone: _UnusedMicrophone(),
            transcriber: http,
          ),
        );
        final otherCloud = _SharedEngine('other', requiresNetwork: true);
        final local = _SharedEngine('local');
        final verdict =
            SttRace([
              cloud,
              otherCloud,
              if (hasLocalEngine) local,
            ], capture: source).run(
              langCode: 'fr',
              acceptedAnswers: ['livre'],
              timeout: const Duration(milliseconds: 20),
              analysisTimeout: const Duration(milliseconds: 50),
            );
        await _pump();
        source.session!.finishUtterance();
        source.session!.finishUtterance();
        if (hasLocalEngine) {
          local.answer(null, call: 0);
          local.answer(null, call: 1);
        }
        expect((await verdict).matched, isFalse);
        expect(http.firstRequest.isCompleted, isFalse);
        expect(http.calls, 1);
        expect(otherCloud.calls, isEmpty);

        final next = SttRace(
          [cloud, otherCloud],
          capture: source,
        ).run(langCode: 'fr', acceptedAnswers: ['chat'], promptHints: ['chat']);
        await _pump();
        source.session!.finishUtterance();
        await _pump();
        expect(http.calls, 1, reason: 'the first HTTP request is still active');
        otherCloud.answer('chat');
        expect((await next).winnerEngineId, otherCloud.id);

        http.firstRequest.complete('livre');
        final recovered = SttRace(
          [cloud],
          capture: source,
        ).run(langCode: 'fr', acceptedAnswers: ['thé'], promptHints: ['thé']);
        await _pump();
        source.session!.finishUtterance();
        expect((await recovered).winnerEngineId, cloud.id);
        expect(http.calls, 2);
      });
    }

    test(
      'shared speech grading keeps the grammar article in the match',
      () async {
        final source = _FakeSource();
        final local = _SharedEngine('local');
        final verdict = SttRace([local], capture: source).run(
          langCode: 'fr',
          acceptedAnswers: ["l'eau"],
          preserveGrammar: true,
        );
        await _pump();
        source.session!.finishUtterance();
        local.answer('eau');
        await _pump();
        source.session!.finishUtterance();
        local.answer('L’eau.');
        expect((await verdict).matchedCandidate, 'L’eau.');
      },
    );

    test(
      'a completed prior miss cannot discard the delayed flushed tail',
      () async {
        final source = _FakeSource();
        final local = _SharedEngine('local');
        var resolved = false;
        final future = SttRace([local], capture: source).run(
          langCode: 'fr',
          acceptedAnswers: ['livre'],
          timeout: const Duration(milliseconds: 30),
          maxSpeechOverrun: const Duration(milliseconds: 20),
        )..then((_) => resolved = true);
        await _pump();
        source.session!.finishUtterance();
        final closing = Completer<PcmSegment?>();
        source.session!.delayedClose = closing;
        source.session!.startSpeaking();
        await _wait(80);
        local.answer('autre', call: 0);
        await _pump();
        expect(resolved, isFalse);
        closing.complete(_seg(1200));
        await _pump();
        expect(local.calls, hasLength(2));
        local.answer('livre', call: 1);
        expect((await future).matched, isTrue);
      },
    );

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
      },
    );

    test(
      'the window never cuts a learner mid-answer: it waits for the end',
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
      },
    );

    test(
      'speech running past the overrun is flushed and still analysed',
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
      },
    );

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
      final outcome = await SttRace([
        _SharedEngine('whisper'),
      ], capture: source).run(langCode: 'fr', acceptedAnswers: ['thé']);
      expect(outcome.matched, isFalse);
      expect(outcome.hadRealSession, isFalse);
    });

    test('a wrong answer keeps the mic open for a self-correction; at the end '
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
      final future = SttRace([
        scribe,
      ], capture: source).run(langCode: 'fr', acceptedAnswers: ['étudier']);
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
      final future = SttRace(
        [scribe, whisper],
        capture: source,
      ).run(langCode: 'fr', acceptedAnswers: ['thé'], onStatus: statuses.add);
      await _pump();
      source.session!.startSpeaking();
      source.session!.finishUtterance();
      scribe.fail();
      await _pump();
      expect(
        statuses.last.engines
            .firstWhere((e) => e.engineId == 'elevenlabs')
            .state,
        SttEngineState.failed,
      );
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

    test('status walks starting → listening → speaking → analyzing → done, '
        'with per-engine chips', () async {
      final source = _FakeSource();
      final scribe = _SharedEngine('elevenlabs', requiresNetwork: true);
      final statuses = <SttRaceStatus>[];
      final future = SttRace([scribe], capture: source).run(
        langCode: 'ko',
        acceptedAnswers: ['책'],
        timeout: const Duration(milliseconds: 25),
        onStatus: statuses.add,
      );
      await _pump();
      source.session!.startSpeaking();
      source.session!.finishUtterance();
      await _wait(60);
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
        ]),
      );
      final chip = statuses.last.engines.single;
      expect(chip.engineId, 'elevenlabs');
      expect(chip.requiresNetwork, isTrue);
      expect(chip.state, SttEngineState.heard);
      expect(chip.transcript, '책');
      expect(chip.matched, isTrue);
    });

    test(
      'engine work becomes analysis only after microphone closure completes',
      () async {
        final source = _FakeSource();
        final scribe = _SharedEngine('elevenlabs');
        var pending = 0;
        final statuses = <SttRaceStatus>[];
        final future = SttRace([scribe], capture: source).run(
          langCode: 'fr',
          acceptedAnswers: ['thé'],
          timeout: const Duration(milliseconds: 20),
          onMicClosedPending: () => pending++,
          onStatus: statuses.add,
        );
        await _pump();
        source.session!.startSpeaking();
        source.session!.finishUtterance();
        final closing = Completer<PcmSegment?>();
        source.session!.delayedClose = closing;
        await _wait(50);
        expect(scribe.calls, hasLength(1));
        expect(statuses.last.phase, SttPhase.listening);
        expect(statuses.last.engines.single.state, SttEngineState.working);
        expect(pending, 0);
        closing.complete(null);
        await _pump();
        expect(pending, 1);
        expect(statuses.last.phase, SttPhase.analyzing);
        scribe.answer('thé');
        expect((await future).matched, isTrue);
      },
    );
    for (final hangs in [false, true]) {
      test(
        'unconfirmed mic release ends the race once (hangs: $hangs)',
        () async {
          final source = _FakeSource();
          final engine = _SharedEngine('whisper');
          final phases = <SttPhase>[];
          var micClosed = 0;
          final result = SttRace([engine], capture: source).run(
            langCode: 'fr',
            acceptedAnswers: ['thé'],
            timeout: const Duration(milliseconds: 30),
            micReleaseTimeout: const Duration(milliseconds: 55),
            onMicClosedPending: () => micClosed++,
            onStatus: (status) => phases.add(status.phase),
          );
          await _pump();
          final closing = Completer<PcmSegment?>();
          source.session!.delayedClose = closing;
          source.session!.startSpeaking();
          source.session!.finishUtterance();
          await _pump();
          if (hangs) {
            engine.answer('thé');
          } else {
            await _wait(42);
            closing.completeError(StateError('mic still active'));
          }
          final outcome = await result.timeout(const Duration(seconds: 1));
          expect(outcome.micReleaseFailed, isTrue);
          expect(outcome.matched, isFalse);
          expect(micClosed, 0);
          expect(phases, isNot(contains(SttPhase.analyzing)));
          expect(phases.last, SttPhase.done);
          if (hangs) closing.complete(null);
        },
      );
    }
  });

  test(
    'phone partial returned after native end can only grade vocabulary',
    () async {
      const channel = MethodChannel('vocab_kr/pcm_speech');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => switch (call.method) {
          'isSupported' => true,
          // Retained partial after an empty native final bundle or an error.
          'recognize' => {
            'texts': ['사과가'],
            'isFinal': false,
          },
          _ => null,
        },
      );
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final phone = PhoneSttEngine(const MethodChannelPhonePcmRecognizer());
      await phone.prepare();
      for (final grammar in [true, false]) {
        final source = _FakeSource();
        final verdict = SttRace([phone], capture: source).run(
          langCode: 'ko',
          acceptedAnswers: ['사과가'],
          preserveGrammar: grammar,
          timeout: const Duration(milliseconds: 35),
        );
        await _pump();
        source.session!.finishUtterance();
        final outcome = await verdict;
        expect(outcome.hypotheses.single.isFinal, isFalse);
        expect(outcome.matched, !grammar);
        expect(outcome.bestTranscript, grammar ? isNull : '사과가');
      }
    },
  );

  group('SttRace.cancel — a superseded listen must not touch the next one', () {
    test(
      'Whisper skips cancelled queued PCM after the active inference',
      () async {
        final activeInference = Completer<String>();
        final calls = <int>[];
        final whisper = WhisperSttEngine(
          WhisperSpeechService(
            microphone: _UnusedMicrophone(),
            modelReady: true,
            segmentTranscriber:
                ({required pcm16, required langCode, required prompt}) async {
                  final ms = pcm16.length ~/ 32;
                  calls.add(ms);
                  return ms == 800 ? activeInference.future : 'bonjour';
                },
          ),
        );
        final source = _FakeSource();
        final firstRace = SttRace([whisper], capture: source);
        final first = firstRace.run(langCode: 'fr', acceptedAnswers: ['salut']);
        await _pump();
        source.session!.finishUtterance(800);
        source.session!.finishUtterance(900);
        source.session!.finishUtterance(1000);
        await _pump();
        expect(calls, [800]);

        firstRace.cancel();
        expect((await first).cancelled, isTrue);
        final nextRace = SttRace([whisper], capture: source);
        final next = nextRace.run(langCode: 'fr', acceptedAnswers: ['bonjour']);
        await _pump();
        source.session!.finishUtterance(1100);
        await _pump();
        expect(calls, [800], reason: 'native inference must stay serial');

        activeInference.complete('salut');
        expect((await next).matchedCandidate, 'bonjour');
        expect(calls, [800, 1100]);
      },
    );

    test(
      'pausing cancels phone PCM and a new race ignores blocked old work',
      () async {
        const channel = MethodChannel('vocab_kr/pcm_speech');
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        final oldDecode = Completer<Map<String, Object>>();
        final calls = <String>[];
        messenger.setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'isSupported':
              return true;
            case 'cancel':
              calls.add('cancel');
              return null;
            case 'recognize':
              final bytes = call.arguments['pcm'] as Uint8List;
              calls.add('recognize ${bytes.length ~/ 32}');
              if (bytes.length == 800 * 32) return oldDecode.future;
              return {
                'texts': ['livre'],
              };
            default:
              throw MissingPluginException(call.method);
          }
        });
        addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
        final phone = PhoneSttEngine(const MethodChannelPhonePcmRecognizer());
        await phone.prepare();
        final source = _FakeSource();
        final pausedRace = SttRace([phone], capture: source);
        final paused = pausedRace.run(
          langCode: 'fr',
          acceptedAnswers: ['livre'],
        );
        await _pump();
        source.session!.finishUtterance(800);
        source.session!.finishUtterance(900);
        await _pump();
        expect(calls, ['recognize 800']);

        pausedRace.cancel();
        expect((await paused).cancelled, isTrue);
        expect(calls, ['recognize 800', 'cancel']);
        final resumed = SttRace([
          phone,
        ], capture: source).run(langCode: 'fr', acceptedAnswers: ['livre']);
        await _pump();
        source.session!.finishUtterance(1000);
        expect((await resumed).matched, isTrue);
        expect(oldDecode.isCompleted, isFalse);
        oldDecode.complete({
          'texts': ['other'],
        });
        await _pump();
        expect(calls, ['recognize 800', 'cancel', 'recognize 1000', 'cancel']);
      },
    );

    test('cancel resolves the race, closes its own mic window, and never '
        'stops the shared engines (field 2026-10-02: the previous turn\'s '
        'timer cut the next turn 38ms after it opened)', () async {
      final source = _FakeSource();
      final scribe = _SharedEngine('elevenlabs');
      final race = SttRace([scribe], capture: source);
      final future = race.run(
        langCode: 'fr',
        acceptedAnswers: ['thé'],
        timeout: const Duration(milliseconds: 30),
      );
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
        langCode: 'fr',
        acceptedAnswers: ['thé'],
        onStatus: statuses.add,
      );
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
