# Grammar lessons: from quiz to progressive lesson

**Status:** planned (user feedback 2026-07-22 after the first real grammar
session: "DAMN that was hard… it should be more of a lesson and less of just
a quiz, it should be progressive").

## The problem

Today a grammar "session" is: a short lesson sheet (title + explanation +
one worked example) → straight into production drills (conjugate/attach from
memory, typed or spoken). That's a cliff, not a ramp. The user is tested on
something they were never really taught.

## Target: a staged lesson ramp

Each rule becomes a five-stage progression; a stage unlocks when the
previous one is done. The hub card shows per-stage progress instead of one
mastery bar.

1. **Apprendre (teach)** — a real multi-page lesson: the concept in plain
   language, several worked examples WITH audio (tap to hear), contrast
   cases (은 vs 는 side by side), common mistakes. Swipeable pages; no
   grading. Content source: extend `grammar_rules.json` with `lesson_pages`;
   author Korean's by hand first (only ~6 rules exist).
2. **Reconnaître (recognize)** — multiple choice: "which form is correct?"
   3-4 options generated from the rule mechanics (the wrong particles/forms
   are the natural distractors). Low effort, high scaffold.
3. **Construire (build)** — tap-to-assemble / fill-in-the-blank: the stem is
   shown, the user picks the particle/ending from chips. Still recognition,
   but productive shape.
4. **Écrire (produce)** — today's typed drills, unchanged.
5. **Parler (speak)** — today's voice drills, unchanged (the machine/race
   pipeline handles them well now).

Stage gates: e.g. 5 correct in a stage advances; rule mastery = stage 5
complete. `grammar_progress` grows a per-stage dimension (Drift + Supabase
migration).

## What already exists to build on

- `GrammarRule.mechanics` (ParticleMechanics/ConjugationMechanics) can
  GENERATE stage-2/3 exercises + distractors deterministically — no AI
  needed for the scaffolded stages.
- `workedExamples` + audio pipeline (AudioDirector/ElevenLabs) for stage 1.
- The AI exercise generator (edge function) stays for stage 4/5 variety.
- Rule gating/unlock progress bars (grammar hub) — per-stage bars slot in.
- The quiz machinery (machine/race) runs stages 4-5 as-is; stages 1-3 are
  simple non-voice widgets — much easier surface.

## Order of work (each step ships)

1. Content schema: `lesson_pages` in grammar_rules.json + hand-written pages
   for the existing Korean rules (fr copy first, translations after).
2. Stage model + per-stage progress (Drift migration, hub per-stage bars).
3. Stage 1 lesson viewer (swipeable pages + audio).
4. Stage 2 multiple-choice + stage 3 chip-assembly widgets, generated from
   mechanics.
5. Wire stages 4-5 (existing drills) behind the gates; session entry becomes
   "continue where you left off in the ramp".

## Notes

- Same philosophy may later apply to vocabulary onboarding (the user flagged
  this once for vocab too) — keep the stage widgets reusable.
- Keep the dev unlock toggle working across stages for testing.
