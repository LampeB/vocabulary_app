# Grammar lessons: from quiz to progressive lesson

**Status:** planned — now a SUB-PLAN of `docs/two-flow-daily-plan.md`
(the app-wide Apprendre/Réviser split with a daily path). Original trigger:
user feedback 2026-07-22 after the first real grammar session ("DAMN that
was hard… it should be more of a lesson and less of just a quiz, it should
be progressive"). Builds in that epic's phase 3.

> **Addendum 2026-08 (parcours era):** structure and scheduling are
> superseded by `design/v2-ux-architecture.md` §F3 — CEFR levels contain
> GROUPS of ~5 small rules, each group gated by MASTERY of its
> prerequisite vocab lists (the v1 unlock mechanic + bars, kept at group
> scope; different lists per group/level). Per rule: stages 1-3 only
> (short lesson 3-6 pages → Reconnaître J+1 → Construire J+2); stages
> 4-5 (Écrire/Parler) move to the group's **Mélange** phase (a combining
> lesson + mixed drills over the group's rules). One group in flight per
> language; the tier exam (Test de niveau) closes each level. The lesson
> CONTENT spec below (page types, markup, narration, voice roles)
> remains authoritative — lessons get shorter since rules are smaller.

## The problem

Today a grammar "session" is: a short lesson sheet (title + explanation +
one worked example) → straight into production drills (conjugate/attach from
memory, typed or spoken). That's a cliff, not a ramp. The user is tested on
something they were never really taught.

## Target: a staged lesson ramp

Each rule becomes a five-stage progression; a stage unlocks when the
previous one is done. The hub card shows per-stage progress instead of one
mastery bar.

1. **Apprendre (teach)** — a real multi-page lesson. Design spec (user
   direction 2026-07-22):

   - **One idea per screen** — never a wall of text. Pages ALTERNATE:
     a short explanation page, then one or more example pages for that
     exact point, then the next explanation, and so on.
   - **Short lessons** — target 6-10 pages per rule, each page ≤2-3 short
     sentences (or 1-2 examples). A rule that needs more splits into two
     lessons.
   - **Free manual navigation** — horizontal pager, swipe or tap-zones in
     BOTH directions, page dots + progress; the user can go back and
     re-read anything. No timers, no grading.
   - **Inline highlights** — a tiny markup in the page text so key
     elements pop in color: `[[…]]` renders in the accent (clay) color —
     the particle/ending being taught; `((…))` renders in the secondary
     (teal) — contrasted/secondary elements. Hangul runs get the Korean
     font automatically (same usesHangul resolver as the quiz). Parser is
     pure Dart → host-tested.
   - **Narrated lessons, multiple voices** (user direction 2026-07-22):
     every page can be read aloud by TTS, with DISTINCT voices per role —
     the explanation/rule in the narrator voice (UI language), examples in
     a different voice (target language), and multi-speaker examples
     (dialogues) can assign a voice per line.

     - Content: pages/lines carry an optional `voice` role, e.g.
       `{"type": "example", "lines": [{"voice": "speakerA", "ko": "…"},
       {"voice": "speakerB", "ko": "…"}]}`. Roles, not raw ids.
     - A **voice-role registry** maps roles → ElevenLabs voice ids per
       language (premium). Free tier falls back to device TTS — usually a
       single voice; role distinction is a premium nicety, never a gate on
       the content itself.
     - Plumbing: AudioPlayerService.speak grows an optional voiceId
       (ElevenLabsService already supports per-call voices + caching);
       AudioDirector gains a narration queue (page → ordered utterances
       with roles, tap-to-play or play-all per page, stop on page change —
       manual navigation stays in charge).
     - Example pages keep per-line tap-to-play; narration prefetches the
       page's audio like quiz prefetch does.

   Content schema: `lesson_pages` array in `grammar_rules.json`, e.g.
   `{"type": "explain", "text": "Après une consonne on attache [[은]]…"}` /
   `{"type": "example", "ko": "[[책은]] 재미있어요", "fr": "Le livre est
   intéressant", "note": "책 finit par une consonne → [[은]]"}`.
   Author the ~6 Korean rules by hand (fr copy first, translations after).
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
