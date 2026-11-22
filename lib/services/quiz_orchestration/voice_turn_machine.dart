/// Step 3 of the voice-orchestration refactor
/// (docs/refactor-voice-orchestration.md): the explicit state machine for one
/// hands-free/voice quiz turn. Everything that used to live in scattered
/// tokens, boolean banners, retry counters and `Future.delayed` closures is a
/// named phase + a pure transition function here.
///
/// The machine is deliberately free of timers, audio, engines and widgets:
/// the HOST (quiz screen / turn controller) executes the emitted
/// [TurnCommand]s — speak, cue, open the mic, run a wait — and reports what
/// happened back as [TurnEvent]s. Every event carries the [turn] id it
/// belongs to; stale events (a previous card's late callbacks — the source
/// of several field bugs) are rejected wholesale.
///
/// Scoring is NOT here either: the host validates transcripts (AnswerValidator
/// / SttRace) and reports `matchHeard` / `wrongHeard` / `nothingHeard`.
/// The machine owns POLICY:
///  * the not-heard ladder — 3 attempts, the 3rd on the rescue engine, then
///    skip WITHOUT grading (silence is never a wrong answer, 2026-07-06);
///  * consecutive-silent-card escalation — 2 in a row auto-pauses the
///    session (the room can't support hands-free right now);
///  * the retry pacing guard — a retry never reopens the mic within
///    [retryPacing] of the previous open (earcon machine-gun, 2026-07-19);
///  * grade-exactly-once — anything after a verdict is ignored (the
///    90→100→110% bug, 2026-07-19);
///  * analyse only after a REAL listen — an instant engine error must not
///    show a fake "analyse" phase (2026-07-19).
library;

/// Phases of one turn, in nominal order.
enum TurnPhase {
  /// No turn in progress.
  idle,

  /// Clean slate + audio hand-off is running (previous card's residue).
  transition,

  /// The question TTS chain is playing.
  prompting,

  /// "Your turn" earcon + clearance beat.
  cueing,

  /// Mic open — the host is listening/racing.
  listening,

  /// Mic closed, a verdict may still arrive (late results / lane 2).
  analyzing,

  /// Waiting out a commanded pause before re-listening (ladder/pacing).
  waitingRetry,

  /// Terminal: the card was graded (correct or wrong).
  graded,

  /// Terminal: skipped without grading (nothing usable was heard).
  skipped,

  /// Terminal: session auto-paused (environment can't support hands-free).
  paused,
}

// ─── Events (host → machine) ─────────────────────────────────────────────────

sealed class TurnEvent {
  const TurnEvent(this.turn);

  /// The turn this event belongs to; events for another turn are stale.
  final int turn;
}

/// Begin a new turn. [turn] must be a NEW id (monotonic).
class TurnStarted extends TurnEvent {
  const TurnStarted(super.turn, {this.isRetryOfSameCard = false});
  final bool isRetryOfSameCard;
}

/// The transition/hand-off finished; prompting may begin.
class SlateClean extends TurnEvent {
  const SlateClean(super.turn);
}

/// The question TTS chain finished.
class PromptFinished extends TurnEvent {
  const PromptFinished(super.turn);
}

/// The earcon + clearance finished.
class CueFinished extends TurnEvent {
  const CueFinished(super.turn);
}

/// The mic opened successfully.
class MicOpened extends TurnEvent {
  const MicOpened(super.turn);
}

/// The mic could not be opened (permission, engine failure).
class MicFailed extends TurnEvent {
  const MicFailed(super.turn);
}

/// A validated CORRECT candidate was heard.
class MatchHeard extends TurnEvent {
  const MatchHeard(super.turn, this.candidate);
  final String candidate;
}

/// Real speech was heard but nothing validated (a genuine wrong answer).
class WrongHeard extends TurnEvent {
  const WrongHeard(super.turn, this.transcript);
  final String transcript;
}

/// The listen window ended with no usable speech at all.
/// [hadRealWindow]: the mic was genuinely live (≥ ~1.5s) at least once this
/// attempt — instant engine deaths (throttle storms) don't count.
class NothingHeard extends TurnEvent {
  const NothingHeard(super.turn, {required this.hadRealWindow});
  final bool hadRealWindow;
}

