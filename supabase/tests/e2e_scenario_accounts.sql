-- Disposable database only, after migrations 008 and 009. All fixtures roll back.
BEGIN;
INSERT INTO auth.users (id,email,raw_user_meta_data,raw_app_meta_data) VALUES
 ('00000000-0000-0000-0000-000000000001','a@example.invalid','{"username":"scenario_a"}',
  '{"e2e_managed_by":"vocabkr","e2e_scenario_id":"quiz.a"}'),
 ('00000000-0000-0000-0000-000000000002','b@example.invalid','{"username":"scenario_b"}',
  '{"e2e_managed_by":"vocabkr","e2e_scenario_id":"quiz.b"}'),
 ('00000000-0000-0000-0000-000000000003','c@example.invalid','{"username":"scenario_c"}',
  '{"e2e_managed_by":"vocabkr","e2e_scenario_id":"quiz.a"}');
SET LOCAL ROLE service_role;
SELECT public.enroll_e2e_account('00000000-0000-0000-0000-000000000001','quiz.a','scenario_a');
SELECT public.enroll_e2e_account('00000000-0000-0000-0000-000000000001','quiz.a','scenario_a');
SELECT public.enroll_e2e_account('00000000-0000-0000-0000-000000000002','quiz.b','scenario_b');
DO $$ BEGIN
  BEGIN
    PERFORM public.enroll_e2e_account('00000000-0000-0000-0000-000000000003','quiz.a','scenario_c');
    RAISE EXCEPTION 'Duplicate scenario accepted';
  EXCEPTION WHEN unique_violation THEN NULL; END;
END $$;
RESET ROLE;
INSERT INTO public.vocabulary_lists (owner_id,name) VALUES
 ('00000000-0000-0000-0000-000000000001','A fixture'),
 ('00000000-0000-0000-0000-000000000002','B fixture');
DO $$ BEGIN
  IF to_regprocedure('public.reset_e2e_account()') IS NOT NULL
    OR has_function_privilege('authenticated','e2e_private.reset_e2e_account()','EXECUTE')
    OR has_function_privilege('authenticated','public.enroll_e2e_account(uuid,text,text)','EXECUTE') THEN
    RAISE EXCEPTION 'Old or administrative reset access remains';
  END IF;
END $$;
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
SET LOCAL ROLE authenticated;
DO $$ BEGIN
  BEGIN
    PERFORM public.reset_e2e_account('quiz.b');
    RAISE EXCEPTION 'Wrong scenario accepted';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN
    PERFORM public.reset_e2e_account(NULL);
    RAISE EXCEPTION 'NULL scenario accepted';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
DO $$ BEGIN
  IF (SELECT count(*) FROM public.vocabulary_lists) <> 2 THEN
    RAISE EXCEPTION 'Failed reset changed data';
  END IF;
END $$;
SET LOCAL ROLE authenticated;
SELECT public.reset_e2e_account('quiz.a');
SELECT public.reset_e2e_account('quiz.a');
RESET ROLE;
DO $$ BEGIN
  IF (SELECT count(*) FROM public.vocabulary_lists) <> 1
    OR NOT EXISTS (SELECT 1 FROM public.vocabulary_lists WHERE name='B fixture')
    OR NOT EXISTS (SELECT 1 FROM public.profiles WHERE username='scenario_b') THEN
    RAISE EXCEPTION 'Reset A affected B';
  END IF;
END $$;
-- Shared relationships must fail closed instead of altering the other scenario.
INSERT INTO public.friendships (user_a_id,user_b_id) VALUES
 ('00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000002');
SET LOCAL ROLE authenticated;
DO $$ BEGIN
  BEGIN
    PERFORM public.reset_e2e_account('quiz.a');
    RAISE EXCEPTION 'Reset of shared data accepted';
  EXCEPTION WHEN foreign_key_violation THEN NULL; END;
END $$;
RESET ROLE;
DO $$ BEGIN
  IF (SELECT count(*) FROM public.friendships) <> 1
    OR NOT EXISTS (SELECT 1 FROM public.vocabulary_lists WHERE name='B fixture') THEN
    RAISE EXCEPTION 'Shared-data rejection changed data';
  END IF;
END $$;
ROLLBACK;
