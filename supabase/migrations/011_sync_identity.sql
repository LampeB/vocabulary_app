-- A copied shared list needs its own public token. Source provenance is not
-- globally unique: many different learners may import the same public list.
ALTER TABLE public.vocabulary_lists
  ADD COLUMN IF NOT EXISTS imported_from_share_token text;
UPDATE public.vocabulary_lists
SET imported_from_share_token = share_token, share_token = NULL
WHERE visibility = 'private' AND share_token IS NOT NULL;

-- The existing unique(user_id, variant_id, direction) constraint is the
-- authoritative progress identity. Clients upsert using that business key.
