# v2 implementation plan — the two-flow era

**Baseline:** `v1.2.0` (2026-07-22) — voice refactor complete, multi-language
shipped, all plans committed. This document consolidates
`two-flow-daily-plan.md`, `grammar-lessons-redesign.md` and
`feature-roadmap.md` into ONE ordered build sequence.

Rules of engagement: one milestone per focused session where possible; every
milestone ships suite-green + on-device check; voice work only through the
machine/director/race seams; everything multi-language by design.
Milestones flagged **[DESIGN]** need new screen designs first (Claude
Design; see `docs/app-design-overview.md` for the current state).

## Milestones

### M1 — Quick win: "Mots difficiles" (leeches)
Roadmap #4. Query over variant_progress.lapses + review_events; smart
source tile in quiz setup. No new screens. **Size: S.**

### M2 — Quick win: weekly recap  **[DESIGN — recap screen]**
Roadmap #6. Aggregate queries (shared with M6 dashboard), one celebratory
screen + home card + optional notification. **Size: S-M.**

### M3 — Daily-path shell (epic phase 1)  **[DESIGN — new home/path]**
Step model + deterministic generator from EXISTING data (due counts per
pair, grammar statuses, leech count once M1 lands); path UI on home;
deep-links into existing sessions. No session internals change. **Size: M.**

### M4 — Vocab learning flow: batch intro + gate (epic phase 2)
**[DESIGN — intro/echo screens]**
introducedAt data model (Drift + Supabase migrations), card sources gated
(reviews never serve unseen words), intro batch screens + ungraded echo
practice, daily new-word budget setting. The path's "Découvrir" step goes
live. **Size: M-L.**

### M5 — Grammar staged ramp (epic phase 3)  **[DESIGN — lesson viewer]**
Per `grammar-lessons-redesign.md`: lesson_pages content schema + highlight
markup parser (pure Dart, tested); hand-written Korean lesson content;
paged viewer (one idea/screen, free navigation, color highlights); narration
with voice roles (AudioDirector narration queue + ElevenLabs role registry);
mid-lesson quick checks (roadmap #1) and multi-voice dialogues (roadmap #2)
as page types; stage model + per-stage progress (Drift + Supabase) and
per-stage gates wiring stages 4-5 (existing drills). **Size: L — likely 2-3
sessions (schema+content / viewer+narration / stages+gates).**

### M6 — Cloze cards (roadmap #3)
Sentence-with-blank cards drawn from lesson/dialogue content containing due
words; grades onto the blanked word's FSRS card; review_events tagged.
**Size: M.**

### M7 — Dashboard: progression + CEFR (roadmap #9)
**[DESIGN — stats/dashboard overhaul]**
Multi-scale charts (day/week/month/all), per-pair; CEFR estimate card per
target language (thresholds v1; word-level CEFR tags v2 via the AI-batch
pipeline). Reuses M1/M2 queries. **Size: M-L.**

### M8 — Word families (roadmap #7)  **[DESIGN — family chips/browser]**
Generic concept_roots tables + AI-batch generation + cache; hanja families
for Korean first, Latin/Germanic roots+cognates for European targets on the
same design; UI chips on answer reveal + list rows; family browser v2.
**Size: L.**

### M9 — Challenges revival (roadmap #8)  **[DESIGN — challenge flow]**
Step 0 audit of the dormant tables/UI, THEN scope the async-duel MVP.
**Size: L (after audit).**

### M10 — Epic phase 4 polish
Path tuning (budgets, pair balance), completion celebration, notification
alignment, stats tie-ins. **Size: M.**

## Design dependencies summary

New screens needing design (in order of need): daily-path home (M3), vocab
intro/echo (M4), lesson viewer + dialogue pages (M5), weekly recap (M2),
dashboard/CEFR (M7), word-family browser (M8), challenge flow (M9).
`docs/app-design-overview.md` documents the current app (screens +
design system) as the reference for consistency.

## Standing backlog (not scheduled)

sherpa-onnx sharedPcm racer · Concept.exampleFr/Ko → A/B data migration ·
grammar modules for non-Korean languages · vocab teach-first onboarding
reuse · streak freeze / OCR import (not selected).
