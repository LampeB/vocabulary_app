BEGIN;
INSERT INTO auth.users(id,email,raw_user_meta_data) VALUES
  ('82400000-0000-0000-0000-000000000001','purges_a@example.invalid','{"username":"purges_a"}'),
  ('82400000-0000-0000-0000-000000000002','purges_b@example.invalid','{"username":"purges_b"}');
INSERT INTO public.vocabulary_lists(id,owner_id,name) VALUES
  ('82400000-0000-0000-0000-000000000010','82400000-0000-0000-0000-000000000001','Retained'),
  ('82400000-0000-0000-0000-000000000020','82400000-0000-0000-0000-000000000001','Purged');
INSERT INTO public.concepts(id,owner_id,list_id,notes) VALUES
  ('82400000-0000-0000-0000-000000000011','82400000-0000-0000-0000-000000000001','82400000-0000-0000-0000-000000000010','Concept text to erase'),
  ('82400000-0000-0000-0000-000000000012','82400000-0000-0000-0000-000000000001','82400000-0000-0000-0000-000000000010','Retained concept');
INSERT INTO public.word_variants(id,owner_id,concept_id,word,lang_code) VALUES
  ('82400000-0000-0000-0000-000000000013','82400000-0000-0000-0000-000000000001','82400000-0000-0000-0000-000000000011','effacé','fr'),
  ('82400000-0000-0000-0000-000000000014','82400000-0000-0000-0000-000000000001','82400000-0000-0000-0000-000000000012','mot supprimé','fr'),
  ('82400000-0000-0000-0000-000000000015','82400000-0000-0000-0000-000000000001','82400000-0000-0000-0000-000000000012','bonjour','fr');
INSERT INTO public.variant_progress(id,user_id,variant_owner_id,variant_id,direction,reps) VALUES
  ('82400000-0000-0000-0000-000000000016','82400000-0000-0000-0000-000000000001','82400000-0000-0000-0000-000000000001','82400000-0000-0000-0000-000000000013','fr>ko',2),
  ('82400000-0000-0000-0000-000000000017','82400000-0000-0000-0000-000000000001','82400000-0000-0000-0000-000000000001','82400000-0000-0000-0000-000000000014','fr>ko',3);
SELECT set_config('test.vocabulary_revision',(SELECT revision::text FROM vocabulary_private.pull_watermarks
  WHERE owner_id='82400000-0000-0000-0000-000000000001'),true);

DELETE FROM public.concepts WHERE id='82400000-0000-0000-0000-000000000011';
DELETE FROM public.word_variants WHERE id='82400000-0000-0000-0000-000000000014';
DELETE FROM public.vocabulary_lists WHERE id='82400000-0000-0000-0000-000000000020';

SELECT set_config('request.jwt.claim.sub','82400000-0000-0000-0000-000000000001',true);
SELECT set_config('request.method','POST',true);
SELECT set_config('request.headers',
  '{"x-ponderin-sync-writer":"82400000-0000-0000-0000-000000000009","x-ponderin-sync-sequence":"1"}',true);
SET LOCAL ROLE authenticated;
DO $$
DECLARE
  actor uuid := auth.uid();
  other_owner uuid := '82400000-0000-0000-0000-000000000002';
  retained uuid := '82400000-0000-0000-0000-000000000010';
  purged_list uuid := '82400000-0000-0000-0000-000000000020';
  purged_concept uuid := '82400000-0000-0000-0000-000000000011';
  retained_concept uuid := '82400000-0000-0000-0000-000000000012';
  cascade_variant uuid := '82400000-0000-0000-0000-000000000013';
  purged_variant uuid := '82400000-0000-0000-0000-000000000014';
  before_purges bigint := current_setting('test.vocabulary_revision')::bigint;
  after_purges bigint := public.vocabulary_pull_revision(actor);
  replay text;