/// A commanded [WaitThenRetry] elapsed.
class WaitElapsed extends TurnEvent {
  const WaitElapsed(super.turn);
}

// ─── Commands (machine → host) ───────────────────────────────────────────────

sealed class TurnCommand {
  const TurnCommand();
}

/// Reset UI (bar, banners), invalidate old sessions, hand audio to a clean
/// state. Host replies [SlateClean].
class CleanSlate extends TurnCommand {
  const CleanSlate();
}

/// Speak the question (and wait out the chain). Host replies [PromptFinished].
class PlayPrompt extends TurnCommand {
  const PlayPrompt();
}

/// Play the "your turn" earcon + clearance. Host replies [CueFinished].
class PlayCue extends TurnCommand {
  const PlayCue();
}

/// Open the mic / start the race. Host replies [MicOpened]/[MicFailed], then
/// eventually [MatchHeard]/[WrongHeard]/[NothingHeard].
/// [useRescueEngine]: 3rd not-heard attempt runs the alternate engine.
class OpenMic extends TurnCommand {
  const OpenMic({required this.useRescueEngine});
  final bool useRescueEngine;
}

/// Show the "analyse…" state (mic closed, verdict pending).
class ShowAnalyzing extends TurnCommand {
  const ShowAnalyzing();
}

/// Show the "pas entendu — essai n/3" prompt.
class ShowNotHeard extends TurnCommand {
  const ShowNotHeard(this.attempt, this.maxAttempts);
  final int attempt;
  final int maxAttempts;
}

/// Wait [duration], then reply [WaitElapsed]. Ladder beats + pacing guard.
class WaitThenRetry extends TurnCommand {
  const WaitThenRetry(this.duration);
  final Duration duration;
}

/// Grade the card correct with [candidate]. Terminal.
class GradeCorrect extends TurnCommand {
  const GradeCorrect(this.candidate);
  final String candidate;
}

/// Grade the card wrong with what was heard. Terminal.
class GradeWrong extends TurnCommand {
  const GradeWrong(this.transcript);
  final String transcript;
}

/// Skip without grading — silence is never a wrong answer. Terminal.
class SkipCard extends TurnCommand {
  const SkipCard();
}

/// Auto-pause the whole session (environment failure). Terminal.
class PauseSession extends TurnCommand {
  const PauseSession();
}

// ─── The machine ─────────────────────────────────────────────────────────────

class VoiceTurnMachine {
  VoiceTurnMachine({
    DateTime Function()? clock,
    this.maxListenAttempts = 3,
    this.silentCardsBeforePause = 2,
    this.retryPacing = const Duration(milliseconds: 3500),
    this.ladderBeat = const Duration(milliseconds: 900),
  }) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  /// Total listen attempts per card (initial + retries); the last one uses
  /// the rescue engine.
  final int maxListenAttempts;

  /// Consecutive skipped-silent cards that trigger an auto-pause.
  final int silentCardsBeforePause;

  /// Minimum gap between mic opens across retries (earcon machine-gun guard).
  final Duration retryPacing;

  /// The breather between a not-heard prompt and the next attempt.
  final Duration ladderBeat;

  TurnPhase _phase = TurnPhase.idle;
  int _turn = -1;
  int _attempt = 0;
  int _consecutiveSilentCards = 0;
  DateTime? _lastMicOpen;

  TurnPhase get phase => _phase;
  int get turn => _turn;
  int get attempt => _attempt;
  int get consecutiveSilentCards => _consecutiveSilentCards;

  bool get _terminal =>
      _phase == TurnPhase.graded ||
      _phase == TurnPhase.skipped ||
      _phase == TurnPhase.paused;

