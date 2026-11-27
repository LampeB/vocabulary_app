BEGIN;

-- Administrative imports keep the server-side legacy owner resolution.
-- Client resolution runs as the caller so hidden matches cannot introduce
-- ambiguity for a UUID that also names a visible variant.
DROP TRIGGER bind_vocabulary_owner ON public.variant_progress;
CREATE TRIGGER bind_vocabulary_owner BEFORE INSERT OR UPDATE ON public.variant_progress
  FOR EACH ROW WHEN (current_user NOT IN ('anon', 'authenticated'))
  EXECUTE FUNCTION public.bind_vocabulary_owner();

CREATE FUNCTION vocabulary_private.check_progress_variant_access()
RETURNS trigger LANGUAGE plpgsql SET search_path = '' AS $$
DECLARE
  visible_owner uuid;
BEGIN
  IF TG_OP = 'UPDATE' THEN
    IF NEW.variant_owner_id IS NOT DISTINCT FROM OLD.variant_owner_id
       AND NEW.variant_id IS NOT DISTINCT FROM OLD.variant_id THEN
      RETURN NEW;
    END IF;
    IF NEW.variant_id IS DISTINCT FROM OLD.variant_id
       AND NEW.variant_owner_id IS NOT DISTINCT FROM OLD.variant_owner_id THEN
      NEW.variant_owner_id := NULL;
    END IF;
  END IF;

  -- The same RLS checks as an ordinary read apply to the whole branch.
  SELECT CASE WHEN bool_or(w.owner_id = NEW.user_id) THEN NEW.user_id
    WHEN count(*) = 1 THEN min(w.owner_id::text)::uuid END INTO visible_owner
  FROM public.word_variants w
  JOIN public.concepts c ON c.owner_id = w.owner_id AND c.id = w.concept_id
  JOIN public.vocabulary_lists l ON l.owner_id = c.owner_id AND l.id = c.list_id
  WHERE w.id = NEW.variant_id AND (NEW.variant_owner_id IS NULL OR w.owner_id = NEW.variant_owner_id)
    AND w.is_deleted IS NOT TRUE AND c.is_deleted IS NOT TRUE AND l.is_deleted IS NOT TRUE;
  IF visible_owner IS NOT NULL THEN
    NEW.variant_owner_id := visible_owner;
    RETURN NEW;
  END IF;

  -- ON CONFLICT runs BEFORE INSERT first. An existing exact history key is
  -- safe to update even after its variant became inaccessible. Lock that key
  -- so a concurrent deletion cannot turn the attempted upsert into an insert.
  IF TG_OP = 'INSERT' AND NEW.user_id = auth.uid() THEN
    PERFORM 1 FROM public.variant_progress p
    WHERE p.user_id = NEW.user_id AND p.variant_owner_id = NEW.variant_owner_id
      AND p.variant_id = NEW.variant_id AND p.direction = NEW.direction
    FOR KEY SHARE;
    IF FOUND THEN RETURN NEW; END IF;
  END IF;
  RAISE EXCEPTION 'Vocabulary variant unavailable' USING ERRCODE = '42501';
END $$;
REVOKE ALL ON FUNCTION vocabulary_private.check_progress_variant_access() FROM PUBLIC, anon, authenticated;
CREATE TRIGGER check_progress_variant_access BEFORE INSERT OR UPDATE ON public.variant_progress
  FOR EACH ROW WHEN (current_user IN ('anon', 'authenticated'))
  EXECUTE FUNCTION vocabulary_private.check_progress_variant_access();

-- Clients delete through tombstones. Physical removal of a parent cascades
-- into other learners' histories, so reserve it for server administration.
REVOKE DELETE, TRUNCATE ON public.vocabulary_lists, public.concepts, public.word_variants
  FROM PUBLIC, anon, authenticated;
CREATE POLICY client_tombstone_only ON public.vocabulary_lists
  AS RESTRICTIVE FOR DELETE TO anon, authenticated USING (false);
CREATE POLICY client_tombstone_only ON public.concepts
  AS RESTRICTIVE FOR DELETE TO anon, authenticated USING (false);
CREATE POLICY client_tombstone_only ON public.word_variants
  AS RESTRICTIVE FOR DELETE TO anon, authenticated USING (false);

CREATE FUNCTION public.vocabulary_reference_guards_ready()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT public.vocabulary_pull_catchup_ready()
    AND EXISTS (SELECT 1 FROM pg_catalog.pg_trigger
      WHERE tgrelid = to_regclass('public.variant_progress') AND tgname = 'check_progress_variant_access'
        AND tgfoid = to_regprocedure('vocabulary_private.check_progress_variant_access()')
        AND tgenabled IN ('O', 'A') AND tgtype = 23)
    AND (SELECT count(*) = 3 FROM pg_catalog.pg_policy p
      JOIN pg_catalog.pg_class t ON t.oid = p.polrelid
      WHERE p.polrelid IN (to_regclass('public.vocabulary_lists'), to_regclass('public.concepts'),
                           to_regclass('public.word_variants'))
        AND t.relrowsecurity AND p.polname = 'client_tombstone_only'
        AND p.polcmd = 'd' AND NOT p.polpermissive
        AND ARRAY[to_regrole('anon')::oid, to_regrole('authenticated')::oid] <@ p.polroles
        AND pg_catalog.pg_get_expr(p.polqual, p.polrelid) = 'false'
        AND NOT has_table_privilege('anon', t.oid, 'DELETE,TRUNCATE')
        AND NOT has_table_privilege('authenticated', t.oid, 'DELETE,TRUNCATE'));
$$;
REVOKE ALL ON FUNCTION public.vocabulary_reference_guards_ready() FROM PUBLIC, anon, authenticated;

-- Keep the earlier checks as prerequisites for the new public contract.
ALTER FUNCTION public.e2e_patrol_contract() SET SCHEMA e2e_private;
REVOKE ALL ON FUNCTION e2e_private.e2e_patrol_contract() FROM PUBLIC, anon, authenticated;
CREATE FUNCTION public.e2e_patrol_contract()
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT CASE WHEN e2e_private.e2e_patrol_contract() = 'write-order-v1'
    AND public.vocabulary_reference_guards_ready() THEN 'progress-boundaries-v1' END;
$$;
REVOKE ALL ON FUNCTION public.e2e_patrol_contract() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.e2e_patrol_contract() TO anon, authenticated;

-- Keep client reset closed on upgrades from the original 015 as well.
REVOKE ALL ON FUNCTION public.reset_e2e_account(text) FROM PUBLIC, anon, authenticated;
NOTIFY pgrst, 'reload schema';
COMMIT;