BEGIN
  IF NOT public.vocabulary_purge_ready()
    OR NOT EXISTS (SELECT 1 FROM public.vocabulary_pull_changed_lists(actor,before_purges,after_purges)
      WHERE value->>'id'=retained::text AND value->>'is_deleted'='false')
    OR NOT EXISTS (SELECT 1 FROM public.vocabulary_pull_concepts(actor,retained,NULL)
      WHERE id=purged_concept AND value->>'is_deleted'='true'
        AND value->>'list_id'=retained::text AND NOT (value ? 'notes'))
    OR NOT EXISTS (SELECT 1 FROM public.vocabulary_pull_concepts(actor,retained,purged_concept)
      WHERE id=retained_concept
        AND value->'word_variants' @> jsonb_build_array(jsonb_build_object('id',purged_variant,'is_deleted',true))
        AND value->'word_variants' @> '[{"word":"bonjour","is_deleted":false}]')
    OR EXISTS (SELECT 1 FROM public.vocabulary_pull_concepts(actor,retained,purged_concept)
      WHERE id=purged_concept)
    OR EXISTS (SELECT 1 FROM public.variant_progress)
    THEN RAISE EXCEPTION 'Child purges did not propagate into inventory and delta'; END IF;

  FOREACH replay IN ARRAY ARRAY[
    format('INSERT INTO public.vocabulary_lists(id,owner_id,name) VALUES(%L,auth.uid(),%L)
      ON CONFLICT(owner_id,id) DO UPDATE SET name=excluded.name',purged_list,'Late list edit'),
    format('INSERT INTO public.concepts(id,owner_id,list_id) VALUES(%L,auth.uid(),%L)
      ON CONFLICT(owner_id,id) DO UPDATE SET notes=excluded.notes',purged_concept,retained),
    format('INSERT INTO public.word_variants(id,owner_id,concept_id,word,lang_code)
      VALUES(%L,auth.uid(),%L,%L,%L) ON CONFLICT(owner_id,id) DO UPDATE SET word=excluded.word',
      purged_variant,retained_concept,'Late word edit','fr')
  ] LOOP
    BEGIN
      EXECUTE replay;
      RAISE EXCEPTION 'Purged identity was resurrected';
    EXCEPTION WHEN SQLSTATE 'PV001' THEN NULL; END;
  END LOOP;
  BEGIN
    UPDATE public.vocabulary_lists SET id=purged_list WHERE id=retained;
    RAISE EXCEPTION 'A live ID could move into a purged identity';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;

  IF public.vocabulary_pull_revision(actor) <> after_purges
    OR EXISTS (SELECT 1 FROM public.vocabulary_lists WHERE id=purged_list)
    OR (SELECT count(*) FROM public.vocabulary_pull_inventory(actor,NULL)
      WHERE id=purged_list AND is_deleted AND name='') <> 1
    OR public.vocabulary_purge_ack(actor,'list',purged_list,NULL)->>'is_deleted' IS DISTINCT FROM 'true'
    OR public.vocabulary_purge_ack(actor,'variant',cascade_variant,purged_concept)
      #>>'{_sync_deleted_concept,id}' IS DISTINCT FROM purged_concept::text
    OR public.vocabulary_purge_ack(actor,'variant',purged_variant,retained_concept)->>'word' IS NOT NULL
    OR public.vocabulary_purge_ack(other_owner,'list',purged_list,NULL) IS NOT NULL
    THEN RAISE EXCEPTION 'Replay changed the purge or returned a noncanonical acknowledgement'; END IF;
END $$;

RESET ROLE;
SELECT set_config('request.jwt.claim.sub','82400000-0000-0000-0000-000000000002',true);
SET LOCAL ROLE authenticated;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM public.vocabulary_pull_concepts(
      '82400000-0000-0000-0000-000000000001','82400000-0000-0000-0000-000000000010',NULL))
    OR public.vocabulary_purge_ack('82400000-0000-0000-0000-000000000001','list',
      '82400000-0000-0000-0000-000000000020',NULL) IS NOT NULL
    THEN RAISE EXCEPTION 'A foreign owner could read a purge'; END IF;
END $$;
-- The same UUID remains available to its own account.
INSERT INTO public.vocabulary_lists(id,owner_id,name)
  VALUES('82400000-0000-0000-0000-000000000020',auth.uid(),'Independent namespace');
ROLLBACK;
