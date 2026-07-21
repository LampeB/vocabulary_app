# Refactor: explicit voice-session orchestration

**Status:** planned (user request 2026-07-21 — "whenever you touch something,
something else breaks; the code needs cleanup/refactor to be more robust and
easier to modify"). Owner: next focused session(s).

## Why

A week of field-testing fixed real bugs but proved the architecture fragile:
every fix risked a neighbor (score >100% → triple grading; dead mic → handler
clobbering; audio shambles → throttle-killed restarts; frozen timer bar; fake
analyse phase…). The root cause is structural, not any single bug:

- `quiz_screen.dart` (~2,100 lines) contains an **implicit** async state
  machine: `_listenToken`, `_whisperWindowGen`, `_raceActive`,
  `_hfAnalyzing/_hfNotHeard/_hfMisheard`, retry ladders, pacing guards, and a
  dozen `Future.delayed` closures — all guarding each other by convention.
- Audio sequencing is spread across three layers (screen SFX/answer TTS,
  provider question TTS + advance timing, AudioPlayerService/TTS/ElevenLabs),
  coordinated only by polling `isSpeaking` and sleeps.
- Two engine paths (legacy ladder + SttRace) share mutable service callbacks.
- None of the timing behavior is host-testable; every regression was found on
  the device via stt_logs.

## Target architecture

1. **`VoiceTurnMachine`** (pure Dart, `lib/services/quiz_orchestration/`):
   an explicit state machine per card —
   `transition → prompt → listening → analyzing → verdict → (retry|advance)`.
   Inputs are events (`ttsDone`, `hypothesis`, `sessionEnded`, `timeout`,
   `retryRequested`…); outputs are commands (`speak`, `earcon`, `openMic`,
   `grade`, `advance`). All tokens/generations/ladders live INSIDE it.
2. **`AudioDirector`**: sole owner of every sound (question/answer TTS,
   earcons, SFX, ElevenLabs prefetch). One queue, one `quiet()` future, an
   explicit `handOffToMic()` — no scattered `stop()` + magic delays.
3. **Engine layer stays as-is**: `SttRace`/`SttEngine` already have the right
   shape (pluggable, tested); the machine consumes race outcomes as events.
4. **`quiz_screen` becomes a renderer** of the machine's state (+ mic button
   forwarding); `quiz_provider` keeps FSRS/persistence/session state only.
5. **Golden-log replay tests**: convert recorded field incidents
   (`stt_logs/*.log`) into event sequences and assert the machine's decisions
   — every past regression becomes a permanent regression test:
   throttle storm (2026-07-19), late Samsung results, stale-token grading,
   dead-mic clobber (2026-07-21), triple grade (2026-07-19).

## Migration plan (each step ships green)

1. Extract `AudioDirector`; route screen + provider audio through it
   (behavior-neutral; deletes the isSpeaking polling loops).
2. Build `VoiceTurnMachine` + unit tests for every transition, including the
   five field incidents above.
3. Route the RACE path through the machine (it's the simpler path).
4. Route the legacy ladder through the machine; delete the flag guards
   (`_raceActive`, banner booleans, ad-hoc timers).
5. Delete the legacy path once Course mode is the default.

## Estimate

Steps 1–2: one focused session. 3–4: one more, with on-device validation per
step (release build). 5: after a week of stable Course-mode testing.
