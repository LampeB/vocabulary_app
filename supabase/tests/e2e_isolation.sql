-- Disposable database only, after migration 021. All fixtures roll back.
BEGIN;
INSERT INTO auth.users(id,email,raw_user_meta_data,raw_app_meta_data) VALUES
 ('51000000-0000-0000-0000-000000000001','isolated@example.invalid','{"username":"isolated"}',
  '{"e2e_managed_by":"vocabkr","e2e_scenario_id":"isolation.a"}'),
 ('51000000-0000-0000-0000-000000000002','ordinary_a@example.invalid','{"username":"ordinary_a"}','{}'),
 ('51000000-0000-0000-0000-000000000003','ordinary_b@example.invalid','{"username":"ordinary_b"}','{}');
SELECT public.enroll_e2e_account('51000000-0000-0000-0000-000000000001','isolation.a','isolated');
INSERT INTO public.vocabulary_lists(id,owner_id,name,visibility) VALUES
 ('52000000-0000-0000-0000-000000000001','51000000-0000-0000-0000-000000000001','Public E2E','public'),
 ('52000000-0000-0000-0000-000000000002','51000000-0000-0000-0000-000000000003','Public ordinary','public');
INSERT INTO public.concepts(id,list_id) VALUES
 ('53000000-0000-0000-0000-000000000001','52000000-0000-0000-0000-000000000001'),
 ('53000000-0000-0000-0000-000000000002','52000000-0000-0000-0000-000000000002');
INSERT INTO public.word_variants(id,concept_id,word,lang_code) VALUES
 ('54000000-0000-0000-0000-000000000001','53000000-0000-0000-0000-000000000001','private','en'),
 ('54000000-0000-0000-0000-000000000002','53000000-0000-0000-0000-000000000002','public','en');
DO $$ BEGIN
  IF has_schema_privilege('authenticated','e2e_private','USAGE')
    OR has_table_privilege('authenticated','e2e_private.accounts','SELECT')
    OR has_function_privilege('authenticated','e2e_private.guard_shared_write()','EXECUTE')
    OR has_function_privilege('authenticated','e2e_private.reset_e2e_account(text)','EXECUTE') THEN
    RAISE EXCEPTION 'Isolation exposes the registry or trigger function';
  END IF;
END $$;

SET LOCAL ROLE anon;
DO $$ BEGIN
  IF public.e2e_patrol_contract() IS DISTINCT FROM 'friend-consent-v1' THEN
    RAISE EXCEPTION 'CI cannot verify the installed Patrol schema';
  END IF;
END $$;
RESET ROLE;
ALTER TABLE public.friend_requests DISABLE TRIGGER e2e_guard_shared_write;
SELECT set_config('request.jwt.claim.sub','51000000-0000-0000-0000-000000000001',true);
SET LOCAL ROLE authenticated;
DO $$ BEGIN
  IF public.e2e_patrol_contract() IS NOT NULL THEN RAISE EXCEPTION 'Disabled isolation reported ready'; END IF;
  BEGIN
    PERFORM public.reset_e2e_account('isolation.a');
    RAISE EXCEPTION 'Reset accepted with disabled isolation';
  EXCEPTION WHEN object_not_in_prerequisite_state THEN NULL; END;
  IF NOT EXISTS(SELECT 1 FROM public.vocabulary_lists WHERE id='52000000-0000-0000-0000-000000000001') THEN
    RAISE EXCEPTION 'Reset with disabled isolation changed a list';
  END IF;
END $$;
RESET ROLE;
ALTER TABLE public.friend_requests ENABLE TRIGGER e2e_guard_shared_write;
ALTER TABLE public.word_variants DISABLE TRIGGER word_variants_guard_tombstone;
SET LOCAL ROLE anon;
DO $$ BEGIN
  IF public.e2e_patrol_contract() IS NOT NULL THEN RAISE EXCEPTION 'Disabled tombstones reported ready'; END IF;
