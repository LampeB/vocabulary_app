-- Disposable database only, after 009, 012, 013 or 014 and before 015.
BEGIN;
DO $$ BEGIN
  IF to_regprocedure('public.e2e_patrol_contract()') IS NOT NULL THEN
    RAISE EXCEPTION 'A partial schema exposes the Patrol contract before migration 015';
  END IF;
END $$;
INSERT INTO auth.users(id,email,raw_user_meta_data,raw_app_meta_data) VALUES
 ('51000000-0000-0000-0000-000000000001','pending@example.invalid','{"username":"pending"}',
  '{"e2e_managed_by":"vocabkr","e2e_scenario_id":"activation.a"}');
SELECT public.enroll_e2e_account('51000000-0000-0000-0000-000000000001','activation.a','pending');
INSERT INTO public.vocabulary_lists(id,owner_id,name) VALUES
 ('52000000-0000-0000-0000-000000000001','51000000-0000-0000-0000-000000000001','Pending isolation');
SELECT set_config('request.jwt.claim.sub','51000000-0000-0000-0000-000000000001',true);
SET LOCAL ROLE authenticated;
DO $$ BEGIN
  BEGIN
    PERFORM public.reset_e2e_account('activation.a');
    RAISE EXCEPTION 'An enrolled account reset before the Patrol schema was ready';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
DO $$ BEGIN
  IF NOT EXISTS(SELECT 1 FROM public.vocabulary_lists WHERE id='52000000-0000-0000-0000-000000000001') THEN
    RAISE EXCEPTION 'Reset modified a list before the Patrol schema was ready';
  END IF;
END $$;
ROLLBACK;
