-- Disposable database only, after 009 and 012–020.
BEGIN;
SET LOCAL ROLE anon;
DO $$ BEGIN
  IF to_regprocedure('public.e2e_patrol_contract()') IS NOT NULL THEN
    IF public.e2e_patrol_contract() IS NOT DISTINCT FROM 'friend-consent-v1' THEN
      RAISE EXCEPTION 'A partial schema advertises the current Patrol contract';
    END IF;
  END IF;
END $$;
RESET ROLE;
INSERT INTO auth.users(id,email,raw_user_meta_data,raw_app_meta_data) VALUES
 ('51000000-0000-0000-0000-000000000001','pending@example.invalid','{"username":"pending"}',
  '{"e2e_managed_by":"vocabkr","e2e_scenario_id":"activation.a"}');
SELECT public.enroll_e2e_account('51000000-0000-0000-0000-000000000001','activation.a','pending');
INSERT INTO public.vocabulary_lists(id,owner_id,name) VALUES
 ('52000000-0000-0000-0000-000000000001','51000000-0000-0000-0000-000000000001','Pending isolation');
UPDATE public.profiles SET display_name='Pending reset'
  WHERE id='51000000-0000-0000-0000-000000000001';
SELECT set_config('request.jwt.claim.sub','51000000-0000-0000-0000-000000000001',true);
SET LOCAL ROLE authenticated;
DO $$ BEGIN
  BEGIN
    PERFORM public.reset_e2e_account('activation.a');
    RAISE EXCEPTION 'An enrolled account reset before the Patrol schema was ready';
  EXCEPTION WHEN insufficient_privilege OR object_not_in_prerequisite_state THEN NULL; END;
END $$;
RESET ROLE;
DO $$ BEGIN
  IF has_function_privilege('authenticated', 'public.reset_e2e_account(text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'Client reset privilege granted before schema completion';
  END IF;
  IF NOT EXISTS(SELECT 1 FROM public.vocabulary_lists WHERE id='52000000-0000-0000-0000-000000000001')
    OR NOT EXISTS (SELECT 1 FROM public.profiles WHERE id='51000000-0000-0000-0000-000000000001'
      AND display_name='Pending reset') THEN
    RAISE EXCEPTION 'Reset modified scenario data before the Patrol schema was ready';
  END IF;
END $$;
ROLLBACK;