END $$;
RESET ROLE;
ALTER TABLE public.word_variants ENABLE TRIGGER word_variants_guard_tombstone;
ALTER TABLE public.word_variants DISABLE TRIGGER zz_vocabulary_write_order_update;
SET LOCAL ROLE anon;
DO $$ BEGIN
  IF public.e2e_patrol_contract() IS NOT NULL THEN RAISE EXCEPTION 'Disabled write ordering reported ready'; END IF;
END $$;
RESET ROLE;
ALTER TABLE public.word_variants ENABLE TRIGGER zz_vocabulary_write_order_update;
ALTER TABLE public.vocabulary_lists DISABLE TRIGGER vocabulary_pull_change;
SET LOCAL ROLE anon;
DO $$ BEGIN
  IF public.e2e_patrol_contract() IS NOT NULL THEN RAISE EXCEPTION 'Disabled pull catch-up reported ready'; END IF;
END $$;
RESET ROLE;
ALTER TABLE public.vocabulary_lists ENABLE TRIGGER vocabulary_pull_change;
ALTER TABLE public.variant_progress DISABLE TRIGGER check_progress_variant_access;
SET LOCAL ROLE anon;
DO $$ BEGIN
  IF public.e2e_patrol_contract() IS NOT NULL THEN RAISE EXCEPTION 'Disabled progress access guard reported ready'; END IF;
END $$;
RESET ROLE;
ALTER TABLE public.variant_progress ENABLE TRIGGER check_progress_variant_access;
GRANT TRUNCATE ON public.concepts TO authenticated;
SET LOCAL ROLE anon;
DO $$ BEGIN
  IF public.e2e_patrol_contract() IS NOT NULL THEN RAISE EXCEPTION 'Client truncate grant reported ready'; END IF;
END $$;
RESET ROLE;
REVOKE TRUNCATE ON public.concepts FROM authenticated;
ALTER TABLE public.challenges DISABLE TRIGGER check_challenge_list_access;
SET LOCAL ROLE authenticated;
DO $$ BEGIN
  IF public.e2e_patrol_contract() IS NOT NULL THEN RAISE EXCEPTION 'Disabled challenge guard reported ready'; END IF;
  BEGIN
    PERFORM public.reset_e2e_account('isolation.a');
    RAISE EXCEPTION 'Reset accepted with disabled challenge guard';
  EXCEPTION WHEN object_not_in_prerequisite_state THEN NULL; END;
  IF NOT EXISTS (SELECT 1 FROM public.vocabulary_lists WHERE id='52000000-0000-0000-0000-000000000001') THEN
    RAISE EXCEPTION 'Reset with disabled challenge guard changed a list';
  END IF;
END $$;
RESET ROLE;
ALTER TABLE public.challenges ENABLE TRIGGER check_challenge_list_access;
GRANT UPDATE ON public.friend_requests TO authenticated;
SET LOCAL ROLE authenticated;
DO $$ BEGIN
  IF public.e2e_patrol_contract() IS NOT NULL THEN RAISE EXCEPTION 'Unchecked friend updates reported ready'; END IF;
  BEGIN
    PERFORM public.reset_e2e_account('isolation.a');
    RAISE EXCEPTION 'Reset accepted with a broad friend request grant';
  EXCEPTION WHEN object_not_in_prerequisite_state THEN NULL; END;
END $$;
RESET ROLE;
REVOKE UPDATE ON public.friend_requests FROM authenticated;

SELECT set_config('request.jwt.claim.sub','51000000-0000-0000-0000-000000000002',true);
SET LOCAL ROLE authenticated;
DO $$
DECLARE
  target uuid := '51000000-0000-0000-0000-000000000001';
  ordinary uuid := '51000000-0000-0000-0000-000000000003';
  target_list uuid := '52000000-0000-0000-0000-000000000001';
  target_variant uuid := '54000000-0000-0000-0000-000000000001';
  ordinary_variant uuid := '54000000-0000-0000-0000-000000000002';
  statement text;
