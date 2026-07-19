import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/services/speech/stt_engine.dart';
import 'package:vocab_kr/services/speech/stt_engine_registry.dart';
import 'package:vocab_kr/services/speech/stt_race.dart';

/// A controllable engine: the test pushes hypotheses via [emit] and inspects
/// [started]/[stopped].
class _FakeEngine implements SttEngine {
  _FakeEngine(
    this.id, {
    this.capture = SttCapture.ownsMicrophone,
    this.isReady = true,
    this.languages = const {'fr'},
  });

  @override
  final String id;
  @override
  final SttCapture capture;
  @override
  bool isReady;
  final Set<String> languages;

  bool started = false;
  bool stopped = false;
  int prepareCalls = 0;
  void Function(SttHypothesis)? _sink;

  @override
  bool supportsLanguage(String langCode) => languages.contains(langCode);

  @override
  Future<void> prepare() async => prepareCalls++;

  @override
  Future<bool> start({
    required String langCode,
    required List<String> promptHints,
    required void Function(SttHypothesis) onHypothesis,
  }) async {
    started = true;
    _sink = onHypothesis;
    return true;
  }

  @override
  void feed(Uint8List pcm16) {}

  @override
  Future<void> stop() async => stopped = true;

  @override
  void dispose() {}

  void emit(String transcript,
          {List<String>? candidates,
          bool isFinal = true,
          double confidence = 0.9}) =>
      _sink?.call(SttHypothesis(
        engineId: id,
        transcript: transcript,
        candidates: candidates ?? [transcript],
        confidence: confidence,
        isFinal: isFinal,
      ));
}

/// Yields so the coordinator's start()/stop() microtasks run.
Future<void> _pump() => Future<void>.delayed(Duration.zero);

void main() {
  group('SttRace', () {
    test('first engine to emit a validating guess wins; losers are stopped',
        () async {
      final a = _FakeEngine('a');
      final b = _FakeEngine('b');
      final future =
          SttRace([a, b]).run(langCode: 'fr', acceptedAnswers: ['thé']);
      await _pump();

      expect(a.started, isTrue);
      expect(b.started, isTrue);

      a.emit('thé');
      final outcome = await future;
      await _pump();

      expect(outcome.matched, isTrue);
      expect(outcome.winnerEngineId, 'a');
      expect(outcome.matchedCandidate, 'thé');
      expect(a.stopped, isTrue);
      expect(b.stopped, isTrue, reason: 'the loser must be cancelled');
    });

    test('a non-validating guess does not end the race', () async {
      final a = _FakeEngine('a');
      final future = SttRace([a]).run(
        langCode: 'fr',
        acceptedAnswers: ['thé'],
        timeout: const Duration(milliseconds: 60),
      );
      await _pump();
      a.emit('bonjour'); // wrong — must not win

      final outcome = await future; // resolves via timeout
      expect(outcome.matched, isFalse);
      expect(outcome.bestTranscript, 'bonjour'); // shown as "we heard…"
    });

    test('a validating PARTIAL wins immediately', () async {
      final a = _FakeEngine('a');
      final partials = <SttHypothesis>[];
      final future = SttRace([a]).run(
        langCode: 'fr',
        acceptedAnswers: ['thé'],
        onPartial: partials.add,
      );
      await _pump();
      a.emit('thé', isFinal: false);

      final outcome = await future;
      expect(outcome.matched, isTrue);
      expect(partials.single.transcript, 'thé');
    });

    test('the fastest correct engine wins even if a slower one also would',
        () async {
      final fast = _FakeEngine('fast');
      final slow = _FakeEngine('slow');
      final future = SttRace([fast, slow])
          .run(langCode: 'fr', acceptedAnswers: ['thé']);
      await _pump();

      fast.emit('thé');
      slow.emit('thé'); // arrives after — ignored, race already won
      final outcome = await future;

      expect(outcome.winnerEngineId, 'fast');
    });

    test('an engine that does not support the language is never started',
        () async {
      final fr = _FakeEngine('fr', languages: {'fr'});
      final koOnly = _FakeEngine('ko', languages: {'ko'});
      final future = SttRace([fr, koOnly])
          .run(langCode: 'fr', acceptedAnswers: ['thé']);
      await _pump();

      expect(fr.started, isTrue);
      expect(koOnly.started, isFalse);
      fr.emit('thé');
      await future;
    });

    test('no ready engine → noEngines outcome', () async {
      final notReady = _FakeEngine('x', isReady: false);
      final outcome = await SttRace([notReady])
          .run(langCode: 'fr', acceptedAnswers: ['thé']);
      expect(outcome.matched, isFalse);
      expect(notReady.started, isFalse);
    });
  });

  group('SttEngineRegistry', () {
    test('racersFor prefers the shared-PCM pool over a mic owner', () {
      final reg = SttEngineRegistry()
        ..register(_FakeEngine('system'))
        ..register(_FakeEngine('sherpa', capture: SttCapture.sharedPcm))
        ..register(_FakeEngine('whisper2', capture: SttCapture.sharedPcm));

      final racers = reg.racersFor('fr').map((e) => e.id).toList();
      expect(racers, ['sherpa', 'whisper2']); // shared pool, not the mic owner
    });

    test('racersFor falls back to a single mic owner (never two)', () {
      final reg = SttEngineRegistry()
        ..register(_FakeEngine('system'))
        ..register(_FakeEngine('whisper'));

      final racers = reg.racersFor('fr');
      expect(racers.length, 1);
      expect(racers.single.id, 'system'); // registration order = priority
    });

    test('register/unregister add and remove racers', () {
      final reg = SttEngineRegistry()..register(_FakeEngine('system'));
      expect(reg.has('system'), isTrue);
      reg.register(_FakeEngine('sherpa', capture: SttCapture.sharedPcm));
      expect(reg.all.length, 2);
      reg.unregister('system');
      expect(reg.has('system'), isFalse);
      expect(reg.racersFor('fr').single.id, 'sherpa');
    });

    test('racersFor skips engines that do not support the language', () {
      final reg = SttEngineRegistry()
        ..register(_FakeEngine('fr-only', languages: {'fr'}))
        ..register(_FakeEngine('ko-only', languages: {'ko'}));
      expect(reg.racersFor('ko').single.id, 'ko-only');
      expect(reg.racersFor('it'), isEmpty);
    });
  });
}
