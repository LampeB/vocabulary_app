---
name: seed-content
description: Use when generating or editing seed content — vocab packs/lists, language layers, example sentences, teaching notes, grammar rules/groups, or adding a language. Encodes the format contracts, the sentence style guide, per-unit workflows, and the validation gate.
---

# Seed content generation

You are producing **data**, not code. One unit per run (unit ids U1–U9:
`docs/content-roadmap.md`), gate green before you claim done. Format
contract lives in `docs/seed-content-authoring.md` — read both before
writing a single entry.

## Hard rules

1. **Never rename or delete a concept id, list id, or rule id.** Seeded
   rows reconcile by these ids; grammar prerequisites reference list ids.
   Additive changes only.
2. **Every registry concept must exist in every language layer** — adding
   a concept means touching `registry.json` + all 6 (or more) files in
   `assets/seed/vocab/lang/`. The gate fails otherwise.
3. **Examples are aligned**: same sentence, translated, in every layer
   that concept appears in. All-or-none per concept.
4. **Exactly one `is_primary` word** per entry; gender `tags` ∈ {m,f,n}
   on common nouns only.
5. Grammar rule ids are language-prefixed (`es-…`); locale cards carry
   **fr + en minimum**; every rule ships `test_vectors` and they must
   pass the language's grammar module in CI. If the rule needs a mechanic
   the engine doesn't have, STOP and file a code ticket — do not invent
   mechanics in JSON.
6. New `seed.list.<id>.name/.desc` keys go in **all 7** translation files
   (`assets/translations/{fr,en,es,de,it,ja,ko}.json`).
7. LLM-drafted content for a language you can't natively verify gets the
   file-header flag **pending native review** (see existing layer files).
8. Levels/groups: once the schema carries them, every new list gets
   `level`, every new rule gets `level` + `group` (~5 rules per group).

## Sentence style guide (non-negotiable, user decision 2026-08-08)

Every example sentence, worked example, and test-vector sentence must be
**usable in real life** — traveling, ordering, meeting people, daily
logistics. First person where natural, A1/A2 register for starter
content, high-frequency vocabulary. Absurd or toy sentences
(Duolingo-style "the fox's big cucumber") are banned, including inside
grammar drills: exercise the mechanic inside a sentence the learner
could actually say.

## Per-unit workflows

- **U1 new language layer**: copy the fr layer as semantic reference →
  produce `vocab/lang/<code>.json` covering every registry concept →
  gender tags if the language has grammatical gender → `lang.<code>` key
  in all translation files → add to `Languages._speechLocales` → pubspec
  already globs the dir? verify `assets/seed/vocab/lang/` is declared.
- **U2 vocab pack (level list)**: pick ~18–20 concepts for the theme →
  new ids (kebab, stable, list-scoped semantics) in `registry.json` →
  entries in every layer **with aligned examples for all of them** (new
  content ships 100 % exampled) → `seed.list.*` keys ×7.
- **U3 examples backfill**: for each target concept, write the fr example
  first (style guide), then translate into each layer. Batch ≤40
  concepts per run.
- **U4 notes**: only where a note earns its place (function words, false
  friends, register). Locale-keyed map, `fr` + `en` minimum.
- **U5 grammar group**: ~5 small rules, staged prerequisites (ramp lists
  1→3 across the group like ko A1), `min_known_words` per category,
  worked_examples fr+en, 8–15 test_vectors per rule, run them through
  the module tests locally.
- **U6/U8/U9**: edits inside existing files — same gate, smaller diff.

## Validation gate (run before claiming done)

```bash
LD_LIBRARY_PATH="$HOME/.local/lib:$LD_LIBRARY_PATH" flutter test \
  test/seed/seed_catalog_validity_test.dart \
  test/integration/seed_starter_lists_test.dart \
  test/unit/grammar/latin_grammar_test.dart \
  test/unit/grammar/korean_grammar_test.dart
```

(The `LD_LIBRARY_PATH` prefix is required on this machine for the sqlite3
native lib.) Also `python3 -m json.tool` every file you touched, and for
grammar edits run any `test/unit/grammar/*` file for that language.

## Done means

Gate green + a summary listing: files touched, entry/rule counts, what
needs native review, any code tickets filed. Never mix code changes into
a content run beyond the tiny wiring steps U1 explicitly lists.
