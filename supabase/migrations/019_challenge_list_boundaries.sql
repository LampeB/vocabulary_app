BEGIN;

-- Administrative imports retain legacy owner resolution. Client resolution
-- sees only the active lists made visible by the caller's RLS policies.
DROP TRIGGER bind_vocabulary_owner ON public.challenges;
CREATE TRIGGER bind_vocabulary_owner BEFORE INSERT OR UPDATE ON public.challenges
  FOR EACH ROW WHEN (current_user NOT IN ('anon', 'authenticated'))
  EXECUTE FUNCTION public.bind_vocabulary_owner();

CREATE FUNCTION vocabulary_private.check_challenge_list_access()
RETURNS trigger LANGUAGE plpgsql SET search_path = '' AS $$
DECLARE
  actor uuid := auth.uid();
  visible_owner uuid;
BEGIN
  IF TG_OP = 'UPDATE'
    AND NEW.list_id IS NOT DISTINCT FROM OLD.list_id
    AND NEW.list_owner_id IS NOT DISTINCT FROM OLD.list_owner_id
    AND NEW.challenger_id IS NOT DISTINCT FROM OLD.challenger_id
    AND NEW.challenged_id IS NOT DISTINCT FROM OLD.challenged_id THEN
    RETURN NEW;
  END IF;
  IF NEW.list_id IS NULL AND NEW.list_owner_id IS NULL THEN RETURN NEW; END IF;

  IF actor IS NOT NULL THEN
    SELECT CASE WHEN bool_or(l.owner_id = actor) THEN actor
      WHEN count(*) = 1 THEN min(l.owner_id::text)::uuid END INTO visible_owner
    FROM public.vocabulary_lists l
    WHERE l.id = NEW.list_id AND (NEW.list_owner_id IS NULL OR l.owner_id = NEW.list_owner_id)
      AND l.is_deleted IS NOT TRUE;
  END IF;
  IF visible_owner IS NULL THEN
    RAISE EXCEPTION 'Challenge list unavailable' USING ERRCODE = '42501';
  END IF;
  NEW.list_owner_id := visible_owner;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION vocabulary_private.check_challenge_list_access()
  FROM PUBLIC, anon, authenticated;
CREATE TRIGGER check_challenge_list_access BEFORE INSERT OR UPDATE ON public.challenges
  FOR EACH ROW WHEN (current_user IN ('anon', 'authenticated'))
  EXECUTE FUNCTION vocabulary_private.check_challenge_list_access();

ALTER FUNCTION public.e2e_patrol_contract() RENAME TO e2e_patrol_progress_contract;
ALTER FUNCTION public.e2e_patrol_progress_contract() SET SCHEMA e2e_private;
REVOKE ALL ON FUNCTION e2e_private.e2e_patrol_progress_contract() FROM PUBLIC, anon, authenticated;
CREATE FUNCTION public.e2e_patrol_contract()
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT CASE WHEN e2e_private.e2e_patrol_progress_contract() = 'progress-boundaries-v1'
    AND to_regprocedure('public.vocabulary_pull_inventory(uuid,uuid)') IS NOT NULL
    AND EXISTS (SELECT 1 FROM pg_catalog.pg_trigger
      WHERE tgrelid = to_regclass('public.challenges') AND tgname = 'check_challenge_list_access'
        AND tgfoid = to_regprocedure('vocabulary_private.check_challenge_list_access()')
        AND tgenabled IN ('O', 'A') AND tgtype = 23)
    THEN 'challenge-boundaries-v1' END;
$$;
REVOKE ALL ON FUNCTION public.e2e_patrol_contract() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.e2e_patrol_contract() TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.reset_e2e_account(p_scenario_id text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF public.e2e_patrol_contract() IS DISTINCT FROM 'challenge-boundaries-v1' THEN
    RAISE EXCEPTION 'Patrol schema is unavailable; reset refused' USING ERRCODE = '55000';
  END IF;
  RETURN e2e_private.reset_e2e_account(p_scenario_id);
END $$;
REVOKE ALL ON FUNCTION public.reset_e2e_account(text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.reset_e2e_account(text) TO authenticated;

NOTIFY pgrst, 'reload schema';
COMMIT;
