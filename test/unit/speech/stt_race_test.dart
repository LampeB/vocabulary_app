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
  int startCalls = 0;
  int prepareCalls = 0;
  void Function(SttHypothesis)? _sink;
  void Function()? _sessionEnd;

  @override
  bool supportsLanguage(String langCode) => languages.contains(langCode);

  @override
  Future<void> prepare() async => prepareCalls++;

  @override
  Future<bool> start({
    required String langCode,
    required List<String> promptHints,
    required void Function(SttHypothesis) onHypothesis,
    void Function()? onSessionEnd,
  }) async {
    started = true;
    startCalls++;
    _sink = onHypothesis;
    _sessionEnd = onSessionEnd;
    return true;
  }

  /// Simulates the platform recognizer closing its own session (one-utterance
  /// engines do this after a final result).
  void endSession() => _sessionEnd?.call();

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

/// A fake whose stop() takes real async time — for asserting the race awaits
/// shutdown before resolving.
class _SlowStopEngine extends _FakeEngine {
  _SlowStopEngine(super.id);
  bool stopCompleted = false;

  @override
  Future<void> stop() async {
    await Future<void>.delayed(const Duration(milliseconds: 60));
    stopCompleted = true;
    stopped = true;
  }
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

    test(
        'session-end restarts the engine so a wrong-then-corrected answer is '
        'heard (field bug 2026-07-19)', () async {
      final a = _FakeEngine('a');
      final future = SttRace([a]).run(
        langCode: 'fr',
        acceptedAnswers: ['manger'],
        timeout: const Duration(seconds: 5),
        minSessionForRestart: Duration.zero, // test: restart immediately
        restartDelay: Duration.zero,
      );
      await _pump();

      a.emit('cheval'); // wrong first try — race keeps going
      a.endSession(); // platform recognizer closes after the utterance
      await _pump();
      await _pump();

      expect(a.startCalls, 2, reason: 'engine must be restarted');
      a.emit('manger'); // the self-correction, heard by the restarted session
      final outcome = await future;
      expect(outcome.matched, isTrue);
      expect(outcome.matchedCandidate, 'manger');
    });

    test('restarts are capped (no infinite churn)', () async {
      final a = _FakeEngine('a');
      final future = SttRace([a]).run(
        langCode: 'fr',
        acceptedAnswers: ['manger'],
        timeout: const Duration(milliseconds: 400),
        minSessionForRestart: Duration.zero,
        restartDelay: Duration.zero,
      );
      await _pump();
      for (var i = 0; i < 6; i++) {
        a.endSession();
        await _pump();
        await _pump();
      }
      expect(a.startCalls, lessThanOrEqualTo(3)); // initial + max 2 restarts
      final outcome = await future;
      expect(outcome.matched, isFalse);
    });

    test('a too-short session (throttle ghost) is NOT restarted', () async {
      final a = _FakeEngine('a');
      final future = SttRace([a]).run(
        langCode: 'fr',
        acceptedAnswers: ['manger'],
        timeout: const Duration(milliseconds: 300),
        // default minSessionForRestart (1200ms) — an instant end is a ghost
      );
      await _pump();
      a.endSession(); // dies immediately (~0ms lived)
      await _pump();
      await _pump();
      expect(a.startCalls, 1, reason: 'ghost sessions must not be hammered');
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

  group('throttle-killed restart (dead-mic back half, 2026-07-21)', () {
    test(
        'a session that dies before minSessionForRestart gets ONE cooldown '
        'retry instead of burning the budget and leaving a dead mic',
        () async {
      final e = _FakeEngine('sys');
      final future = SttRace([e]).run(
        langCode: 'fr',
        acceptedAnswers: ['thé'],
        timeout: const Duration(seconds: 3),
        minSessionForRestart: const Duration(milliseconds: 100),
        restartDelay: const Duration(milliseconds: 10),
        throttleCooldown: const Duration(milliseconds: 30),
      );
      await _pump();
      expect(e.startCalls, 1);

      e.endSession(); // dies instantly → throttle-killed, not a real session
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(e.startCalls, 2,
          reason: 'one cooldown retry must re-open the mic');

      e.emit('thé'); // the retried session hears the answer
      final outcome = await future;
      expect(outcome.matched, isTrue);
    });

    test('the cooldown retry happens at most once per window', () async {
      final e = _FakeEngine('sys');
      final future = SttRace([e]).run(
        langCode: 'fr',
        acceptedAnswers: ['thé'],
        timeout: const Duration(milliseconds: 2500),
        minSessionForRestart: const Duration(milliseconds: 100),
        throttleCooldown: const Duration(milliseconds: 20),
      );
      await _pump();
      e.endSession(); // throttle kill #1 → retry
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(e.startCalls, 2);
      e.endSession(); // throttle kill #2 → give up this window
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(e.startCalls, 2, reason: 'no second cooldown retry');
      final outcome = await future; // resolves via timeout
      expect(outcome.matched, isFalse);
    });
  });

  group('deterministic engine shutdown (dead-mic clobber, 2026-07-21)', () {
    test('engines are FULLY stopped before the run future completes', () async {
      // A stop that lingers (async work) must still finish before run()
      // resolves — an unawaited stop used to execute after the caller had
      // already started the next race, stripping its session-end handler.
      final slow = _SlowStopEngine('slow');
      final future = SttRace([slow]).run(
        langCode: 'fr',
        acceptedAnswers: ['thé'],
        timeout: const Duration(milliseconds: 50),
      );
      await _pump();
      final outcome = await future;
      // No pump: the guarantee is stop() completed BEFORE run() resolved.
      expect(outcome.matched, isFalse);
      expect(slow.stopCompleted, isTrue,
          reason: 'run() must not resolve while a stop is still in flight');
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
