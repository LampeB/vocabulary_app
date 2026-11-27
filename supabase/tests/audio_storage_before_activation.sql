-- Disposable database only, after 007 and before 012. Fixtures roll back
-- before the later migrations are applied to the same database.
BEGIN;
DO $$ BEGIN
  IF to_regclass('public.published_audio_assets') IS NOT NULL THEN
    RAISE EXCEPTION 'Run this check before migration 012';
  END IF;
END $$;

INSERT INTO auth.users(id,email) VALUES
 ('00000000-0000-0000-0000-000000000001','audio_reader@example.invalid'),
 ('00000000-0000-0000-0000-000000000002','audio_owner@example.invalid');
INSERT INTO public.vocabulary_lists(id,owner_id,name,visibility) VALUES
 ('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','Private A','private');
INSERT INTO public.concepts(id,list_id) VALUES
 ('20000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001');
INSERT INTO public.word_variants(id,concept_id,word,lang_code) VALUES
 ('30000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','word','en');

INSERT INTO storage.buckets(id,name,public) VALUES ('other','other',false);
INSERT INTO storage.objects(bucket_id,name) VALUES
 ('vocab-audio','seed/v1/en/legacy-private.mp3'),
 ('vocab-audio','users/00000000-0000-0000-0000-000000000002/private.mp3'),
 ('vocab-audio','users/00000000-0000-0000-0000-000000000001/own.mp3'),
 ('other','unrelated.mp3');

-- A pre-existing permissive Storage rule must not bypass the bucket guard.
GRANT SELECT ON storage.objects TO anon;
CREATE POLICY fixture_existing_storage_read ON storage.objects
  FOR SELECT TO anon, authenticated USING (true);

SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
SET LOCAL ROLE authenticated;
DO $$ DECLARE changed integer; BEGIN
  UPDATE public.word_variants
  SET audio_path = 'users/00000000-0000-0000-0000-000000000002/private.mp3'
  WHERE id = '30000000-0000-0000-0000-000000000001';
  GET DIAGNOSTICS changed = ROW_COUNT;
  IF changed <> 1 THEN RAISE EXCEPTION 'Fixture did not update the client-owned audio_path'; END IF;
  IF EXISTS(SELECT 1 FROM storage.objects WHERE bucket_id='vocab-audio') THEN
    RAISE EXCEPTION 'Audio bucket exposed a clip before security activation';
  END IF;
  IF NOT EXISTS(SELECT 1 FROM storage.objects WHERE bucket_id='other') THEN
    RAISE EXCEPTION 'Audio activation guard blocked another bucket';
  END IF;
END $$;
RESET ROLE;
SET LOCAL ROLE anon;
DO $$ BEGIN
  IF EXISTS(SELECT 1 FROM storage.objects WHERE bucket_id='vocab-audio') THEN
    RAISE EXCEPTION 'Audio bucket exposed a clip to an anonymous client';
  END IF;
END $$;
ROLLBACK;
