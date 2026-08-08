# Content roadmap — what's missing, and how to order it from an agent

Companion to `seed-content-authoring.md` (the format contract). This doc is
the **shopping list**: every missing piece of content, cut into units small
enough that a single agent run can generate one and pass the validity gate.

How to order a unit: invoke the `seed-content` skill (or the
`seed-content-author` agent, which loads it) with the unit id and its
parameters, e.g. *"U3: backfill examples for the 71 concepts without one"*
or *"U5: generate the A2 grammar group for Spanish"*.

## Current state (2026-08-08)

| Asset | Have | Missing |
|---|---|---|
| Vocab lists | 5 universal A1 lists + 1 ko particles list (111 concepts) | Everything A2→C2 |
| Language layers | 6 (fr en it de es ko), 111/111 entries each | New languages; native review of en/it/de/es (LLM-drafted) |
| Example sentences | 40/111 concepts, aligned across all 6 layers | 71 concepts bare |
| Teaching notes | ko: 111/111 (fr+en) | de/en/es/fr/it: 0 notes |
| Grammar rules | A1: 4/lang (latin), 5 (ko), texts fr+en | A2→C2 groups; texts in other UI locales; latin A1 staging is flat |
| Lesson texts (viewer) | none (🔴 in map) | All levels, all languages |
| Level tests | design only | Generated at runtime from vocab+rules — no seed content needed, but rules/lists must be level-tagged |

## Schema prerequisites (CODE, not content — do these first)

The parcours A1→C2 and level tests need level metadata the seed schema
doesn't carry yet. Small, but content generated before this lands would
need re-touching:

- **P1 — level tag on lists**: `registry.json` lists gain `"level": "A1"`.
  Existing 6 lists are A1. Seeder + validity test updated.
- **P2 — group + level on grammar rules**: rules gain
  `"level": "A1", "group": "<lang>-a1-g1", "group_order": n` so the
  ~5-rule groups of `grammar-flow.md` exist in data. Existing rules = one
  group per language.
- **P3 — lesson text slot**: decide where lesson-viewer texts live
  (probably `assets/seed/grammar/<lang>/lessons.json` or a `lesson` locale
  map on the rule). Blocks U7.

## Units of work (the orderable menu)

Each unit = one agent run, one reviewable diff, gate green
(`test/seed/seed_catalog_validity_test.dart` + grammar module tests).

### U1 — New language layer (unlocks a new studyable language)
- **Input**: language code; registry + fr layer as semantic reference.
- **Output**: `assets/seed/vocab/lang/<code>.json` (all concepts, aligned
  examples, gender tags if applicable), `lang.<code>` keys in the 7
  translation files, `Languages._speechLocales` entry (tiny code edit).
  Non-latin languages also need a grammar module (code) before U5.
- **Size**: ~111 entries today; grows with every U2 shipped before it.

### U2 — Vocab pack for a level (the main cliff-filler)
- **Input**: level (A2…), theme list. Target per level: **8–10 lists ×
  18–20 words** (~160–200 concepts), themes chosen for practical use
  (travel, small talk, food, work, health, opinions…).
- **Output**: registry additions (new list + concept ids, `level` tag)
  **plus entries in all 6 layers** (gate fails otherwise), examples for
  every concept (see style guide), `seed.list.*` keys in 7 translation
  files.
- **Order**: one list per run is the comfortable diff size; a level is
  ~8–10 runs.

### U3 — Examples backfill (A1)
- **Input**: the 71 example-less concept ids.
- **Output**: aligned `example` in all 6 layers per concept. Do in 2–3
  batches. Should ship **before** the intro screens (they lean on
  examples for first contact).

### U4 — Teaching notes for a language layer
- **Input**: language (de/en/es/fr/it — ko is done); which concepts need
  notes (function words, false friends, register traps — not every noun).
- **Output**: `notes` (fr + en minimum) on the selected entries.

### U5 — Grammar group for a language × level
- **Input**: language, level, group theme (e.g. es-A2: pretérito vs
  imperfecto). ~5 small rules per group per `grammar-flow.md`.
- **Output**: rules appended to `assets/seed/grammar/<lang>/rules.json`
  (prefixed ids, locale cards fr+en, `prerequisite_lists` pointing at
  that level's lists, mechanics from the generic engine, worked examples,
  **test_vectors** — CI runs them through the module). If the group needs
  a mechanic the engine lacks, that's a code ticket first, not a content
  run.

### U6 — Restage latin A1 prerequisites (quick win, pure JSON)
- Today all 4 rules per latin language gate on the same 2 lists
  (`starter-food`, `starter-daily-life`) — flat, and learners doing lists
  in order see no grammar for weeks. Restage like Korean: first rule on
  `starter-greetings`, then ramp 1→3 lists so rules unlock one at a time.
  One run, all 5 languages. **Note**: with the new global-80 % gate the
  wall is lower, but staging still sequences the unlocks.

### U7 — Lesson texts (blocked on P3)
- **Input**: rule/group ids for a language × level.
- **Output**: short lesson pages (locale cards) per the lesson-viewer
  design — « moins un quiz, plus une leçon ».

### U8 — Grammar texts in more UI locales
- Rule titles/descriptions/explanations exist in fr+en only; de/es/it/ja/ko
  UI locales read the en fallback. One run per added locale.

### U9 — Native review pass
- en/it/de/es layers are LLM-drafted (`tool/seed/generate_layers.py`,
  flagged pending review). A review unit = one language: check register,
  gender tags, example naturalness; clear the pending flag in the file
  header.

## Suggested order

1. **U6** (restage latin A1) + **U3** (examples backfill) — content-only,
   immediate pedagogy wins on what's already shipped.
2. **P1/P2** schema tags, then **U2 × A2** for the launch languages and
   **U5 × A2** groups — kills the ~2-week content cliff.
3. **U4** notes + **U8** locales + **U9** native review — polish.
4. **P3 + U7** lessons when the viewer design lands.
5. A3/B1… repeat U2+U5 per level; **U1** whenever a new language is
   wanted.

## Example-sentence style guide (user decision, 2026-08-08)

Every example and every sentence a learner is asked to build must be
something they could **actually say while traveling or talking to
people**. Concretely:

- Situational: ordering, asking the way, introducing yourself, small
  talk, transactions, feelings, plans. First person where natural.
- No Duolingo-style absurdism (« le gros concombre du renard » is
  banned), no toy sentences that exist only to exercise a rule.
- A1/A2 register: short, high-frequency words, present-tense-heavy early.
- A rule's worked_examples and test_vectors follow the same rule: drill
  the mechanic **inside a usable sentence**.
- Aligned across layers: the example is the same sentence translated in
  every language (the gate enforces presence, a human enforces meaning).

## The generation pipeline (agent + skill + flow)

- **Skill** `.claude/skills/seed-content/SKILL.md` — the how-to: format
  contracts, per-unit workflows, style guide, validation commands.
- **Agent** `.claude/agents/seed-content-author.md` — a subagent wired to
  load the skill and produce exactly one unit per run, gate green,
  flagged for native review.
- **Flow** per run: pick unit → agent drafts JSON + translation keys →
  runs the validity gate + grammar tests → summarizes what needs human
  (native) review → you review the diff and commit. Content lands as
  data-only PRs; code tickets (new mechanics, schema tags) are filed
  separately, never smuggled into a content run.
