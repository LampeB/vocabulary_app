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

-- Shared curriculum assets are readable to all authenticated learners. Custom
-- paths remain private: only the owner of the linked list can download them.
DROP POLICY IF EXISTS "vocab audio authenticated read" ON storage.objects;
CREATE POLICY "vocab audio authenticated read"
  ON storage.objects FOR SELECT TO authenticated
  USING (
    bucket_id = 'vocab-audio'
    AND (
      name LIKE 'seed/%'
      OR EXISTS (
        SELECT 1
        FROM public.word_variants w
        JOIN public.concepts c ON c.id = w.concept_id
        JOIN public.vocabulary_lists l ON l.id = c.list_id
        WHERE w.audio_path = storage.objects.name
          AND l.owner_id = auth.uid()
      )
    )
  );

COMMIT;
