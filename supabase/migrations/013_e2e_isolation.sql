BEGIN;

-- Keep the account registry private while checking relationships even when
-- the writer cannot read the destination list or its owner through RLS.
CREATE FUNCTION e2e_private.guard_shared_write()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  participants uuid[];
  list_owner uuid;
BEGIN
  CASE TG_TABLE_NAME
    WHEN 'friend_requests' THEN
      participants := ARRAY[NEW.from_user_id, NEW.to_user_id];
    WHEN 'friendships' THEN
      participants := ARRAY[NEW.user_a_id, NEW.user_b_id];
    WHEN 'challenges' THEN
      SELECT owner_id INTO list_owner FROM public.vocabulary_lists WHERE id = NEW.list_id;
      participants := ARRAY[NEW.challenger_id, NEW.challenged_id, list_owner];
    WHEN 'variant_progress' THEN
      SELECT l.owner_id INTO list_owner FROM public.word_variants w
        JOIN public.concepts c ON c.id = w.concept_id
        JOIN public.vocabulary_lists l ON l.id = c.list_id
        WHERE w.id = NEW.variant_id;
      IF NEW.user_id IS NOT DISTINCT FROM list_owner THEN
        RETURN NEW;
      END IF;
      participants := ARRAY[NEW.user_id, list_owner];
  END CASE;

  IF EXISTS (SELECT 1 FROM e2e_private.accounts
    WHERE user_id = ANY(participants) AND scenario_id IS NOT NULL) THEN
    RAISE EXCEPTION 'E2E scenario accounts cannot share relationships or progress'
      USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION e2e_private.guard_shared_write() FROM PUBLIC, anon, authenticated;

CREATE TRIGGER e2e_guard_shared_write BEFORE INSERT OR UPDATE ON public.friend_requests
  FOR EACH ROW EXECUTE FUNCTION e2e_private.guard_shared_write();
CREATE TRIGGER e2e_guard_shared_write BEFORE INSERT OR UPDATE ON public.friendships
  FOR EACH ROW EXECUTE FUNCTION e2e_private.guard_shared_write();
CREATE TRIGGER e2e_guard_shared_write BEFORE INSERT OR UPDATE ON public.challenges
  FOR EACH ROW EXECUTE FUNCTION e2e_private.guard_shared_write();
CREATE TRIGGER e2e_guard_shared_write BEFORE INSERT OR UPDATE ON public.variant_progress
  FOR EACH ROW EXECUTE FUNCTION e2e_private.guard_shared_write();

-- Check the relationship isolation installed here. Patrol additionally needs
-- the tombstone and owner namespace contract published in migration 015.
CREATE FUNCTION public.e2e_isolation_ready()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT to_regclass('public.review_events') IS NOT NULL
    AND to_regclass('public.published_audio_assets') IS NOT NULL
    AND (SELECT count(*) = 2 FROM pg_catalog.pg_policy
      WHERE polrelid = to_regclass('storage.objects') AND NOT polpermissive
        AND polname IN ('vocab audio anonymous boundary', 'vocab audio authenticated boundary'))
    AND (SELECT count(*) = 4 FROM pg_catalog.pg_trigger
      WHERE tgrelid IN (to_regclass('public.friend_requests'), to_regclass('public.friendships'),
                       to_regclass('public.challenges'), to_regclass('public.variant_progress'))
        AND tgname = 'e2e_guard_shared_write'
        AND tgfoid = to_regprocedure('e2e_private.guard_shared_write()')
        AND tgenabled IN ('O', 'A')
        AND tgtype = 23); -- BEFORE INSERT OR UPDATE, FOR EACH ROW
$$;
REVOKE ALL ON FUNCTION public.e2e_isolation_ready() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.e2e_isolation_ready() TO anon, authenticated;

DO $$ BEGIN
  IF NOT public.e2e_isolation_ready() THEN
    RAISE EXCEPTION 'Apply migration 012 before activating E2E reset';
  END IF;
END $$;

ALTER FUNCTION public.reset_e2e_account(text) SET SCHEMA e2e_private;
REVOKE ALL ON FUNCTION e2e_private.reset_e2e_account(text) FROM PUBLIC, anon, authenticated;
CREATE FUNCTION public.reset_e2e_account(p_scenario_id text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF NOT public.e2e_isolation_ready() THEN
    RAISE EXCEPTION 'E2E isolation is unavailable; reset refused' USING ERRCODE = '55000';
  END IF;
  RETURN e2e_private.reset_e2e_account(p_scenario_id);
END $$;
REVOKE ALL ON FUNCTION public.reset_e2e_account(text) FROM PUBLIC, anon, authenticated;
NOTIFY pgrst, 'reload schema';

COMMIT;
