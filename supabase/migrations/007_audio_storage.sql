-- Pre-rendered vocabulary audio. The client receives an immutable path on a
-- word variant, downloads the asset from this private bucket, and never sends
-- a TTS request while a quiz is running.

BEGIN;

ALTER TABLE public.word_variants
  ADD COLUMN IF NOT EXISTS audio_path TEXT;

CREATE INDEX IF NOT EXISTS idx_word_variants_audio_path
  ON public.word_variants (audio_path)
  WHERE audio_path IS NOT NULL;

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('vocab-audio', 'vocab-audio', false, 5242880, ARRAY['audio/mpeg'])
ON CONFLICT (id) DO UPDATE
SET public = false,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

-- Keep the bucket closed to clients until 012 installs the publication
-- manifest and the owner-scoped private read policy in the same transaction.
DROP POLICY IF EXISTS "vocab audio authenticated read" ON storage.objects;
DROP POLICY IF EXISTS "vocab audio pending activation" ON storage.objects;
CREATE POLICY "vocab audio pending activation" ON storage.objects
  AS RESTRICTIVE FOR ALL TO anon, authenticated
  USING (bucket_id IS DISTINCT FROM 'vocab-audio')
  WITH CHECK (bucket_id IS DISTINCT FROM 'vocab-audio');

COMMIT;
