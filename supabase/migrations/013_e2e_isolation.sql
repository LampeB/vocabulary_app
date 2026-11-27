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

COMMIT;
