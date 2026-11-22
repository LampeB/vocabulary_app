import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/services/quiz_orchestration/voice_turn_machine.dart';

/// VoiceTurnMachine (refactor step 3): every phase transition, and each field
/// incident from the on-device logs pinned as a named regression test.

void main() {
  // A controllable clock so pacing decisions are deterministic.
  var now = DateTime(2026, 7, 22, 12, 0, 0);
  DateTime clock() => now;
  void tick(Duration d) => now = now.add(d);

  VoiceTurnMachine machine({int maxAttempts = 3, int silentBeforePause = 2}) =>
      VoiceTurnMachine(
        clock: clock,
        maxListenAttempts: maxAttempts,
        silentCardsBeforePause: silentBeforePause,
      );

  setUp(() => now = DateTime(2026, 7, 22, 12, 0, 0));

  /// Drives a fresh turn to the listening phase.
  void toListening(VoiceTurnMachine m, int turn) {
    expect(m.on(TurnStarted(turn)), [isA<CleanSlate>()]);
    expect(m.on(SlateClean(turn)), [isA<PlayPrompt>()]);
    expect(m.on(PromptFinished(turn)), [isA<PlayCue>()]);
    expect(m.on(CueFinished(turn)), [isA<OpenMic>()]);
    expect(m.on(MicOpened(turn)), isEmpty);
    expect(m.phase, TurnPhase.listening);
  }

  group('happy path', () {
    test('transition → prompt → cue → mic → match → grade correct', () {
      final m = machine();
      toListening(m, 1);
      final out = m.on(const MatchHeard(1, 'thé'));
      expect(out, [isA<GradeCorrect>()]);
      expect((out.single as GradeCorrect).candidate, 'thé');
      expect(m.phase, TurnPhase.graded);
    });

    test('a real wrong answer grades wrong (not skipped)', () {
      final m = machine();
      toListening(m, 1);
      expect(m.on(const WrongHeard(1, 'bonjour')), [isA<GradeWrong>()]);
      expect(m.phase, TurnPhase.graded);
    });
  });

  group('grade exactly once (90→100→110% score, field 2026-07-19)', () {
    test('any event after a verdict is ignored — including more matches', () {
      final m = machine();
      toListening(m, 1);
      m.on(const MatchHeard(1, 'thé'));
      // The late Samsung final result + a lane-2 transcript arrive after.
      expect(m.on(const MatchHeard(1, 'thé')), isEmpty);
      expect(m.on(const WrongHeard(1, 'noise')), isEmpty);
      expect(m.on(const NothingHeard(1, hadRealWindow: true)), isEmpty);
      expect(m.phase, TurnPhase.graded);
    });
  });

  group('stale events (previous card\'s echo, field 2026-07-06)', () {
    test('events carrying an old turn id are rejected wholesale', () {
      final m = machine();
      toListening(m, 1);
      m.on(const MatchHeard(1, 'thé')); // turn 1 done
      m.on(const TurnStarted(2));
      m.on(const SlateClean(2));
      // Turn 1's late callbacks must not touch turn 2.
      expect(m.on(const WrongHeard(1, 'stale')), isEmpty);
      expect(m.on(const NothingHeard(1, hadRealWindow: false)), isEmpty);
      expect(m.phase, TurnPhase.prompting);
    });

    test('turn ids must be monotonic — a replayed TurnStarted is ignored', () {
      final m = machine();
      toListening(m, 5);
      expect(m.on(const TurnStarted(5)), isEmpty);
      expect(m.on(const TurnStarted(3)), isEmpty);
      expect(m.phase, TurnPhase.listening);
    });
  });

  group('not-heard ladder (3 attempts, rescue engine last)', () {
    test('silence retries with the prompt, and the LAST attempt uses the '
        'rescue engine', () {
      final m = machine();
      toListening(m, 1); // attempt 1
      var out = m.on(const NothingHeard(1, hadRealWindow: true));
      expect(out, [isA<ShowNotHeard>(), isA<WaitThenRetry>()]);
      expect((out.first as ShowNotHeard).attempt, 1);

      tick(const Duration(seconds: 4)); // pacing satisfied
      out = m.on(const WaitElapsed(1)); // attempt 2 opens
      expect(out, [isA<OpenMic>()]);
      expect((out.single as OpenMic).useRescueEngine, isFalse);
      m.on(const MicOpened(1));

      out = m.on(const NothingHeard(1, hadRealWindow: true));
      expect(out, [isA<ShowNotHeard>(), isA<WaitThenRetry>()]);
      tick(const Duration(seconds: 4));
      out = m.on(const WaitElapsed(1)); // attempt 3 = rescue
      expect((out.single as OpenMic).useRescueEngine, isTrue);
    });

    test('silence NEVER grades wrong — ladder exhausted skips without '
        'grading (user feedback 2026-07-06)', () {
      final m = machine();
      toListening(m, 1);
      for (var i = 0; i < 2; i++) {
        m.on(const NothingHeard(1, hadRealWindow: true));
        tick(const Duration(seconds: 4));
        m.on(const WaitElapsed(1));
        m.on(const MicOpened(1));
      }
      final out = m.on(const NothingHeard(1, hadRealWindow: true));
      expect(out, [isA<SkipCard>()]);
      expect(m.phase, TurnPhase.skipped);
    });
  });

  group('retry pacing guard (earcon machine-gun, field 2026-07-19)', () {
    test('a retry within the pacing window waits the remainder first', () {
      final m = machine();
      toListening(m, 1);
      m.on(const NothingHeard(1, hadRealWindow: true));
      // Ladder beat elapses fast — only ~0.9s since the mic opened.
      tick(const Duration(milliseconds: 900));
      final out = m.on(const WaitElapsed(1));
      expect(out, [isA<WaitThenRetry>()],
          reason: 'must NOT reopen the mic 0.9s after the last open');
      final wait = (out.single as WaitThenRetry).duration;
      expect(wait.inMilliseconds, closeTo(2600, 50)); // 3.5s − 0.9s
      // After the wait the mic opens normally.
      tick(wait);
      expect(m.on(const WaitElapsed(1)), [isA<OpenMic>()]);
    });

    test('the FIRST attempt of a card is never delayed', () {
      final m = machine();
      toListening(m, 1);
      m.on(const MatchHeard(1, 'ok'));
      // Next card starts immediately after — attempt 0, no pacing.
      m.on(const TurnStarted(2));
      m.on(const SlateClean(2));
      m.on(const PromptFinished(2));
      expect(m.on(const CueFinished(2)), [isA<OpenMic>()]);
    });
  });

  group('throttle storm (dead 15ms sessions, field 2026-07-19/21)', () {
    test('instant engine deaths retry via the ladder without ever grading',
        () {
      final m = machine();
      toListening(m, 1);
      // The mic "opens" then the engine dies instantly, repeatedly:
      // hadRealWindow=false — these must never mark the card wrong.
      var out = m.on(const NothingHeard(1, hadRealWindow: false));
      expect(out.whereType<GradeWrong>(), isEmpty);
      expect(out, [isA<ShowNotHeard>(), isA<WaitThenRetry>()]);
    });

    test('MicFailed is handled like a not-real-window silence', () {
      final m = machine();
      m.on(const TurnStarted(1));
      m.on(const SlateClean(1));
      m.on(const PromptFinished(1));
      m.on(const CueFinished(1));
      final out = m.on(const MicFailed(1));
      expect(out, [isA<ShowNotHeard>(), isA<WaitThenRetry>()]);
    });
  });

  group('fake analyse phase (field 2026-07-19)', () {
    test('analyse shows ONLY from live listening with a verdict pending', () {
      final m = machine();
      toListening(m, 1);
      expect(m.micClosedPendingVerdict(1), [isA<ShowAnalyzing>()]);
      expect(m.phase, TurnPhase.analyzing);
      // A late verdict still lands.
      expect(m.on(const MatchHeard(1, 'thé')), [isA<GradeCorrect>()]);
    });

    test('silence goes to the ladder, never through analyse', () {
      final m = machine();
      toListening(m, 1);
      final out = m.on(const NothingHeard(1, hadRealWindow: true));
      expect(out.whereType<ShowAnalyzing>(), isEmpty);
    });

    test('micClosedPendingVerdict outside listening is a no-op', () {
      final m = machine();
      m.on(const TurnStarted(1));
      expect(m.micClosedPendingVerdict(1), isEmpty);
    });
  });

  group('consecutive-silence auto-pause (environment failure)', () {
    test('two silent-skipped cards in a row pause the session; real speech '
        'resets the streak', () {
      final m = machine();

      List<TurnCommand> exhaust(int turn) {
        toListening(m, turn);
        for (var i = 0; i < 2; i++) {
          m.on(NothingHeard(turn, hadRealWindow: true));
          tick(const Duration(seconds: 4));
          m.on(WaitElapsed(turn));
          m.on(MicOpened(turn));
        }
        return m.on(NothingHeard(turn, hadRealWindow: true));
      }

      expect(exhaust(1), [isA<SkipCard>()]); // silent card #1
      expect(exhaust(2), [isA<PauseSession>()]); // silent card #2 → pause
      expect(m.phase, TurnPhase.paused);
    });

    test('a heard answer between silent cards resets the streak', () {
      final m = machine();

      List<TurnCommand> exhaust(int turn) {
        toListening(m, turn);
        for (var i = 0; i < 2; i++) {
          m.on(NothingHeard(turn, hadRealWindow: true));
          tick(const Duration(seconds: 4));
          m.on(WaitElapsed(turn));
          m.on(MicOpened(turn));
        }
        return m.on(NothingHeard(turn, hadRealWindow: true));
      }

      expect(exhaust(1), [isA<SkipCard>()]);
      toListening(m, 2);
      m.on(const MatchHeard(2, 'ok')); // resets the streak
      expect(exhaust(3), [isA<SkipCard>()],
          reason: 'streak reset — this is silent card #1 again, not #2');
    });
  });

  group('manual resume', () {
    test('resetSilenceStreak restarts the pause countdown', () {
      final m = machine();
      List<TurnCommand> exhaust(int turn) {
        toListening(m, turn);
        for (var i = 0; i < 2; i++) {
          m.on(NothingHeard(turn, hadRealWindow: true));
          tick(const Duration(seconds: 4));
          m.on(WaitElapsed(turn));
          m.on(MicOpened(turn));
        }
        return m.on(NothingHeard(turn, hadRealWindow: true));
      }

      expect(exhaust(1), [isA<SkipCard>()]); // silent #1
      m.resetSilenceStreak(); // user unpaused / resumed manually
      expect(exhaust(2), [isA<SkipCard>()],
          reason: 'streak reset — silent #1 again, not a pause');
    });
  });

  group('phase discipline', () {
    test('out-of-order events are no-ops', () {
      final m = machine();
      m.on(const TurnStarted(1));
      // Listening events before the mic ever opened:
      expect(m.on(const PromptFinished(1)), isEmpty);
      expect(m.on(const CueFinished(1)), isEmpty);
      expect(m.on(const WaitElapsed(1)), isEmpty);
      expect(m.phase, TurnPhase.transition);
    });
  });
}
