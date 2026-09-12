# Two flows, one daily path: Apprendre / Réviser

**Status:** planned (user direction 2026-07-22: "a studying flow and a
learning flow… plan it before doing anything").
**Decisions locked:** navigation = daily plan path (guided "today" sequence);
vocab learning = batch intro **with gate** (reviews never serve unseen
words); build order = navigation shell first.

## Vision

The app splits into two complementary flows, surfaced through ONE guided
daily path on home:

- **Apprendre (learn)** — meeting NEW material: multi-screen lessons with
  audio and examples; nothing is graded on first contact.
- **Réviser (study)** — practicing KNOWN material: FSRS reviews, quiz modes,
  grammar exercises. Everything we've built and hardened lives here.

The daily path (Duolingo-style) composes both into a "today" sequence, so
the user opens the app and follows steps instead of choosing screens.

## The daily path

Generated each day (locally, deterministic) from:
1. **Due reviews** (FSRS) per active language pair → one or more Réviser
   steps ("Réviser · 12 mots · 🇫🇷→🇰🇷", mode picked via the existing sheet).
2. **New-word budget** (default ~8/day, user-tunable) → Apprendre steps:
   a batch of unseen words from the user's lists ("Découvrir · 8 mots").
3. **Grammar next step** — the next stage of the in-progress rule (see the
   staged-ramp plan) or the next unlocked rule's lesson.
4. **Streak closer** — completing the path marks the day (ties into the
   existing streak + notifications).

Path states: upcoming → current (highlighted) → done (✓). Steps deep-link
into existing screens/sessions. Multiple active pairs: steps are tagged with
their pair flags; the path groups by pair, heaviest-due pair first.

Home becomes the path screen (streak header stays; lists/stats/grammar hub
remain reachable — the path complements, never traps).

## Vocab learning flow (batch intro + gate)

- **Intro batch:** 5-10 unseen words from the active list(s): one screen per
  word — word + translation + audio (both languages) + example sentence when
  available; swipe through, tap to replay. Then a light **echo practice**
  (multiple choice both directions) — encouraging, not graded into FSRS.
- **Guided first contact:** in the daily path, an item can be presented before
  its first graded practice. The introductory and echo steps are encouraging,
  not graded into FSRS.
- **Free-practice rule (decision 2026-09-12):** this is not a global gate.
  A learner can create/import a list and launch a vocabulary quiz immediately,
  without following a lesson or curriculum. The daily path recommends a
  sequence; it must never trap users who simply want to practise vocabulary.

## Grammar learning flow

The staged ramp of `docs/grammar-lessons-redesign.md` IS grammar's learn
flow (stages 1-3 = Apprendre; stages 4-5 = Réviser steps). That doc becomes
a sub-plan of this epic; its hub/progress design is unchanged.

## Build phases (each ships green + on-device)

1. **Shell first (decided):** the daily-path home — step model, generator
   fed by EXISTING data (due counts, grammar rule statuses), path UI,
   deep-links into current sessions. No behavior change inside sessions.
   The "Découvrir" step can initially open the list detail (placeholder)
   until phase 2 lands.
2. **Vocab intro:** intro/echo screens and budget setting for the guided path,
   while preserving direct list-based quiz access in free practice.
3. **Grammar ramp:** per the existing sub-plan (content schema → stage
   model → lesson viewer → MC/chips widgets → gate wiring).
4. **Polish:** plan tuning (budget, pair balance), path completion
   celebration, notification alignment ("your path is ready"), stats tie-in.

## Related

`docs/feature-roadmap.md` — seven selected features slotted around these
phases (quick checks + dialogues ride phase 3; cloze follows it; leeches +
weekly recap are parallel quick wins; hanja families and challenges follow).

## Open questions (decide when their phase starts)

- Daily budget default + premium interaction (unlimited new words premium?)
- Path regeneration rules mid-day (new list imported, budget raised…)
- Whether Cartes/typing/voice mode choice belongs per-step or per-day.

## Constraints

- Voice changes keep flowing through the machine/director/race seams.
- Stage/intro widgets built reusable across vocab and grammar.
- The dev grammar-unlock toggle must keep working for testing.
