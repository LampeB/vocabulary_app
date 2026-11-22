import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/presentation/screens/quiz/hf_cue.dart';
import 'package:vocab_kr/services/speech/stt_race_status.dart';

HfCue _cue({
  bool paused = false,
  int? countdown,
  bool micRequested = true,
  SttPhase? phase,
  bool verdictPending = false,
  bool notHeard = false,
}) =>
    hfCueFor(
      paused: paused,
      countdown: countdown,
      micRequested: micRequested,
      phase: phase,
      verdictPending: verdictPending,
      notHeard: notHeard,
    );

void main() {
  test(
      'the nominal sequence: reading → countdown → opening → listening → '
      'hearing → analysing', () {
    expect(_cue(micRequested: false), HfCue.reading);
    expect(_cue(micRequested: false, countdown: 3), HfCue.countdown);
    expect(_cue(phase: SttPhase.starting), HfCue.opening);
    expect(_cue(phase: null), HfCue.opening);
    expect(_cue(phase: SttPhase.listening), HfCue.listening);
    expect(_cue(phase: SttPhase.speaking), HfCue.hearing);
    expect(_cue(phase: SttPhase.analyzing), HfCue.analyzing);
  });

  test('pause hides everything', () {
    expect(
        _cue(paused: true, countdown: 2, phase: SttPhase.speaking), HfCue.none);
  });

  test('a pending verdict (mic closed) reads as analysing', () {
    expect(_cue(phase: SttPhase.done, verdictPending: true), HfCue.analyzing);
  });

  test('after a not-heard, the retry prompt stays until voice is detected', () {
    expect(_cue(notHeard: true, phase: SttPhase.listening), HfCue.notHeard);
    expect(_cue(notHeard: true, phase: SttPhase.speaking), HfCue.hearing);
    expect(_cue(notHeard: true, phase: SttPhase.analyzing), HfCue.analyzing);
  });

  test('a stale race phase is ignored once the mic is no longer requested', () {
    expect(_cue(micRequested: false, phase: SttPhase.speaking), HfCue.reading);
  });

  test('the time-left bar shows only while the mic is genuinely open', () {
    bool bar({
      bool paused = false,
      int? countdown,
      bool micRequested = true,
      SttPhase? phase,
      bool verdictPending = false,
    }) =>
        hfBarVisible(
          paused: paused,
          countdown: countdown,
          micRequested: micRequested,
          phase: phase,
          verdictPending: verdictPending,
        );
    expect(bar(phase: SttPhase.listening), isTrue);
    expect(bar(phase: SttPhase.speaking), isTrue);
    expect(bar(phase: SttPhase.starting), isFalse);
    expect(bar(phase: SttPhase.analyzing), isFalse);
    expect(bar(phase: SttPhase.listening, verdictPending: true), isFalse);
    expect(bar(phase: SttPhase.listening, countdown: 1), isFalse);
    expect(bar(phase: SttPhase.listening, paused: true), isFalse);
    expect(bar(phase: SttPhase.listening, micRequested: false), isFalse);
  });
}
