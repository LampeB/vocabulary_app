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

## Sequencing

1. NOW, parallel to epic phase 1: **#4 leeches**, then **#6 weekly recap**
   (both quick, independent, immediately felt).
2. Epic phase 3 carries **#1 quick checks** + **#2 dialogues** natively.
3. After phase 3: **#3 cloze** (feeds on the new sentence content).
4. Then **#7 hanja families** (own data pipeline), and **#8 challenges**
   (after its audit).
