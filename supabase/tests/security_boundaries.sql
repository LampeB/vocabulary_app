-- Disposable database only, after production migrations including 012.
BEGIN;
INSERT INTO auth.users(id,email,raw_user_meta_data) VALUES
 ('00000000-0000-0000-0000-000000000001','security_a@example.invalid','{"username":"security_a"}'),
 ('00000000-0000-0000-0000-000000000002','security_b@example.invalid','{"username":"security_b"}');
INSERT INTO public.vocabulary_lists(id,owner_id,name,visibility,share_token) VALUES
 ('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','Public A','public','public-a'),
 ('10000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000002','Private B','private',NULL);
INSERT INTO public.concepts(id,list_id) VALUES
 ('20000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001'),
 ('20000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000002');
INSERT INTO public.word_variants(id,concept_id,word,lang_code,audio_path) VALUES
 ('30000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','public','en',NULL),
 ('30000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000002','private','en',
  'users/00000000-0000-0000-0000-000000000001/private.mp3');
INSERT INTO storage.buckets(id,name,public) VALUES ('other','other',false);
INSERT INTO storage.objects(bucket_id,name) VALUES
 ('vocab-audio','users/00000000-0000-0000-0000-000000000001/private.mp3'),
 ('vocab-audio','users/00000000-0000-0000-0000-000000000002/own.mp3'),
 ('vocab-audio','seed/v1/en/published.mp3'),
 ('vocab-audio','seed/v1/en/legacy-private.mp3'),
 ('other','unrelated.mp3');
INSERT INTO public.published_audio_assets VALUES ('seed/v1/en/published.mp3');
SET LOCAL ROLE anon;
DO $$ BEGIN
  IF EXISTS(SELECT 1 FROM storage.objects WHERE bucket_id='vocab-audio') THEN
    RAISE EXCEPTION 'Pre-existing Storage rule exposed audio to an anonymous reader';
  END IF;
  IF NOT EXISTS(SELECT 1 FROM storage.objects WHERE bucket_id='other') THEN
    RAISE EXCEPTION 'Audio policy blocked anonymous access to another bucket';
  END IF;
END $$;
RESET ROLE;
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000002',true);
SET LOCAL ROLE authenticated;
DO $$ DECLARE changed integer; BEGIN
  IF (SELECT count(*) FROM public.concepts WHERE list_id='10000000-0000-0000-0000-000000000001') <> 1
    OR (SELECT count(*) FROM public.word_variants WHERE concept_id='20000000-0000-0000-0000-000000000001') <> 1 THEN
    RAISE EXCEPTION 'Shared active content is not readable by second account';
  END IF;
  UPDATE public.word_variants SET word='attacked' WHERE id='30000000-0000-0000-0000-000000000001';
  GET DIAGNOSTICS changed = ROW_COUNT;
  IF changed <> 0 THEN RAISE EXCEPTION 'Public reader can write owner content'; END IF;
  IF EXISTS(SELECT 1 FROM storage.objects WHERE name LIKE 'users/00000000-0000-0000-0000-000000000001/%') THEN
    RAISE EXCEPTION 'Forged variant path permits private audio theft';
  END IF;
  IF (SELECT count(*) FROM storage.objects WHERE bucket_id='vocab-audio' AND
      name IN ('users/00000000-0000-0000-0000-000000000002/own.mp3','seed/v1/en/published.mp3')) <> 2 THEN
    RAISE EXCEPTION 'Own/published audio inaccessible';
  END IF;
  IF NOT EXISTS(SELECT 1 FROM storage.objects WHERE bucket_id='other') THEN
    RAISE EXCEPTION 'Audio policy blocked authenticated access to another bucket';
  END IF;
  IF EXISTS(SELECT 1 FROM storage.objects WHERE name='seed/v1/en/legacy-private.mp3') THEN
    RAISE EXCEPTION 'Unmanifested legacy seed asset is public';
  END IF;
  INSERT INTO public.review_events(id,user_id,variant_id,direction,mode,correct,rating)
  VALUES('40000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000002','grammar-synthetic','en>fr','typing',true,'good');
  BEGIN
    INSERT INTO public.review_events(id,user_id,variant_id,direction,mode,correct,rating)
    VALUES('40000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000001','foreign','en>fr','typing',true,'good');
    RAISE EXCEPTION 'Review event ownership bypassed';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
UPDATE public.vocabulary_lists SET is_deleted=true WHERE id='10000000-0000-0000-0000-000000000001';
SET LOCAL ROLE authenticated;
DO $$ BEGIN
  IF EXISTS(SELECT 1 FROM public.vocabulary_lists WHERE share_token='public-a')
    OR EXISTS(SELECT 1 FROM public.concepts WHERE id='20000000-0000-0000-0000-000000000001')
    OR EXISTS(SELECT 1 FROM public.word_variants WHERE id='30000000-0000-0000-0000-000000000001') THEN
    RAISE EXCEPTION 'Deleted public content remains readable';
  END IF;
  IF has_function_privilege('authenticated','public.acquire_audio_generation(uuid,text)','EXECUTE') THEN
    RAISE EXCEPTION 'Client can acquire arbitrary audio generation leases';
  END IF;
END $$;
RESET ROLE;
DO $$ DECLARE lease uuid; next_lease uuid; path text := 'users/00000000-0000-0000-0000-000000000002/v/hash.mp3'; BEGIN
  lease := public.acquire_audio_generation('00000000-0000-0000-0000-000000000002',path);
  IF lease IS NULL OR public.acquire_audio_generation('00000000-0000-0000-0000-000000000002',path) IS NOT NULL THEN
    RAISE EXCEPTION 'Concurrent paid render admitted';
  END IF;
  PERFORM public.release_audio_generation(path,gen_random_uuid());
  IF public.acquire_audio_generation('00000000-0000-0000-0000-000000000002',path) IS NOT NULL THEN
    RAISE EXCEPTION 'Wrong release token removed audio lease';
  END IF;
  PERFORM public.release_audio_generation(path,lease);
  next_lease := public.acquire_audio_generation('00000000-0000-0000-0000-000000000002',path);
  IF next_lease IS NULL THEN RAISE EXCEPTION 'Released render cannot retry'; END IF;
  BEGIN
    PERFORM public.acquire_audio_generation('00000000-0000-0000-0000-000000000002','seed/v1/en/private.mp3');
    RAISE EXCEPTION 'Private generation can enter shared namespace';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
ROLLBACK;
