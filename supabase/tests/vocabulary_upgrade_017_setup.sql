BEGIN;
INSERT INTO auth.users(id,email,raw_user_meta_data) VALUES
  ('82000000-0000-0000-0000-000000000001','legacy_inventory@example.invalid','{"username":"legacy_inventory"}');
INSERT INTO public.vocabulary_lists(id,owner_id,name) VALUES
  ('82000000-0000-0000-0000-000000000010','82000000-0000-0000-0000-000000000001','Purged before upgrade'),
  ('82000000-0000-0000-0000-000000000020','82000000-0000-0000-0000-000000000001','Retained after upgrade');
INSERT INTO public.concepts(id,owner_id,list_id) VALUES
  ('82000000-0000-0000-0000-000000000021','82000000-0000-0000-0000-000000000001','82000000-0000-0000-0000-000000000020');
INSERT INTO public.word_variants(id,owner_id,concept_id,word,lang_code) VALUES
  ('82000000-0000-0000-0000-000000000022','82000000-0000-0000-0000-000000000001','82000000-0000-0000-0000-000000000021','bonjour','fr');
INSERT INTO public.variant_progress(id,user_id,variant_owner_id,variant_id,direction,reps) VALUES
  ('82000000-0000-0000-0000-000000000023','82000000-0000-0000-0000-000000000001',
   '82000000-0000-0000-0000-000000000001','82000000-0000-0000-0000-000000000022','fr>ko',4);
DELETE FROM public.vocabulary_lists WHERE id='82000000-0000-0000-0000-000000000010';
DO $$ BEGIN
  IF to_regprocedure('public.vocabulary_pull_inventory(uuid,uuid)') IS NOT NULL
    OR NOT EXISTS (SELECT 1 FROM vocabulary_private.pull_watermarks
      WHERE owner_id='82000000-0000-0000-0000-000000000001' AND revision=6)
    THEN RAISE EXCEPTION 'Historical 017 with its populated journal was not installed'; END IF;
END $$;
COMMIT;

