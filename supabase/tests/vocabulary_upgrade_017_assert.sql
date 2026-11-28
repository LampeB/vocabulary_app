BEGIN;
SELECT set_config('request.jwt.claim.sub','82000000-0000-0000-0000-000000000001',true);
SELECT set_config('request.method','POST',true);
SELECT set_config('request.headers',
  '{"x-ponderin-sync-writer":"82000000-0000-0000-0000-000000000002","x-ponderin-sync-sequence":"1"}',true);
SET LOCAL ROLE authenticated;
DO $$
DECLARE
  purged uuid := '82000000-0000-0000-0000-000000000010';
  retained uuid := '82000000-0000-0000-0000-000000000020';
  concept uuid := '82000000-0000-0000-0000-000000000021';
BEGIN
  IF NOT public.vocabulary_purge_ready()
    OR public.vocabulary_pull_revision(auth.uid()) <> 6
    OR NOT EXISTS (SELECT 1 FROM public.vocabulary_pull_inventory(auth.uid(),NULL)
      WHERE id=purged AND is_deleted AND name='')
    OR NOT EXISTS (SELECT 1 FROM public.vocabulary_pull_inventory(auth.uid(),purged)
      WHERE id=retained AND NOT is_deleted AND name='Retained after upgrade')
    OR NOT EXISTS (SELECT 1 FROM public.vocabulary_pull_concepts(auth.uid(),retained,NULL)
      WHERE id=concept AND value#>>'{word_variants,0,word}'='bonjour')
    OR NOT EXISTS (SELECT 1 FROM public.vocabulary_pull_changed_progress(auth.uid(),0,6)
      WHERE value->>'reps'='4')
    THEN RAISE EXCEPTION 'Forward repair did not preserve 017 vocabulary, progress or journal'; END IF;
  BEGIN
    INSERT INTO public.vocabulary_lists(id,owner_id,name,sync_write_protocol)
      VALUES(purged,auth.uid(),'Old client replay',16);
    RAISE EXCEPTION 'Historical purge was not fenced';
  EXCEPTION WHEN SQLSTATE 'PV001' THEN NULL; END;
END $$;
ROLLBACK;
