-- Disposable database only. Exercise Postgres privileges, RLS and the real FK.
BEGIN;
INSERT INTO auth.users(id,email) VALUES
  ('18000000-0000-4000-8000-000000000001','boundary-owner@example.invalid'),
  ('18000000-0000-4000-8000-000000000002','boundary-learner@example.invalid'),
  ('18000000-0000-4000-8000-000000000003','boundary-collision@example.invalid');
INSERT INTO public.vocabulary_lists(owner_id,id,name,visibility) VALUES
  ('18000000-0000-4000-8000-000000000001','18000000-0000-4000-8000-000000000011','Hidden','private'),
  ('18000000-0000-4000-8000-000000000001','18000000-0000-4000-8000-000000000012','Shared','public'),
  ('18000000-0000-4000-8000-000000000002','18000000-0000-4000-8000-000000000013','Owned','private'),
  ('18000000-0000-4000-8000-000000000003','18000000-0000-4000-8000-000000000014','Collision','private');
INSERT INTO public.concepts(owner_id,list_id,id) VALUES
  ('18000000-0000-4000-8000-000000000001','18000000-0000-4000-8000-000000000011','18000000-0000-4000-8000-000000000021'),
  ('18000000-0000-4000-8000-000000000001','18000000-0000-4000-8000-000000000012','18000000-0000-4000-8000-000000000022'),
  ('18000000-0000-4000-8000-000000000002','18000000-0000-4000-8000-000000000013','18000000-0000-4000-8000-000000000023'),
  ('18000000-0000-4000-8000-000000000003','18000000-0000-4000-8000-000000000014','18000000-0000-4000-8000-000000000024');
INSERT INTO public.word_variants(owner_id,concept_id,id,word,lang_code) VALUES
  ('18000000-0000-4000-8000-000000000001','18000000-0000-4000-8000-000000000021','18000000-0000-4000-8000-000000000031','hidden','en'),
  ('18000000-0000-4000-8000-000000000001','18000000-0000-4000-8000-000000000022','18000000-0000-4000-8000-000000000032','shared','en'),
  ('18000000-0000-4000-8000-000000000002','18000000-0000-4000-8000-000000000023','18000000-0000-4000-8000-000000000033','owned','en'),
  ('18000000-0000-4000-8000-000000000003','18000000-0000-4000-8000-000000000024','18000000-0000-4000-8000-000000000032','collision','en');
-- Legacy history made before the access guard was installed.
INSERT INTO public.variant_progress(user_id,variant_owner_id,variant_id,direction) VALUES
  ('18000000-0000-4000-8000-000000000002','18000000-0000-4000-8000-000000000001',
    '18000000-0000-4000-8000-000000000031','en>ko');

SELECT set_config('request.jwt.claim.sub', '18000000-0000-4000-8000-000000000002', true);
SET LOCAL ROLE authenticated;
DO $$
DECLARE
  owner uuid := '18000000-0000-4000-8000-000000000001';
  hidden uuid := '18000000-0000-4000-8000-000000000031';
  shared uuid := '18000000-0000-4000-8000-000000000032';
  owned uuid := '18000000-0000-4000-8000-000000000033';
  missing uuid := '18000000-0000-4000-8000-000000000034';
  probed uuid;
  resolved_owner uuid;
BEGIN
  INSERT INTO public.variant_progress(user_id,variant_owner_id,variant_id,direction)
    VALUES (auth.uid(),auth.uid(),owned,'en>fr');
  -- An invisible collision must have no effect on legacy owner resolution.
  INSERT INTO public.variant_progress(user_id,variant_id,direction)
    VALUES (auth.uid(),shared,'en>fr') RETURNING variant_owner_id INTO resolved_owner;
  IF resolved_owner IS DISTINCT FROM owner THEN RAISE EXCEPTION 'Public variant did not resolve'; END IF;
  FOREACH probed IN ARRAY ARRAY[hidden,missing] LOOP
    BEGIN
      INSERT INTO public.variant_progress(user_id,variant_owner_id,variant_id,direction)
        VALUES (auth.uid(),owner,probed,'en>fr');
      RAISE EXCEPTION 'Unauthorized progress accepted';
    EXCEPTION WHEN insufficient_privilege THEN
      IF SQLERRM <> 'Vocabulary variant unavailable' THEN RAISE; END IF;
    END;
    BEGIN
      UPDATE public.variant_progress SET variant_owner_id=owner, variant_id=probed
        WHERE user_id=auth.uid() AND variant_id=owned;
      RAISE EXCEPTION 'Unauthorized progress retarget accepted';
    EXCEPTION WHEN insufficient_privilege THEN
      IF SQLERRM <> 'Vocabulary variant unavailable' THEN RAISE; END IF;
    END;
  END LOOP;
  UPDATE public.variant_progress SET reps=2 WHERE variant_id=hidden AND direction='en>ko';
  IF NOT FOUND THEN RAISE EXCEPTION 'Non-reference update to existing history failed'; END IF;
  INSERT INTO public.variant_progress(user_id,variant_owner_id,variant_id,direction,reps)
    VALUES (auth.uid(),owner,hidden,'en>ko',3)
    ON CONFLICT(user_id,variant_owner_id,variant_id,direction) DO UPDATE SET reps=excluded.reps;
  IF NOT EXISTS (SELECT 1 FROM public.variant_progress WHERE variant_id=hidden AND reps=3) THEN
    RAISE EXCEPTION 'Existing history upsert failed after visibility was lost';
  END IF;
