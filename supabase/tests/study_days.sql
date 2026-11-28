-- Disposable PostgreSQL. The fixture installed before 022 exercises backfill.
BEGIN;
DO $$ BEGIN
  IF (SELECT count(*) FROM study_private.streak_ranges
    WHERE user_id='22000000-0000-4000-8000-000000000003') <> 1
    OR NOT EXISTS (SELECT 1 FROM study_private.streak_ranges
      WHERE user_id='22000000-0000-4000-8000-000000000003'
        AND first_day='0001-01-01' AND last_day='2026-11-24') THEN
    RAISE EXCEPTION 'An oversized historical counter was not represented by one bounded range';
  END IF;
  IF has_schema_privilege('authenticated','study_private','USAGE')
    OR has_table_privilege('authenticated','study_private.streak_ranges','SELECT,INSERT,UPDATE,DELETE,TRUNCATE')
    OR has_function_privilege('anon','public.record_study_day(uuid,date)','EXECUTE') THEN
    RAISE EXCEPTION 'Study day permissions are too broad';
  END IF;
END $$;

SELECT set_config('request.jwt.claim.sub','22000000-0000-4000-8000-000000000001',true);
SET LOCAL ROLE authenticated;
DO $$ BEGIN
  BEGIN
    PERFORM public.record_study_day('22000000-0000-4000-8000-000000000002','2026-11-25');
    RAISE EXCEPTION 'One account wrote a study day for another';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN
    UPDATE public.profiles SET current_streak=999 WHERE id=auth.uid();
    RAISE EXCEPTION 'Client overwrote the derived streak';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  UPDATE public.profiles SET display_name='Allowed profile edit' WHERE id=auth.uid();
  IF NOT FOUND THEN RAISE EXCEPTION 'An unrelated profile update was denied'; END IF;

  PERFORM public.record_study_day(auth.uid(),'2026-11-26');
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id=auth.uid()
    AND (current_streak,longest_streak,last_study_date)=(1,5,date '2026-11-26')) THEN
    RAISE EXCEPTION 'An actual gap failed to start a new run';
  END IF;
  PERFORM public.record_study_day(auth.uid(),'2026-11-25');
  PERFORM public.record_study_day(auth.uid(),'2026-11-25');
  PERFORM public.record_study_day(auth.uid(),'2026-11-21');
  PERFORM public.record_study_day(auth.uid(),'2026-11-26');
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id=auth.uid()
    AND (current_streak,longest_streak,last_study_date)=(7,7,date '2026-11-26')) THEN
    RAISE EXCEPTION 'Reverse-order arrival or replay lost part of the streak';
  END IF;
  PERFORM public.record_study_day(auth.uid(),'2026-10-31');
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id=auth.uid()
    AND (current_streak,longest_streak,last_study_date)=(7,7,date '2026-11-26')) THEN
    RAISE EXCEPTION 'A disconnected historical day became the latest date';
  END IF;
END $$;

SELECT set_config('request.jwt.claim.sub','22000000-0000-4000-8000-000000000002',true);
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id=auth.uid()
    AND (current_streak,longest_streak,last_study_date)=(5,10,date '2026-11-24')) THEN
    RAISE EXCEPTION 'The other account changed before its own requests';
  END IF;
  PERFORM public.record_study_day(auth.uid(),'2026-11-25');
  PERFORM public.record_study_day(auth.uid(),'2026-11-26');
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id=auth.uid()
    AND (current_streak,longest_streak,last_study_date)=(7,10,date '2026-11-26')) THEN
    RAISE EXCEPTION 'Forward arrival changed the duration or lost the previous record';
  END IF;
END $$;
RESET ROLE;
DO $$ BEGIN
  IF (SELECT count(*) FROM study_private.streak_ranges
      WHERE user_id='22000000-0000-4000-8000-000000000001') <> 2
    OR NOT EXISTS (SELECT 1 FROM study_private.streak_ranges
      WHERE user_id='22000000-0000-4000-8000-000000000001'
        AND first_day='2026-11-20' AND last_day='2026-11-26') THEN
    RAISE EXCEPTION 'Replayed or adjacent days were not merged into compact ranges';
  END IF;
END $$;

INSERT INTO auth.users(id,email,raw_user_meta_data,raw_app_meta_data) VALUES
  ('22000000-0000-4000-8000-000000000004','study-reset@example.invalid','{"username":"study_reset"}',
   '{"e2e_managed_by":"vocabkr","e2e_scenario_id":"study.reset"}');
SELECT public.enroll_e2e_account('22000000-0000-4000-8000-000000000004','study.reset','study_reset');
SELECT set_config('request.jwt.claim.sub','22000000-0000-4000-8000-000000000004',true);
SET LOCAL ROLE authenticated;
SELECT public.record_study_day(auth.uid(),'2026-11-25');
SELECT public.reset_e2e_account('study.reset');
RESET ROLE;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM study_private.streak_ranges WHERE user_id='22000000-0000-4000-8000-000000000004')
    OR NOT EXISTS (SELECT 1 FROM public.profiles WHERE id='22000000-0000-4000-8000-000000000004'
      AND current_streak=0 AND longest_streak=0 AND last_study_date IS NULL) THEN
    RAISE EXCEPTION 'Patrol reset did not clear the study streak';
  END IF;
END $$;
SET LOCAL ROLE authenticated;
SELECT public.record_study_day(auth.uid(),'2026-11-26');
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id=auth.uid()
    AND (current_streak,longest_streak,last_study_date)=(1,1,date '2026-11-26')) THEN
    RAISE EXCEPTION 'A previous day reappeared after the Patrol reset';
  END IF;
END $$;
ROLLBACK;
