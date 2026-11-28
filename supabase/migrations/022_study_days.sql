BEGIN;

CREATE SCHEMA study_private;
REVOKE ALL ON SCHEMA study_private FROM PUBLIC, anon, authenticated;
CREATE TABLE study_private.streak_ranges (
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  first_day date NOT NULL,
  last_day date NOT NULL CHECK (last_day >= first_day),
  PRIMARY KEY (user_id, first_day)
);
ALTER TABLE study_private.streak_ranges ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON study_private.streak_ranges FROM PUBLIC, anon, authenticated;

CREATE FUNCTION study_private.guard_profile_streak()
RETURNS trigger LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.current_streak = 0 AND NEW.longest_streak = 0 AND NEW.last_study_date IS NULL THEN
      RETURN NEW;
    END IF;
  ELSIF (NEW.current_streak,NEW.longest_streak,NEW.last_study_date)
    IS NOT DISTINCT FROM (OLD.current_streak,OLD.longest_streak,OLD.last_study_date) THEN
    RETURN NEW;
  END IF;
  RAISE EXCEPTION 'Record a study day to update the streak' USING ERRCODE = '42501';
END $$;
REVOKE ALL ON FUNCTION study_private.guard_profile_streak() FROM PUBLIC, anon, authenticated;
CREATE TRIGGER guard_profile_streak BEFORE INSERT OR UPDATE ON public.profiles
  FOR EACH ROW WHEN (current_user IN ('anon','authenticated'))
  EXECUTE FUNCTION study_private.guard_profile_streak();

-- An old profile describes one contiguous run and its historical best.
-- Backfill one interval per profile even for unusually large old counters.
INSERT INTO study_private.streak_ranges(user_id,first_day,last_day)
SELECT id,
  last_study_date - least(greatest(current_streak,1) - 1, last_study_date - date '0001-01-01'),
  last_study_date
FROM public.profiles
WHERE isfinite(last_study_date) AND last_study_date >= date '0001-01-01';

CREATE FUNCTION public.record_study_day(p_user_id uuid, p_study_date date)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  profile public.profiles%ROWTYPE;
  prior study_private.streak_ranges%ROWTYPE;
  joined_first date := p_study_date;
  joined_last date;
  latest study_private.streak_ranges%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL OR auth.uid() IS DISTINCT FROM p_user_id THEN
    RAISE EXCEPTION 'Study day account unavailable' USING ERRCODE = '42501';
  END IF;
  IF p_study_date IS NULL OR p_study_date NOT BETWEEN date '0001-01-01' AND date '9999-12-31' THEN
    RAISE EXCEPTION 'Invalid study date' USING ERRCODE = '22008';
  END IF;

  -- Serialize all range changes for one account and synchronize with profile
  -- removal during an account or Patrol reset.
  SELECT p.* INTO profile FROM public.profiles p WHERE p.id=p_user_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Study day account unavailable' USING ERRCODE = '42501'; END IF;

  SELECT r.* INTO prior FROM study_private.streak_ranges r
    WHERE r.user_id=p_user_id AND r.first_day<=p_study_date
    ORDER BY r.first_day DESC LIMIT 1;
  IF FOUND THEN
    IF prior.last_day >= p_study_date THEN RETURN; END IF;
    IF prior.last_day = p_study_date - 1 THEN
      joined_first := prior.first_day;
      DELETE FROM study_private.streak_ranges WHERE user_id=p_user_id AND first_day=prior.first_day;
    END IF;
  END IF;
  DELETE FROM study_private.streak_ranges WHERE user_id=p_user_id AND first_day=p_study_date + 1
    RETURNING last_day INTO joined_last;
  joined_last := COALESCE(joined_last,p_study_date);
  INSERT INTO study_private.streak_ranges(user_id,first_day,last_day)
    VALUES (p_user_id,joined_first,joined_last);

  SELECT r.* INTO STRICT latest FROM study_private.streak_ranges r
    WHERE r.user_id=p_user_id ORDER BY r.first_day DESC LIMIT 1;
  UPDATE public.profiles
    SET current_streak=latest.last_day - latest.first_day + 1,
        longest_streak=greatest(profile.longest_streak,profile.current_streak,
          joined_last - joined_first + 1,latest.last_day - latest.first_day + 1),
        last_study_date=greatest(profile.last_study_date,latest.last_day),
        updated_at=now()
    WHERE id=p_user_id;
END $$;
REVOKE ALL ON FUNCTION public.record_study_day(uuid,date) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.record_study_day(uuid,date) TO authenticated;

ALTER FUNCTION public.e2e_patrol_contract() RENAME TO e2e_patrol_friend_contract;
ALTER FUNCTION public.e2e_patrol_friend_contract() SET SCHEMA e2e_private;
REVOKE ALL ON FUNCTION e2e_private.e2e_patrol_friend_contract() FROM PUBLIC, anon, authenticated;
CREATE FUNCTION public.e2e_patrol_contract()
RETURNS text LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF to_regprocedure('public.vocabulary_purge_catalog_ready()') IS NULL THEN RETURN NULL; END IF;
  IF public.vocabulary_purge_catalog_ready() IS DISTINCT FROM true THEN RETURN NULL; END IF;
  RETURN (SELECT CASE WHEN e2e_private.e2e_patrol_friend_contract() = 'friend-consent-v1'
    AND to_regclass('study_private.streak_ranges') IS NOT NULL
    AND has_function_privilege('authenticated','public.record_study_day(uuid,date)','EXECUTE')
    AND EXISTS (SELECT 1 FROM pg_catalog.pg_trigger
      WHERE tgrelid=to_regclass('public.profiles') AND tgname='guard_profile_streak'
        AND tgfoid=to_regprocedure('study_private.guard_profile_streak()')
        AND tgenabled IN ('O','A') AND tgtype=23)
    THEN 'study-catalog-v1' END);
END $$;
REVOKE ALL ON FUNCTION public.e2e_patrol_contract() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.e2e_patrol_contract() TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.reset_e2e_account(p_scenario_id text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF public.e2e_patrol_contract() IS DISTINCT FROM 'study-catalog-v1' THEN
    RAISE EXCEPTION 'Patrol schema is unavailable; reset refused' USING ERRCODE = '55000';
  END IF;
  RETURN e2e_private.reset_e2e_account(p_scenario_id);
END $$;
REVOKE ALL ON FUNCTION public.reset_e2e_account(text) FROM PUBLIC, anon, authenticated;

NOTIFY pgrst, 'reload schema';
COMMIT;