  /// Feed one event; returns the commands the host must execute.
  /// Unknown-turn events and anything after a terminal phase return `[]`.
  List<TurnCommand> on(TurnEvent event) {
    if (event is TurnStarted) {
      if (event.turn <= _turn) return const []; // ids must be monotonic
      _turn = event.turn;
      _attempt = event.isRetryOfSameCard ? _attempt : 0;
      _phase = TurnPhase.transition;
      return const [CleanSlate()];
    }

    if (event.turn != _turn) return const []; // stale — a previous turn's echo
    if (_terminal) return const []; // grade exactly once

    switch (event) {
      case SlateClean():
        if (_phase != TurnPhase.transition) return const [];
        _phase = TurnPhase.prompting;
        return const [PlayPrompt()];

      case PromptFinished():
        if (_phase != TurnPhase.prompting) return const [];
        _phase = TurnPhase.cueing;
        return const [PlayCue()];

      case CueFinished():
        if (_phase != TurnPhase.cueing) return const [];
        return _openMicPaced();

      case MicOpened():
        _phase = TurnPhase.listening;
        _lastMicOpen = _clock();
        return const [];

      case MicFailed():
        // Engine unavailable: treated like a not-real-window silence — the
        // ladder decides (retry on the rescue engine or skip).
        return _handleSilence(hadRealWindow: false);

      case MatchHeard(:final candidate):
        _phase = TurnPhase.graded;
        _consecutiveSilentCards = 0; // real speech reached us
        return [GradeCorrect(candidate)];

      case WrongHeard(:final transcript):
        _phase = TurnPhase.graded;
        _consecutiveSilentCards = 0; // real speech reached us
        return [GradeWrong(transcript)];

      case NothingHeard(:final hadRealWindow):
        return _handleSilence(hadRealWindow: hadRealWindow);

      case WaitElapsed():
        if (_phase != TurnPhase.waitingRetry) return const [];
        return _openMicPaced();

      case TurnStarted():
        return const []; // unreachable — handled above
    }
  }

  /// Opens the mic, inserting a pacing wait when the last open is too recent
  /// (retries only — attempt 0 is never delayed).
  List<TurnCommand> _openMicPaced() {
    if (_attempt > 0 && _lastMicOpen != null) {
      final sinceLast = _clock().difference(_lastMicOpen!);
      if (sinceLast < retryPacing) {
        _phase = TurnPhase.waitingRetry;
        // Re-check on elapse; by then the gap is satisfied.
        return [WaitThenRetry(retryPacing - sinceLast)];
      }
    }
    _phase = TurnPhase.listening; // optimistic; MicFailed corrects it
    _attempt++;
    _lastMicOpen = _clock();
    return [OpenMic(useRescueEngine: _attempt >= maxListenAttempts)];
  }

  /// Silence policy: ladder while attempts remain, then skip-without-grading;
  /// too many silent cards in a row pauses the session. A fake "analyse"
  /// never shows here — analyse is only commanded when a verdict is genuinely
  /// pending, which silence is not.
  List<TurnCommand> _handleSilence({required bool hadRealWindow}) {
    if (_attempt < maxListenAttempts) {
      _phase = TurnPhase.waitingRetry;
      return [
        ShowNotHeard(_attempt, maxListenAttempts),
        WaitThenRetry(ladderBeat),
      ];
    }
    // Ladder exhausted. Silence is NEVER a wrong answer (2026-07-06).
    _consecutiveSilentCards++;
    if (_consecutiveSilentCards >= silentCardsBeforePause) {
      _phase = TurnPhase.paused;
      return const [PauseSession()];
    }
    _phase = TurnPhase.skipped;
    return const [SkipCard()];
  }

  /// Manual session resume: the user says the environment is OK again, so
  /// the consecutive-silence streak starts over (mirrors the legacy unpause).
  void resetSilenceStreak() => _consecutiveSilentCards = 0;

  /// The host reports the mic closed while a verdict is still possible
  /// (late platform results, a second race lane). Only meaningful from
  /// listening — silence handling owns the other paths.
  List<TurnCommand> micClosedPendingVerdict(int turn) {
    if (turn != _turn || _phase != TurnPhase.listening) return const [];
    _phase = TurnPhase.analyzing;
    return const [ShowAnalyzing()];
  }
}
