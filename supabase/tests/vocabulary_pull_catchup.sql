BEGIN;
INSERT INTO auth.users(id,email,raw_user_meta_data) VALUES
  ('81700000-0000-0000-0000-000000000001','pull_a@example.invalid','{"username":"pull_a"}'),
  ('81700000-0000-0000-0000-000000000002','pull_b@example.invalid','{"username":"pull_b"}');
SELECT set_config('request.jwt.claim.sub','81700000-0000-0000-0000-000000000001',true);
SELECT set_config('request.method','POST',true);
SET LOCAL ROLE authenticated;

DO $$
DECLARE
  actor uuid := auth.uid();
  other_actor uuid := '81700000-0000-0000-0000-000000000002';
  writer uuid := '81700000-0000-0000-0000-000000000003';
  earlier_list uuid := '81700000-0000-0000-0000-000000000010';
  later_list uuid := '81700000-0000-0000-0000-000000000020';
  concept uuid := '81700000-0000-0000-0000-000000000021';
  variant uuid := '81700000-0000-0000-0000-000000000022';
  progress uuid := '81700000-0000-0000-0000-000000000023';
  caught_up bigint;
  initial bigint;
  canonical public.vocabulary_lists%ROWTYPE;
BEGIN
  IF NOT public.vocabulary_pull_catchup_ready()
    OR public.vocabulary_pull_revision(actor) IS DISTINCT FROM 0::bigint THEN
    RAISE EXCEPTION 'Account watermark unavailable';
  END IF;
  PERFORM set_config('request.headers', jsonb_build_object(
    'x-ponderin-sync-writer', writer, 'x-ponderin-sync-sequence', '1')::text, true);
  INSERT INTO public.vocabulary_lists(id,owner_id,name,description,visibility)
    VALUES(later_list,actor,'Canonical','Other device edit','public');
  INSERT INTO public.concepts(id,owner_id,list_id) VALUES(concept,actor,later_list);
  INSERT INTO public.word_variants(id,owner_id,concept_id,word,lang_code)
    VALUES(variant,actor,concept,'chat','fr');
  INSERT INTO public.variant_progress(id,user_id,variant_owner_id,variant_id,direction,reps)
    VALUES(progress,actor,actor,variant,'fr>ko',1);
  initial := public.vocabulary_pull_revision(actor);
  IF initial <> 4 THEN RAISE EXCEPTION 'Missing initial journal entries'; END IF;

  -- B's unchanged shared import acknowledges exactly the canonical row.
  -- It must still fence a PATCH with a smaller sequence arriving later.
  PERFORM set_config('request.headers', jsonb_build_object(
    'x-ponderin-sync-writer', writer, 'x-ponderin-sync-sequence', '3')::text, true);
  INSERT INTO public.vocabulary_lists(id,owner_id,name)
    VALUES(later_list,actor,'Baseline') ON CONFLICT(owner_id,id) DO NOTHING;
  UPDATE public.vocabulary_lists SET sync_write_protocol=16 WHERE id=later_list RETURNING * INTO canonical;
  IF NOT FOUND OR canonical.name <> 'Canonical' OR canonical.description <> 'Other device edit'
    OR canonical.visibility <> 'public' OR public.vocabulary_pull_revision(actor) <> initial THEN
    RAISE EXCEPTION 'Unchanged acknowledgement rewrote the canonical row';
  END IF;
  PERFORM set_config('request.headers', jsonb_build_object(
    'x-ponderin-sync-writer', writer, 'x-ponderin-sync-sequence', '2')::text, true);
  BEGIN
    UPDATE public.vocabulary_lists SET name='Timed out earlier' WHERE id=later_list;
    RAISE EXCEPTION 'Late PATCH passed an acknowledged no-op';
  EXCEPTION WHEN serialization_failure THEN NULL; END;

  PERFORM set_config('request.headers', jsonb_build_object(
    'x-ponderin-sync-writer', writer, 'x-ponderin-sync-sequence', '4')::text, true);
  UPDATE public.word_variants SET word='minou' WHERE id=variant;
  UPDATE public.variant_progress SET reps=2 WHERE id=progress;
  UPDATE public.vocabulary_lists SET is_deleted=true WHERE id=later_list;
  INSERT INTO public.vocabulary_lists(id,owner_id,name) VALUES(earlier_list,actor,'Behind UUID cursor');
  caught_up := public.vocabulary_pull_revision(actor);
  IF caught_up <> initial + 4 THEN RAISE EXCEPTION 'Missing later journal entries'; END IF;
  IF (SELECT count(*) FROM public.vocabulary_pull_changed_lists(actor,initial,caught_up)) <> 2
    OR NOT EXISTS (SELECT 1 FROM public.vocabulary_pull_changed_lists(actor,initial,caught_up)
      WHERE value->>'id'=later_list::text AND value->>'is_deleted'='true')
    OR NOT EXISTS (SELECT 1 FROM public.vocabulary_pull_changed_lists(actor,initial,caught_up)
      WHERE value->>'id'=earlier_list::text AND revision=caught_up)
    OR NOT EXISTS (SELECT 1 FROM public.vocabulary_pull_changed_progress(actor,initial,caught_up)
      WHERE value->>'id'=progress::text AND value->>'reps'='2') THEN
    RAISE EXCEPTION 'Catch-up missed deletion, insertion or progress';
  END IF;
  IF EXISTS (SELECT 1 FROM public.vocabulary_pull_changed_lists(actor,initial,initial+1))
    OR public.vocabulary_pull_revision(other_actor) IS NOT NULL
    OR EXISTS (SELECT 1 FROM public.vocabulary_pull_changed_lists(other_actor,0,caught_up))
    OR EXISTS (SELECT 1 FROM public.vocabulary_pull_changed_progress(other_actor,0,caught_up))
    THEN RAISE EXCEPTION 'Catch-up crossed a window or account boundary'; END IF;
END $$;

RESET ROLE;
DELETE FROM public.vocabulary_lists WHERE id='81700000-0000-0000-0000-000000000010';
SET LOCAL ROLE authenticated;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.vocabulary_pull_changed_lists(auth.uid(),0,999)
    WHERE value->>'id'='81700000-0000-0000-0000-000000000010'
      AND value->>'is_deleted'='true' AND value->>'name'='' AND NOT (value ? 'share_token'))
    THEN RAISE EXCEPTION 'Physical deletion did not leave a minimal tombstone'; END IF;
END $$;

RESET ROLE;
SELECT set_config('request.jwt.claim.sub','81700000-0000-0000-0000-000000000002',true);
SET LOCAL ROLE authenticated;
DO $$ BEGIN
  IF public.vocabulary_pull_revision(auth.uid()) <> 0
    OR EXISTS (SELECT 1 FROM public.vocabulary_pull_changed_lists(
      '81700000-0000-0000-0000-000000000001',0,999))
    THEN RAISE EXCEPTION 'Another account can read changed lists'; END IF;
END $$;
ROLLBACK;
