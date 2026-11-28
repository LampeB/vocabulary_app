-- A starter, an imported copy and their dependent rows may use the same
-- client IDs in different accounts. No fixture survives this suite.
BEGIN;
INSERT INTO auth.users(id,email,raw_user_meta_data,raw_app_meta_data) VALUES
  ('61000000-0000-0000-0000-000000000001','namespace_a@example.invalid',
    '{"username":"namespace_a"}',
    '{"e2e_managed_by":"vocabkr","e2e_scenario_id":"namespace.a"}'),
  ('61000000-0000-0000-0000-000000000002','namespace_b@example.invalid',
    '{"username":"namespace_b"}','{}'),
  ('61000000-0000-0000-0000-000000000003','namespace_c@example.invalid',
    '{"username":"namespace_c"}','{}');
SELECT public.enroll_e2e_account(
  '61000000-0000-0000-0000-000000000001','namespace.a','namespace_a'
);

SET LOCAL ROLE authenticated;
DO $$
DECLARE
  account uuid;
  starter_id uuid := '63000000-0000-5000-8000-000000000001';
  import_id uuid := '63000000-0000-5000-8000-000000000002';
  list_key uuid;
  concept_key uuid;
  variant_key uuid;
  progress_key uuid;
  seq int;
BEGIN
  FOREACH account IN ARRAY ARRAY[
    '61000000-0000-0000-0000-000000000001'::uuid,
    '61000000-0000-0000-0000-000000000002'::uuid
  ] LOOP
    PERFORM set_config('request.jwt.claim.sub', account::text, true);
    FOR seq IN 1..2 LOOP
      list_key := CASE seq WHEN 1 THEN starter_id ELSE import_id END;
      concept_key := ('64000000-0000-5000-8000-00000000000' || seq)::uuid;
      variant_key := ('65000000-0000-5000-8000-00000000000' || seq)::uuid;
      progress_key := ('66000000-0000-5000-8000-00000000000' || seq)::uuid;
      INSERT INTO public.vocabulary_lists(id,owner_id,name,origin,seed_id,imported_from_share_token)
      VALUES (list_key,auth.uid(),'Scoped list',
        CASE seq WHEN 1 THEN 'starter' ELSE 'user' END,
        CASE seq WHEN 1 THEN 'starter-greetings:fr>ko' END,
        CASE seq WHEN 2 THEN 'original-source-token' END)
      ON CONFLICT(owner_id,id) DO NOTHING;
      INSERT INTO public.concepts(id,owner_id,list_id,seed_id)
        VALUES(concept_key,auth.uid(),list_key,'hello')
      ON CONFLICT(owner_id,id) DO NOTHING;
      INSERT INTO public.word_variants(id,owner_id,concept_id,word,lang_code)
        VALUES(variant_key,auth.uid(),concept_key,'bonjour','fr')
      ON CONFLICT(owner_id,id) DO NOTHING;
      INSERT INTO public.variant_progress(id,user_id,variant_owner_id,variant_id,direction,reps)
        VALUES(progress_key,auth.uid(),auth.uid(),variant_key,'fr>ko',1)
      ON CONFLICT(user_id,variant_owner_id,variant_id,direction)
        DO UPDATE SET reps=excluded.reps;
    END LOOP;
    IF (SELECT count(*) FROM public.vocabulary_lists WHERE id IN (starter_id,import_id)) <> 2
      OR (SELECT count(*) FROM public.concepts) <> 2
      OR (SELECT count(*) FROM public.word_variants) <> 2
      OR (SELECT count(*) FROM public.variant_progress) <> 2 THEN
      RAISE EXCEPTION 'A catalogue or imported copy was blocked or leaked across owners';
    END IF;
  END LOOP;

  -- Account B can publish its list with its own content. RLS must not then
  -- make A's private children visible through the matching ID.
  UPDATE public.vocabulary_lists SET visibility='public' WHERE id=starter_id;
  INSERT INTO public.challenges(challenger_id,challenged_id,list_owner_id,list_id)
    VALUES(auth.uid(),'61000000-0000-0000-0000-000000000003',auth.uid(),starter_id);
  IF (SELECT count(*) FROM public.concepts WHERE list_id=starter_id) <> 1
    OR (SELECT count(*) FROM public.word_variants
        WHERE concept_id='64000000-0000-5000-8000-000000000001') <> 1 THEN
    RAISE EXCEPTION 'Public content changed visibility for another owner';
  END IF;

  PERFORM set_config('request.jwt.claim.sub','61000000-0000-0000-0000-000000000001',true);
  UPDATE public.vocabulary_lists SET is_deleted=true WHERE id=starter_id;
  PERFORM set_config('request.jwt.claim.sub','61000000-0000-0000-0000-000000000002',true);
  UPDATE public.word_variants SET word='salut'
    WHERE id='65000000-0000-5000-8000-000000000001';
  IF NOT EXISTS (
    SELECT 1 FROM public.word_variants
    WHERE owner_id=auth.uid() AND word='salut' AND is_deleted=false
  ) THEN
    RAISE EXCEPTION 'A different owner tombstone affected this write';
  END IF;
END $$;

SELECT set_config('request.jwt.claim.sub','61000000-0000-0000-0000-000000000001',true);
SELECT public.reset_e2e_account('namespace.a');
RESET ROLE;

DO $$ BEGIN
  IF (SELECT count(*) FROM public.vocabulary_lists) <> 2
    OR (SELECT count(*) FROM public.concepts) <> 2
    OR (SELECT count(*) FROM public.word_variants) <> 2
    OR (SELECT count(*) FROM public.variant_progress) <> 2
    OR (SELECT count(*) FROM public.challenges) <> 1 THEN
    RAISE EXCEPTION 'Reset crossed the vocabulary owner namespace';
  END IF;
END $$;
ROLLBACK;
