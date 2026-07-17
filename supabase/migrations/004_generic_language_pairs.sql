-- Generic learning-language pairs (generic-language-pairs epic).
--
-- Relaxes the FR/KO-only constraints so lists in any pair (en/it/de/es/ko/…)
-- and the new generic 'question>answer' direction form sync to the cloud.
-- Without this, a variant with lang_code='en' or a progress row with
-- direction='en>it' is REJECTED by the remote CHECK constraints, so
-- non-FR/KO lists work locally but silently fail to push to Supabase.
--
-- Safe on an existing database: idempotent and row-preserving. NOT auto-
-- deployed — review, then run against your project (supabase db push / SQL
-- editor). Verify the auto-generated constraint names below match your schema
-- (\d public.word_variants) before running if your DB predates these tables.

BEGIN;

-- 1. Per-list language pair. The Drift client already sends lang_a/lang_b in
--    its remote map; add the columns (existing rows are all FR↔KO).
ALTER TABLE public.vocabulary_lists
  ADD COLUMN IF NOT EXISTS lang_a TEXT NOT NULL DEFAULT 'fr';
ALTER TABLE public.vocabulary_lists
  ADD COLUMN IF NOT EXISTS lang_b TEXT NOT NULL DEFAULT 'ko';

-- 2. Word variants: drop the lang_code IN ('fr','ko') whitelist. New study
--    languages are added data-only in the client's Languages registry, so a
--    SQL whitelist would just be a second place to edit. Keep a format sanity
--    check instead.
ALTER TABLE public.word_variants
  DROP CONSTRAINT IF EXISTS word_variants_lang_code_check;
ALTER TABLE public.word_variants
  ADD CONSTRAINT word_variants_lang_code_check
  CHECK (char_length(lang_code) BETWEEN 2 AND 8);

-- 3. Direction is now the generic 'question>answer' form (e.g. 'en>it').
--    Migrate the legacy enum values first (mirrors the client's Drift
--    migration at schemaVersion < 4), then relax the constraint. The
--    UNIQUE (user_id, variant_id, direction) index is unaffected — same rows,
--    rewritten value.
ALTER TABLE public.variant_progress
  DROP CONSTRAINT IF EXISTS variant_progress_direction_check;
UPDATE public.variant_progress SET direction = 'fr>ko' WHERE direction = 'frToKo';
UPDATE public.variant_progress SET direction = 'ko>fr' WHERE direction = 'koToFr';
ALTER TABLE public.variant_progress
  ADD CONSTRAINT variant_progress_direction_check
  CHECK (direction ~ '^[a-z]{2,8}>[a-z]{2,8}$');

COMMIT;
