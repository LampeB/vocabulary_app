# Seed content authoring (starter catalog)

> Companion docs: `content-roadmap.md` (what's missing, generation units
> U1–U9, agent/skill pipeline) · `.agents/skills/seed-content/SKILL.md`
> (the how-to an agent follows). **Style rule (2026-08-08): every example
> or learner-built sentence must be practically usable in travel or real
> conversation — no Duolingo-style absurd sentences, anywhere, including
> grammar drills.**

The starter curriculum scales **per language, not per pair**: a
language-agnostic registry plus one content layer per studyable language.
Any ordered pair (source > target) is composed at seed time by
`StarterSeeder` — target layer supplies the studied words/examples, source
layer supplies the prompt side, target notes supply the concept notes.

## Files

```
assets/seed/vocab/registry.json      lists + concepts (no language content)
assets/seed/vocab/lang/<code>.json   one per studyable language (fr en it de es ko)
```

`tool/seed/` holds the one-shot generators that produced the initial layers
(fr/ko converted from the legacy fr→ko asset; en/it/de/es LLM-generated
2026-08-08, **pending native review**; English ko-note fallbacks likewise).

## Format contract

Enforced by `test/seed/seed_catalog_validity_test.dart` (CI):

- every registry concept id is unique and belongs to exactly ONE list;
- every language layer covers EVERY registry concept: ≥1 word, exactly one
  `is_primary`;
- `example` is the same sentence translated in every language — if one
  language has it, all must (aligned per concept);
- `notes` keys are UI locales; ko notes must include the `en` fallback
  (non-French learners of Korean read it via source → en fallback);
- word `tags` ∈ {m,f,n}: gender for common nouns only — proper nouns stay
  untagged so article drills skip them;
- `seed.list.<id>.name/.desc` exist in all 7 translation files;
- `target_langs` (null = universal) references studyable languages only.

## Adding a language

1. Create `assets/seed/vocab/lang/<code>.json` covering all registry concepts.
2. Add the language to `Languages._speechLocales` (that's what makes it
   studyable) + `lang.<code>` keys per translation file.
3. Run the validity gate. Nothing else: seeding, pairing and sync are generic.

## Adding content

New concepts/lists go in the registry **plus every language layer** (the gate
fails otherwise). Never rename a concept id or list id — seeded rows are
reconciled by these ids (`concepts.seed_id`, `vocabulary_lists.seed_id`), and
grammar prerequisites reference list ids. List display names live in the
translation files; they are resolved once at seed time and user-editable after.

## Grammar article overrides

Each key in `mechanics.article.overrides` matches the exact target word.
The value is the full expected form. When a learned sense takes no article,
map the word to itself, as in `"milk": "milk"`. The generator excludes
these entries from article exercises and from the corresponding
`min_known_words` counts. Check that the rule's prerequisite lists still
provide enough eligible nouns.

Use the aligned vocabulary examples to check the taught sense. In
`starter-food`, coffee keeps its countable serving sense for the a/an rule
because the English example is “A coffee, please.” The revised English
article card copy is pending native review.

By the 2026-11-27 decision, `en-articles-a-an` requires `starter-food`
and `starter-greetings`, with a minimum of five known eligible nouns.
The food list supplies three eligible nouns and the greetings list adds
four. Both lists use the standard vocabulary mastery gate.

## Grammar lesson pages (P3)

Grammar rules may carry an optional `lesson_pages` array. It is authored
content, never generated at runtime, and is intentionally absent until a U7
unit supplies reviewed pages. Each page uses this compact shape:

```json
{
  "type": "explain",
  "text": { "fr": "…", "en": "…", "ko": "…" },
  "example": {
    "target": "Je parle français.",
    "translations": { "fr": "…", "en": "…", "ko": "…" },
    "detail": { "fr": "…", "en": "…", "ko": "…" }
  }
}
```

`type` is descriptive (`explain`, `example`, then future reviewed types); the
reader must degrade unknown types to readable text. `example` is optional. If
present, its `target` is in the studied language; `translations` is shown on
the page and `detail` is the short, localized copy for its contextual popup.
For V0, every displayed page and example must include fr, en and ko: never
fall back to English for the Korean → French learner path.

## Generation prompt (for LLM-drafted layers)

Give the model: the registry concept ids with categories + the fr layer as
semantic reference. Ask for: A1-register primary word per concept, the aligned
example translation where fr has one, gender tags per the contract. Flag the
output file header as pending native review.
