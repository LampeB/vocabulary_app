-- List origin column (starter-content epic).
--
-- The Drift client's upsertList payload has included 'origin'
-- ('user' | 'starter' | 'premium') since the starter-lists feature, but the
-- remote table never gained the column — PostgREST rejects unknown columns,
-- so EVERY list upsert 400s and lists (and, via FK ordering, their concepts
-- and variants) silently never reach the cloud.
--
-- Idempotent and row-preserving; existing rows become 'user'.

BEGIN;

ALTER TABLE public.vocabulary_lists
  ADD COLUMN IF NOT EXISTS origin TEXT NOT NULL DEFAULT 'user';

ALTER TABLE public.vocabulary_lists
  DROP CONSTRAINT IF EXISTS vocabulary_lists_origin_check;
ALTER TABLE public.vocabulary_lists
  ADD CONSTRAINT vocabulary_lists_origin_check
  CHECK (origin IN ('user', 'starter', 'premium'));

COMMIT;
