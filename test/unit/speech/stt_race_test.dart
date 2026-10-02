import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/core/utils/pcm_segmenter.dart';
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
    this.requiresNetwork = false,
  });

  @override
  final String id;
  @override
  final SttCapture capture;
  @override
  bool isReady;
  final Set<String> languages;
  @override
  final bool requiresNetwork;

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
  Future<SttHypothesis?> recognize(
    PcmSegment segment, {
    required String langCode,
    required List<String> promptHints,
  }) async =>
      null;

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
        lateResultGrace: const Duration(milliseconds: 40),
      );
      await _pump();
      a.emit('bonjour'); // wrong — must not win

      final outcome = await future; // resolves via timeout (+grace)
      expect(outcome.matched, isFalse);
      expect(outcome.bestTranscript, 'bonjour'); // shown as "we heard…"
    });

    test(
        'late-result grace: a correction arriving after the window still '
        'wins (field 2026-07-22: "étudiant" → "étudier")', () async {
      final a = _FakeEngine('a');
      final future = SttRace([a]).run(
        langCode: 'fr',
        acceptedAnswers: ['étudier'],
        timeout: const Duration(milliseconds: 80),
        lateResultGrace: const Duration(milliseconds: 300),
      );
      await _pump();
      a.emit('étudiant'); // wrong → verdict held at timeout
      await Future<void>.delayed(const Duration(milliseconds: 150));
      a.emit('étudier'); // the late correction — inside the grace
      final outcome = await future;
      expect(outcome.matched, isTrue);
      expect(outcome.matchedCandidate, 'étudier');
    });

    test('pure silence gets NO grace — the window resolves promptly', () async {
      final a = _FakeEngine('a');
      final sw = Stopwatch()..start();
      final outcome = await SttRace([a]).run(
        langCode: 'fr',
        acceptedAnswers: ['thé'],
        timeout: const Duration(milliseconds: 80),
        lateResultGrace: const Duration(seconds: 5),
      );
      expect(outcome.matched, isFalse);
      expect(sw.elapsedMilliseconds, lessThan(1500),
          reason: 'no hypotheses → no correction pending → no grace');
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
      final future =
          SttRace([fast, slow]).run(langCode: 'fr', acceptedAnswers: ['thé']);
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
      final future =
          SttRace([fr, koOnly]).run(langCode: 'fr', acceptedAnswers: ['thé']);
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

    test('hybrid handoff ends the system lane instead of restarting its mic',
        () async {
      final system = _FakeEngine('system');
      final future = SttRace([system]).run(
        langCode: 'fr',
        acceptedAnswers: ['manger'],
        restartOnSessionEnd: false,
      );
      await _pump();

      system.emit('cheval');
      system.endSession();
      final outcome = await future;

      expect(outcome.matched, isFalse);
      expect(outcome.bestTranscript, 'cheval');
      expect(system.startCalls, 1,
          reason: 'the following offline lane must own the next capture');
      expect(system.stopped, isTrue);
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
        'retry instead of burning the budget and leaving a dead mic', () async {
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

  group('SttRace.cancel — mic-owner path', () {
    test('cancel resolves without stopping the engine; its timer never fires',
        () async {
      final a = _FakeEngine('system');
      final race = SttRace([a]);
      final future = race.run(
        langCode: 'fr',
        acceptedAnswers: ['thé'],
        timeout: const Duration(milliseconds: 30),
      );
      await _pump();
      race.cancel();
      final outcome = await future;
      expect(outcome.cancelled, isTrue);
      expect(a.stopped, isFalse,
          reason: 'the engine now belongs to the superseding race');
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(a.stopped, isFalse, reason: 'the stale timer must not stop it');
    });
  });

  group('SttEngineRegistry.select — best available engines (2026-10-02)', () {
    // Registration order = quality rank: cloud Scribe, then the platform
    // recognizer, then on-device Whisper — the app's real registration.
    SttEngineRegistry appRegistry({bool whisperReady = true}) =>
        SttEngineRegistry()
          ..register(_FakeEngine('elevenlabs',
              capture: SttCapture.sharedPcm, requiresNetwork: true))
          ..register(_FakeEngine('system'))
          ..register(_FakeEngine('whisper',
              capture: SttCapture.sharedPcm, isReady: whisperReady));

    List<String> ids(List<SttEngine> engines) =>
        engines.map((e) => e.id).toList();

    test(
        'online: the best engine is shared, so every shared engine joins it '
        'in parallel (a mic owner cannot share the mic)', () {
      expect(ids(appRegistry().select(langCode: 'fr', online: true)),
          ['elevenlabs', 'whisper']);
    });

    test('offline: cloud engines are never selected', () {
      expect(
          ids(appRegistry().select(langCode: 'fr', online: false)), ['system']);
    });

    test('online but Whisper still downloading: Scribe alone', () {
      expect(
          ids(appRegistry(whisperReady: false)
              .select(langCode: 'fr', online: true)),
          ['elevenlabs']);
    });

    test(
        'the app order with the phone bridge: online, three engines hear the '
        'same recording; offline, the live phone recognizer alone', () {
      final reg = SttEngineRegistry()
        ..register(_FakeEngine('elevenlabs',
            capture: SttCapture.sharedPcm, requiresNetwork: true))
        ..register(_FakeEngine('phone',
            capture: SttCapture.sharedPcm, requiresNetwork: true))
        ..register(_FakeEngine('system'))
        ..register(_FakeEngine('whisper', capture: SttCapture.sharedPcm));
      expect(ids(reg.select(langCode: 'fr', online: true)),
          ['elevenlabs', 'phone', 'whisper']);
      expect(ids(reg.select(langCode: 'fr', online: false)), ['system']);
      expect(ids(reg.select(langCode: 'fr', online: true, rescue: true)),
          ['phone', 'whisper']);
    });

    test('at most maxEngines shared engines run, best first', () {
      final reg = SttEngineRegistry()
        ..register(_FakeEngine('a', capture: SttCapture.sharedPcm))
        ..register(_FakeEngine('b', capture: SttCapture.sharedPcm))
        ..register(_FakeEngine('c', capture: SttCapture.sharedPcm))
        ..register(_FakeEngine('d', capture: SttCapture.sharedPcm));
      expect(ids(reg.select(langCode: 'fr', online: true)), ['a', 'b', 'c']);
      expect(ids(reg.select(langCode: 'fr', online: true, maxEngines: 2)),
          ['a', 'b']);
    });

    test('a best-ranked mic owner runs alone (never two mic owners)', () {
      final reg = SttEngineRegistry()
        ..register(_FakeEngine('system'))
        ..register(_FakeEngine('other'))
        ..register(_FakeEngine('whisper', capture: SttCapture.sharedPcm));
      expect(ids(reg.select(langCode: 'fr', online: true)), ['system']);
    });

    test('rescue attempt skips the first choice for the next best set', () {
      expect(
          ids(appRegistry().select(langCode: 'fr', online: true, rescue: true)),
          ['system']);
      expect(
          ids(appRegistry()
              .select(langCode: 'fr', online: false, rescue: true)),
          ['whisper']);
    });

    test('rescue with a single candidate keeps it', () {
      final reg = SttEngineRegistry()..register(_FakeEngine('system'));
      expect(ids(reg.select(langCode: 'fr', online: false, rescue: true)),
          ['system']);
    });

    test('skips engines that do not support the language', () {
      final reg = SttEngineRegistry()
        ..register(_FakeEngine('fr-only', languages: {'fr'}))
        ..register(_FakeEngine('ko-only', languages: {'ko'}));
      expect(ids(reg.select(langCode: 'ko', online: true)), ['ko-only']);
      expect(reg.select(langCode: 'it', online: true), isEmpty);
    });

    test('register/unregister add and remove engines', () {
      final reg = SttEngineRegistry()..register(_FakeEngine('system'));
      expect(reg.has('system'), isTrue);
      reg.register(_FakeEngine('sherpa', capture: SttCapture.sharedPcm));
      expect(reg.all.length, 2);
      reg.unregister('system');
      expect(reg.has('system'), isFalse);
      expect(ids(reg.select(langCode: 'fr', online: true)), ['sherpa']);
    });
  });
}