END $$;
RESET ROLE;

DO $$
DECLARE target text;
BEGIN
  FOREACH target IN ARRAY ARRAY['vocabulary_lists','concepts','word_variants'] LOOP
    IF has_table_privilege('authenticated', 'public.'||target, 'DELETE,TRUNCATE')
      OR has_table_privilege('anon', 'public.'||target, 'DELETE,TRUNCATE') THEN
      RAISE EXCEPTION 'Physical removal is still granted on %', target;
    END IF;
  END LOOP;
END $$;
-- A broad grant must not override the restrictive policy either.
GRANT DELETE ON public.vocabulary_lists, public.concepts, public.word_variants TO authenticated;
SELECT set_config('request.jwt.claim.sub', '18000000-0000-4000-8000-000000000001', true);
SET LOCAL ROLE authenticated;
DO $$
DECLARE
  shared_list uuid := '18000000-0000-4000-8000-000000000012';
  shared_concept uuid := '18000000-0000-4000-8000-000000000022';
  shared_variant uuid := '18000000-0000-4000-8000-000000000032';
BEGIN
  UPDATE public.word_variants SET is_deleted=true WHERE id=shared_variant;
  UPDATE public.concepts SET is_deleted=true WHERE id=shared_concept;
  UPDATE public.vocabulary_lists SET is_deleted=true WHERE id=shared_list;
  DELETE FROM public.word_variants WHERE id=shared_variant;
  IF FOUND THEN RAISE EXCEPTION 'Client physically removed a variant tombstone'; END IF;
  DELETE FROM public.concepts WHERE id=shared_concept;
  IF FOUND THEN RAISE EXCEPTION 'Client physically removed a concept tombstone'; END IF;
  DELETE FROM public.vocabulary_lists WHERE id=shared_list;
  IF FOUND THEN RAISE EXCEPTION 'Client physically removed a list tombstone'; END IF;

  INSERT INTO public.vocabulary_lists(owner_id,id,name,is_deleted)
    VALUES(auth.uid(),shared_list,'stale',false)
    ON CONFLICT(owner_id,id) DO UPDATE SET name=excluded.name,is_deleted=excluded.is_deleted;
  IF NOT EXISTS (SELECT 1 FROM public.vocabulary_lists
      WHERE owner_id=auth.uid() AND id=shared_list AND is_deleted AND name='Shared') THEN
    RAISE EXCEPTION 'Stale write restored the deleted list';
  END IF;
  INSERT INTO public.concepts(owner_id,id,list_id,is_deleted)
    VALUES(auth.uid(),shared_concept,shared_list,false)
    ON CONFLICT(owner_id,id) DO UPDATE SET is_deleted=excluded.is_deleted;
  IF NOT EXISTS (SELECT 1 FROM public.concepts
      WHERE owner_id=auth.uid() AND id=shared_concept AND is_deleted) THEN
    RAISE EXCEPTION 'Stale write restored the deleted concept';
  END IF;
  INSERT INTO public.word_variants(owner_id,id,concept_id,word,lang_code,is_deleted)
    VALUES(auth.uid(),shared_variant,shared_concept,'stale','en',false)
    ON CONFLICT(owner_id,id) DO UPDATE SET word=excluded.word,is_deleted=excluded.is_deleted;
  IF NOT EXISTS (SELECT 1 FROM public.word_variants
      WHERE owner_id=auth.uid() AND id=shared_variant AND is_deleted AND word='shared') THEN
    RAISE EXCEPTION 'Stale write restored the deleted variant';
  END IF;
END $$;
RESET ROLE;
SELECT set_config('request.jwt.claim.sub', '18000000-0000-4000-8000-000000000002', true);
SET LOCAL ROLE authenticated;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.variant_progress
      WHERE variant_id='18000000-0000-4000-8000-000000000032' AND user_id=auth.uid()) THEN
    RAISE EXCEPTION 'Client physical removal lost another learner''s history';
  END IF;
  BEGIN
    INSERT INTO public.variant_progress(user_id,variant_owner_id,variant_id,direction)
      VALUES(auth.uid(),'18000000-0000-4000-8000-000000000001','18000000-0000-4000-8000-000000000032','en>ko');
    RAISE EXCEPTION 'Progress was added to a deleted branch';
  EXCEPTION WHEN insufficient_privilege THEN
    IF SQLERRM <> 'Vocabulary variant unavailable' THEN RAISE; END IF;
  END;
END $$;
RESET ROLE;
SET LOCAL ROLE service_role;
DELETE FROM public.vocabulary_lists WHERE id='18000000-0000-4000-8000-000000000012';
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM public.variant_progress WHERE
      variant_owner_id='18000000-0000-4000-8000-000000000001'
      AND variant_id='18000000-0000-4000-8000-000000000032') THEN
    RAISE EXCEPTION 'Authorized server purge did not cascade';
  END IF;
END $$;
ROLLBACK;
