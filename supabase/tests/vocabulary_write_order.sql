BEGIN;
INSERT INTO auth.users(id,email,raw_user_meta_data,raw_app_meta_data) VALUES
 ('81000000-0000-0000-0000-000000000001','write_order@example.invalid',
  '{"username":"write_order"}','{"e2e_managed_by":"vocabkr","e2e_scenario_id":"write.order"}');
SELECT public.enroll_e2e_account(
  '81000000-0000-0000-0000-000000000001','write.order','write_order'
);
DO $$ BEGIN
  IF NOT public.vocabulary_sync_write_ready() THEN
    RAISE EXCEPTION 'The installed write fence is unavailable';
  END IF;
END $$;

SELECT set_config('request.jwt.claim.sub','81000000-0000-0000-0000-000000000001',true);
SELECT set_config('request.method','POST',true);
SET LOCAL ROLE authenticated;

DO $$
DECLARE
  list_id uuid := '81000000-0000-0000-0000-000000000002';
  concept_id uuid := '81000000-0000-0000-0000-000000000003';
  variant_id uuid := '81000000-0000-0000-0000-000000000004';
  later_progress uuid := '81000000-0000-0000-0000-000000000005';
  earlier_progress uuid := '81000000-0000-0000-0000-000000000006';
  writer_id uuid := '81000000-0000-0000-0000-000000000007';
  second_writer uuid := '81000000-0000-0000-0000-000000000008';
  event_id uuid := '81000000-0000-0000-0000-000000000009';
  statement text;
BEGIN
  -- B has arrived and been acknowledged for each row. A's HTTP deadline
  -- already expired, but its earlier mutation can still arrive afterwards.
  PERFORM set_config('request.headers', jsonb_build_object(
    'x-ponderin-sync-writer', writer_id, 'x-ponderin-sync-sequence', '2')::text, true);
  INSERT INTO public.vocabulary_lists(id,owner_id,name,sync_write_protocol)
    VALUES(list_id,auth.uid(),'Acknowledged',16);
  INSERT INTO public.concepts(id,owner_id,list_id,notes,sync_write_protocol)
    VALUES(concept_id,auth.uid(),list_id,'Acknowledged',16);
  INSERT INTO public.word_variants(id,owner_id,concept_id,word,lang_code,sync_write_protocol)
    VALUES(variant_id,auth.uid(),concept_id,'bonjour','fr',16);
  INSERT INTO public.variant_progress(id,user_id,variant_owner_id,variant_id,direction,reps,sync_write_protocol)
    VALUES(later_progress,auth.uid(),auth.uid(),variant_id,'fr>ko',2,16);
  INSERT INTO public.review_events(id,user_id,variant_id,list_id,direction,mode,correct,rating,sync_write_protocol)
    VALUES(event_id,auth.uid(),variant_id::text,list_id,'fr>ko','typing',true,'good',16);

  PERFORM set_config('request.headers', jsonb_build_object(
    'x-ponderin-sync-writer', writer_id, 'x-ponderin-sync-sequence', '1')::text, true);
  FOREACH statement IN ARRAY ARRAY[
    format('INSERT INTO public.vocabulary_lists(id,owner_id,name) VALUES(%L,auth.uid(),%L) ON CONFLICT(owner_id,id) DO UPDATE SET name=excluded.name', list_id, 'Older'),
    format('UPDATE public.concepts SET notes=%L WHERE id=%L', 'Older', concept_id),
    format('UPDATE public.word_variants SET word=%L WHERE id=%L', 'older', variant_id),
    format('INSERT INTO public.variant_progress(id,user_id,variant_owner_id,variant_id,direction,reps) VALUES(%L,auth.uid(),auth.uid(),%L,%L,1) ON CONFLICT(user_id,variant_owner_id,variant_id,direction) DO UPDATE SET id=excluded.id,reps=excluded.reps', earlier_progress, variant_id, 'fr>ko'),
    format('UPDATE public.review_events SET variant_id=%L WHERE id=%L', 'older-variant', event_id)
  ] LOOP
    BEGIN
      EXECUTE statement;
      RAISE EXCEPTION 'Earlier REST write was accepted: %', statement;
    EXCEPTION WHEN serialization_failure THEN NULL; END;
  END LOOP;
  IF (SELECT name FROM public.vocabulary_lists WHERE id=list_id) <> 'Acknowledged'
    OR (SELECT notes FROM public.concepts WHERE id=concept_id) <> 'Acknowledged'
    OR (SELECT word FROM public.word_variants WHERE id=variant_id) <> 'bonjour'
    OR NOT EXISTS (SELECT 1 FROM public.variant_progress WHERE id=later_progress AND reps=2)
    OR NOT EXISTS (SELECT 1 FROM public.review_events e WHERE e.id=event_id AND e.list_id IS NOT NULL AND e.variant_id <> 'older-variant')
  THEN RAISE EXCEPTION 'A timed-out write changed the acknowledged state'; END IF;

  -- Another installation may still edit the list. A replay from the first
  -- installation remains stale even though it was no longer the last writer.
  PERFORM set_config('request.headers', jsonb_build_object(
    'x-ponderin-sync-writer', second_writer, 'x-ponderin-sync-sequence', '1')::text, true);
  UPDATE public.vocabulary_lists SET name='Other device' WHERE id=list_id;
  PERFORM set_config('request.headers', jsonb_build_object(
    'x-ponderin-sync-writer', writer_id, 'x-ponderin-sync-sequence', '1')::text, true);
  BEGIN
    UPDATE public.vocabulary_lists SET name='Replayed' WHERE id=list_id;
    RAISE EXCEPTION 'A new writer made an earlier write eligible';
  EXCEPTION WHEN serialization_failure THEN NULL; END;

  PERFORM set_config('request.headers','{}',true);
  BEGIN
    UPDATE public.vocabulary_lists SET name='Unversioned' WHERE id=list_id;
    RAISE EXCEPTION 'REST accepted an unversioned update';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;

-- Authorised audio updates use the service role, not the user's mutation API.
RESET ROLE;
SELECT set_config('request.jwt.claim.sub','',true);
SET LOCAL ROLE service_role;
UPDATE public.word_variants SET audio_path='users/fixture/audio.mp3'
  WHERE id='81000000-0000-0000-0000-000000000004';
RESET ROLE;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.word_variants WHERE audio_path='users/fixture/audio.mp3') THEN
    RAISE EXCEPTION 'The service role could not update provisioned audio';
  END IF;
END $$;

-- The existing authenticated E2E reset is a POST RPC with no write headers.
SELECT set_config('request.jwt.claim.sub','81000000-0000-0000-0000-000000000001',true);
SET LOCAL ROLE authenticated;
SELECT public.reset_e2e_account('write.order');
RESET ROLE;
ALTER TABLE public.word_variants DISABLE TRIGGER zz_vocabulary_write_order_update;
DO $$ BEGIN
  IF public.vocabulary_sync_write_ready() THEN
    RAISE EXCEPTION 'The preflight overlooked a disabled write fence';
  END IF;
END $$;
ROLLBACK;
