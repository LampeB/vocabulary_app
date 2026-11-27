-- Disposable database only. Run both after 007 and with the final 012 policies.
BEGIN;
INSERT INTO storage.buckets(id,name,public) VALUES ('other','other',false);
SET LOCAL ROLE service_role;
INSERT INTO storage.objects(bucket_id,name) VALUES
 ('vocab-audio','seed/v1/en/published.mp3'),
 ('vocab-audio','users/00000000-0000-0000-0000-000000000001/own.mp3');
DO $$ BEGIN
  IF to_regclass('public.published_audio_assets') IS NOT NULL THEN
    INSERT INTO public.published_audio_assets(path) VALUES ('seed/v1/en/published.mp3');
  END IF;
END $$;
RESET ROLE;

SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
DO $$ DECLARE actor text; changed integer; BEGIN
  FOREACH actor IN ARRAY ARRAY['anon','authenticated'] LOOP
    EXECUTE format('SET LOCAL ROLE %I', actor);
    BEGIN
      INSERT INTO storage.objects(bucket_id,name) VALUES ('vocab-audio','client-created.mp3');
      RAISE EXCEPTION '% inserted audio through a permissive policy', actor;
    EXCEPTION WHEN insufficient_privilege THEN NULL; END;

    INSERT INTO storage.objects(bucket_id,name) VALUES ('other','other.mp3');
    BEGIN
      UPDATE storage.objects SET bucket_id='vocab-audio' WHERE bucket_id='other';
      RAISE EXCEPTION '% moved another bucket object into vocab-audio', actor;
    EXCEPTION WHEN insufficient_privilege THEN NULL; END;

    UPDATE storage.objects SET name='renamed.mp3';
    GET DIAGNOSTICS changed = ROW_COUNT;
    IF changed <> 1 THEN RAISE EXCEPTION '% changed private audio or lost access to another bucket', actor; END IF;

    DELETE FROM storage.objects;
    GET DIAGNOSTICS changed = ROW_COUNT;
    IF changed <> 1 THEN RAISE EXCEPTION '% deleted private audio or lost access to another bucket', actor; END IF;
    EXECUTE 'RESET ROLE';
  END LOOP;
END $$;

DO $$ BEGIN
  IF (SELECT count(*) FROM storage.objects WHERE bucket_id='vocab-audio' AND name IN (
    'seed/v1/en/published.mp3','users/00000000-0000-0000-0000-000000000001/own.mp3')) <> 2 THEN
    RAISE EXCEPTION 'Client writes changed a published or owner-readable audio object';
  END IF;
END $$;
ROLLBACK;
