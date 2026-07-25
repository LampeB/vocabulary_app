# Feature roadmap (selected 2026-07-22)

Seven features picked by the user, planned around the two-flow epic
(`docs/two-flow-daily-plan.md`). Two tracks: **epic-integrated** (build
inside its phases) and **standalone** (parallel quick wins / follow-ups).

## Epic-integrated

### 1. Mid-lesson quick checks — phase 3 (lesson viewer)
Every 3-4 lesson pages, one UNGRADED tap-question that keeps attention.
- Content: page type `check`: `{question, options[], correctIndex, note}` —
  highlight markup works in all fields. Instant feedback (correct → clay
  glow + note; wrong → show correct + note), never recorded to FSRS.
- Also reusable in the vocab intro flow (phase 2 echo practice is the same
  widget).

### 2. Mini-dialogues, multi-voice — phase 3 (lesson content) + later a path step
4-6 line dialogues using ONLY words the user knows (FSRS known set — the
drillWords infrastructure already resolves it).
- Content: page type `dialogue`: `lines: [{voice: speakerA|speakerB, ko,
  fr}]`; voice roles per the narration spec. Tap-per-line + play-all.
- Generation: AI edge function (like the exercise generator) receives the
  known-word list + the rule being taught; result cached per rule. Bundled
  hand-written dialogues for the first Korean rules as fallback/offline.
- Later: standalone "Écouter" step type in the daily path (listening
  comprehension), reusing the same widget.

### 3. Cloze cards — after phase 3 (needs sentence content)
"Fill the blank" quiz cards: a lesson example or dialogue line with a due
word blanked; typed or chip answer.
- Draws sentences CONTAINING due words → context practice becomes a Réviser
  step. Grading records into the existing per-variant FSRS progress (the
  blanked word's card) + review_events tagged `cloze`.
- Dependency: sentence content from lessons/dialogues; no new voice work.

## Standalone (parallel to the epic)

### 4. "Mots difficiles" leech list — QUICK WIN, buildable now
`variant_progress.lapses` and `review_events` already hold the data.
- Definition v1: lapses ≥ 3 OR accuracy < 50% over the last 10 reviews.
- Surfaces as a smart source in quiz setup (next to "À réviser") + a home
  path step when non-empty ("Renforcer · 6 mots difficiles").
- Pure query + one tile: days, not weeks.

### 6. Weekly recap — QUICK WIN
Sunday (or first open after week end): words learned, reviews done,
retention % (review_events), streak held — one celebratory screen.
- Home card when available + optional notification. Data: existing tables,
  one aggregate query set. Reuses stats-screen chart components.

### 7. Hanja-root families — the differentiator
학교/학생/학년 share 학 (study) — show the family, turn memorization into a
network.
- Data: per-concept hanja decomposition + family id. AI-generated in batch
  (edge function) once per concept, cached in a new `concept_roots` table
  (Supabase + Drift); hand-check the first hundred.
- UI v1: on the quiz answer reveal + list detail row → "Famille: 學 (étude)
  → 학교, 학생, 학년" chips linking to the words.
- v2 (later): family browser screen; introduce-by-family in the learn flow.
- Open: free vs premium (leaning free — it strengthens the core loop).

### 8. Challenges revival — biggest, last
Tables exist (`challenges`, friendships, leaderboard) but the feature is
dormant.
- Step 0: AUDIT what exists (entity, remote datasource, any UI stubs).
- MVP: async duel — pick a friend + a shared/public list + mode + word
  count → both play the same card set → results compare screen +
  notification. No real-time play.
- Depends on: social tab state, push notifications; plan the audit before
  committing scope.

### 9. Dashboard: deep progression + CEFR levels
A real progress home for the stats tab (user direction 2026-07-22).

- **Multi-scale progression**: charts at day / week / month / all-time
  (review_events has every timestamped answer; fl_chart is already in) —
  reviews done, accuracy, words known over time, per language pair.
- **CEFR level estimation** per TARGET language: an honest ESTIMATE (never
  a certification claim) from:
  - vocabulary size known (rough public thresholds: A1 ≈ 500, A2 ≈ 1 200,
    B1 ≈ 2 500, B2 ≈ 5 000, C1 ≈ 8 000+),
  - grammar rules mastered (weight grows as grammar content grows),
  - later: dialogue/listening completion.
  Shown as a level card per pair: "🇰🇷 A2 · 62 % vers B1" with a breakdown
  of what moves the needle.
- **Word-level CEFR tags** (v2, better estimates): tag each concept with a
  level per language — AI-batch + cache, same pipeline shape as hanja
  roots. Then the estimate becomes "% of A1/A2/B1 vocab known", much more
  meaningful than raw counts.
- Slots AFTER the quick wins (#4/#6 share the same aggregate queries —
  build those first, the dashboard reuses them).

## Multi-language by design (cross-cutting requirement)

Every feature above must state its story for ALL studyable pairs — nothing
ships Korean-only by accident (user direction 2026-07-22):

- **Lessons/grammar ramp**: the page schema, viewer, highlights and
  narration are language-agnostic; CONTENT is per-language (rules + module
  in the existing registry — Korean first, structure ready for others).
  Fonts/scripts flow through the existing Script resolver (extend it as
  non-Latin/Hangul languages arrive).
- **Dialogues**: generation works for any pair (prompt carries the pair);
  voice roles map per language in the ElevenLabs registry.
- **Cloze**: language-agnostic by construction (uses content sentences).
- **Leeches / weekly recap / dashboard**: pair-agnostic data (direction on
  every progress row/event) — always grouped and filterable by pair.
- **Hanja families → generalized "word families"**: hanja is the KOREAN
  instance of a general concept_roots design (family id + label + members).
  European targets fill it with Latin/Germanic roots and cognates
  (es/it/fr/en/de); the table, UI chips and browser are shared.
- **CEFR**: thresholds and word-level tags are per-language data, same
  shared estimation engine.
- **Challenges / daily path**: already pair-tagged.

## Sequencing

1. NOW, parallel to epic phase 1: **#4 leeches**, then **#6 weekly recap**
   (both quick, independent, immediately felt).
2. Epic phase 3 carries **#1 quick checks** + **#2 dialogues** natively.
3. After phase 3: **#3 cloze** (feeds on the new sentence content).
4. Then **#9 dashboard + CEFR** (reuses #4/#6 queries; word-level tags v2).
5. Then **#7 word families** (hanja first, roots/cognates for European
   targets on the same tables), and **#8 challenges** (after its audit).
