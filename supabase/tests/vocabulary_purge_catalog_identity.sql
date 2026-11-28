BEGIN;
SET LOCAL TIME ZONE 'UTC';
INSERT INTO auth.users(id,email,raw_user_meta_data) VALUES
  ('82600000-0000-4000-8000-000000000001','catalog_purge@example.invalid','{"username":"catalog_purge"}');

-- Earlier clients used arbitrary v4 IDs for these catalogue identities.
INSERT INTO public.vocabulary_lists
  (id,owner_id,name,description,origin,seed_id,lang_a,lang_b,created_at,updated_at)
VALUES
  ('82600000-0000-4000-8000-000000000010','82600000-0000-4000-8000-000000000001',
   'Legacy greetings',NULL,'starter','starter-greetings:fr>ko','fr','ko',
   '2026-11-27T00:00:00Z','2026-11-27T00:00:00Z'),
  ('82600000-0000-4000-8000-000000000020','82600000-0000-4000-8000-000000000001',
   'Purged numbers','Removed personal description','starter','starter-numbers-time:fr>ko','fr','ko',
   '2026-11-27T00:00:00Z','2026-11-27T00:00:00Z'),
  ('82600000-0000-4000-8000-000000000030','82600000-0000-4000-8000-000000000001',
   'Purged personal list','Removed personal description','user','starter-personal:fr>ko','fr','ko',
   '2026-11-27T00:00:00Z','2026-11-27T00:00:00Z');
INSERT INTO public.concepts(id,owner_id,list_id,seed_id,notes,created_at,updated_at) VALUES
  ('82600000-0000-4000-8000-000000000011','82600000-0000-4000-8000-000000000001',
   '82600000-0000-4000-8000-000000000010','bonjour','Removed personal notes',
   '2026-11-27T00:00:00Z','2026-11-27T00:00:00Z'),
  ('82600000-0000-4000-8000-000000000012','82600000-0000-4000-8000-000000000001',
   '82600000-0000-4000-8000-000000000010','merci',NULL,
   '2026-11-27T00:00:00Z','2026-11-27T00:00:00Z');
INSERT INTO public.word_variants(id,owner_id,concept_id,word,lang_code,example,created_at,updated_at) VALUES
  ('82600000-0000-4000-8000-000000000013','82600000-0000-4000-8000-000000000001',
   '82600000-0000-4000-8000-000000000012','감사합니다','ko','Removed personal example',
   '2026-11-27T00:00:00Z','2026-11-27T00:00:00Z');

DO $$ BEGIN
  PERFORM set_config('test.catalog_before',(SELECT revision::text FROM vocabulary_private.pull_watermarks
    WHERE owner_id='82600000-0000-4000-8000-000000000001'),true);
END $$;
DELETE FROM public.word_variants WHERE id='82600000-0000-4000-8000-000000000013';
DELETE FROM public.concepts WHERE id='82600000-0000-4000-8000-000000000011';
DELETE FROM public.vocabulary_lists WHERE id IN ('82600000-0000-4000-8000-000000000020',
                                                '82600000-0000-4000-8000-000000000030');

DO $$ BEGIN
  PERFORM set_config('request.jwt.claim.sub','82600000-0000-4000-8000-000000000001',true);
END $$;
SET LOCAL ROLE authenticated;
DO $$
DECLARE
  greetings uuid := '82600000-0000-4000-8000-000000000010';
  concept uuid := '82600000-0000-4000-8000-000000000011';
  variant uuid := '82600000-0000-4000-8000-000000000013';
  numbers uuid := '82600000-0000-4000-8000-000000000020';
  private_list uuid := '82600000-0000-4000-8000-000000000030';
  before_purge bigint := current_setting('test.catalog_before')::bigint;
  after_purge bigint := public.vocabulary_pull_revision(auth.uid());
BEGIN
  IF NOT public.vocabulary_purge_catalog_ready()
    OR NOT EXISTS (SELECT 1 FROM public.vocabulary_pull_inventory(auth.uid(),NULL)
      WHERE id=numbers AND is_deleted AND origin='starter' AND seed_id='starter-numbers-time:fr>ko'
        AND lang_a='fr' AND lang_b='ko' AND name='' AND description IS NULL)
    OR NOT EXISTS (SELECT 1 FROM public.vocabulary_pull_inventory(auth.uid(),NULL)
      WHERE id=private_list AND is_deleted AND seed_id IS NULL AND description IS NULL)
    OR NOT EXISTS (SELECT 1 FROM public.vocabulary_pull_changed_lists(auth.uid(),before_purge,after_purge)
      WHERE value->>'id'=numbers::text AND value->>'seed_id'='starter-numbers-time:fr>ko')
    OR NOT EXISTS (SELECT 1 FROM public.vocabulary_pull_changed_lists(auth.uid(),before_purge,after_purge)
      WHERE value->>'id'=greetings::text AND value->>'is_deleted'='false')
    OR NOT EXISTS (SELECT 1 FROM public.vocabulary_pull_concepts(auth.uid(),greetings,NULL)
      WHERE id=concept AND value->>'seed_id'='bonjour' AND value->>'is_deleted'='true' AND NOT (value ? 'notes'))
    OR public.vocabulary_purge_ack(auth.uid(),'variant',variant,NULL)->>'lang_code' IS DISTINCT FROM 'ko'
    OR public.vocabulary_purge_ack(auth.uid(),'variant',variant,NULL) ? 'word'
    OR public.vocabulary_purge_ack(auth.uid(),'variant',variant,NULL) ? 'example'
  THEN RAISE EXCEPTION 'Purge lost a starter key or retained original content'; END IF;
END $$;

-- The Flutter regression consumes this exact initial RPC payload in empty SQLite.
SELECT jsonb_build_object(
  'ownerId',auth.uid(),
  'lists',(SELECT jsonb_agg(to_jsonb(l) ORDER BY l.id) FROM public.vocabulary_pull_inventory(auth.uid(),NULL) l),
  'concepts',(SELECT jsonb_agg(c.value ORDER BY c.id) FROM public.vocabulary_pull_concepts(
    auth.uid(),'82600000-0000-4000-8000-000000000010',NULL) c)
) AS starter_catalog_purge_fixture;

RESET ROLE;
ALTER TABLE public.concepts DISABLE TRIGGER zz_vocabulary_purge_catalog;
DO $$ BEGIN
  IF public.vocabulary_purge_catalog_ready()
    THEN RAISE EXCEPTION 'A disabled catalogue guard left the capability enabled'; END IF;
END $$;
ROLLBACK;