BEGIN
  -- The same writes must remain available to ordinary accounts.
  PERFORM public.send_friend_request(ordinary);
  INSERT INTO public.challenges(challenger_id,challenged_id) VALUES (auth.uid(),ordinary);
  INSERT INTO public.variant_progress(user_id,variant_id,direction) VALUES (auth.uid(),ordinary_variant,'en>fr');

  FOREACH statement IN ARRAY ARRAY[
    format('SELECT public.send_friend_request(%L)', target),
    format('INSERT INTO public.challenges(challenger_id,challenged_id) VALUES (%L,%L)', auth.uid(), target),
    format('INSERT INTO public.challenges(challenger_id,challenged_id,list_id) VALUES (%L,%L,%L)', auth.uid(), ordinary, target_list),
    format('INSERT INTO public.variant_progress(user_id,variant_id,direction) VALUES (%L,%L,%L)', auth.uid(), target_variant, 'en>fr'),
    format('UPDATE public.challenges SET list_id=%L WHERE challenger_id=auth.uid()', target_list),
    format('UPDATE public.variant_progress SET variant_id=%L WHERE user_id=auth.uid()', target_variant)
  ] LOOP
    BEGIN
      EXECUTE statement;
      RAISE EXCEPTION 'Cross-account write accepted: %', statement;
    EXCEPTION WHEN insufficient_privilege THEN
      IF SQLERRM <> 'E2E scenario accounts cannot share relationships or progress' THEN RAISE; END IF;
    END;
  END LOOP;
END $$;

SELECT set_config('request.jwt.claim.sub','51000000-0000-0000-0000-000000000003',true);
DO $$ BEGIN
  BEGIN
    UPDATE public.friend_requests SET from_user_id='51000000-0000-0000-0000-000000000001'
      WHERE to_user_id=auth.uid();
    RAISE EXCEPTION 'Friend request could be retargeted to an E2E account';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  PERFORM public.respond_friend_request(id,true) FROM public.friend_requests WHERE to_user_id=auth.uid();
END $$;

SELECT set_config('request.jwt.claim.sub','51000000-0000-0000-0000-000000000001',true);
DO $$ BEGIN
  INSERT INTO public.variant_progress(user_id,variant_id,direction)
    VALUES (auth.uid(),'54000000-0000-0000-0000-000000000001','en>fr');
  BEGIN
    INSERT INTO public.variant_progress(user_id,variant_id,direction)
      VALUES (auth.uid(),'54000000-0000-0000-0000-000000000002','en>fr');
    RAISE EXCEPTION 'E2E progress on an ordinary account was accepted';
  EXCEPTION WHEN insufficient_privilege THEN
    IF SQLERRM <> 'E2E scenario accounts cannot share relationships or progress' THEN RAISE; END IF;
  END;
END $$;
SELECT public.reset_e2e_account('isolation.a');
RESET ROLE;
DO $$
DECLARE
  isolated uuid := '51000000-0000-0000-0000-000000000001';
  requester uuid := '51000000-0000-0000-0000-000000000002';
  recipient uuid := '51000000-0000-0000-0000-000000000003';
BEGIN
  IF EXISTS (SELECT 1 FROM public.vocabulary_lists WHERE owner_id=isolated)
    OR EXISTS (SELECT 1 FROM public.variant_progress WHERE user_id=isolated)
    OR NOT EXISTS (SELECT 1 FROM public.vocabulary_lists WHERE owner_id=recipient
      AND id='52000000-0000-0000-0000-000000000002')
    OR NOT EXISTS (SELECT 1 FROM public.friend_requests
      WHERE from_user_id=requester AND to_user_id=recipient AND status='accepted' AND sender_verified)
    OR NOT EXISTS (SELECT 1 FROM public.friendships
      WHERE user_a_id=requester AND user_b_id=recipient AND consent_verified)
    OR NOT EXISTS (SELECT 1 FROM public.challenges WHERE challenger_id=requester AND challenged_id=recipient)
    OR NOT EXISTS (SELECT 1 FROM public.variant_progress WHERE user_id=requester AND variant_owner_id=recipient
      AND variant_id='54000000-0000-0000-0000-000000000002') THEN
    RAISE EXCEPTION 'Isolation or reset modified ordinary account data';
  END IF;
END $$;
ROLLBACK;
