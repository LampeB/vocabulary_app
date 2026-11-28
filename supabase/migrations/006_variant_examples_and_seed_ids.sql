-- Multi-language seed epic: per-variant examples + stable seed identities.
--
-- 1. word_variants.example — example sentence in the variant's own language.
--    Replaces the fr/ko-specific concepts.example_fr/example_ko pair (kept
--    as read-only legacy for now; nothing in the UI reads them).
-- 2. vocabulary_lists.seed_id / concepts.seed_id — stable catalog identity
--    for seeded content ('starter-greetings:fr>ko' / 'hello'), so seeding
--    dedups and tops up by id instead of by (localized, editable) name.
--
-- Idempotent and row-preserving.

BEGIN;

ALTER TABLE public.word_variants
  ADD COLUMN IF NOT EXISTS example TEXT;
ALTER TABLE public.vocabulary_lists
  ADD COLUMN IF NOT EXISTS seed_id TEXT;
ALTER TABLE public.concepts
  ADD COLUMN IF NOT EXISTS seed_id TEXT;

-- Backfill: copy the legacy per-concept examples onto the primary fr/ko
-- variants they belong to.
UPDATE public.word_variants wv
SET example = CASE wv.lang_code
    WHEN 'fr' THEN c.example_fr
    WHEN 'ko' THEN c.example_ko
  END
FROM public.concepts c
WHERE c.id = wv.concept_id
  AND wv.example IS NULL
  AND wv.is_primary
  AND wv.lang_code IN ('fr', 'ko');

-- Seeded lists are looked up by (owner, seed_id) during reconciliation.
CREATE INDEX IF NOT EXISTS idx_vocabulary_lists_seed
  ON public.vocabulary_lists (owner_id, seed_id)
  WHERE seed_id IS NOT NULL;

COMMIT;
