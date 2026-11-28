BEGIN;

-- Historical 012 left writes under pre-existing permissive Storage policies.
DROP POLICY IF EXISTS "vocab audio client insert boundary" ON storage.objects;
DROP POLICY IF EXISTS "vocab audio client update boundary" ON storage.objects;
DROP POLICY IF EXISTS "vocab audio client delete boundary" ON storage.objects;
CREATE POLICY "vocab audio client insert boundary" ON storage.objects
  AS RESTRICTIVE FOR INSERT TO anon, authenticated
  WITH CHECK (bucket_id IS DISTINCT FROM 'vocab-audio');
CREATE POLICY "vocab audio client update boundary" ON storage.objects
  AS RESTRICTIVE FOR UPDATE TO anon, authenticated
  USING (bucket_id IS DISTINCT FROM 'vocab-audio')
  WITH CHECK (bucket_id IS DISTINCT FROM 'vocab-audio');
CREATE POLICY "vocab audio client delete boundary" ON storage.objects
  AS RESTRICTIVE FOR DELETE TO anon, authenticated
  USING (bucket_id IS DISTINCT FROM 'vocab-audio');

CREATE FUNCTION e2e_private.audio_storage_writes_ready()
RETURNS boolean LANGUAGE sql STABLE SET search_path = '' AS $$
  SELECT EXISTS (SELECT 1 FROM pg_catalog.pg_class
    WHERE oid = to_regclass('storage.objects') AND relrowsecurity)
    AND EXISTS (SELECT 1 FROM storage.buckets WHERE id = 'vocab-audio' AND public IS FALSE)
    AND (SELECT count(*) = 3
      FROM pg_catalog.pg_policy p
      JOIN (VALUES ('vocab audio client insert boundary', 'a', false, true),
                   ('vocab audio client update boundary', 'w', true, true),
                   ('vocab audio client delete boundary', 'd', true, false))
        AS expected(name, command, filters_existing, checks_new)
        ON p.polname = expected.name AND p.polcmd = expected.command::"char"
      WHERE p.polrelid = to_regclass('storage.objects') AND NOT p.polpermissive
        AND ARRAY[to_regrole('anon')::oid, to_regrole('authenticated')::oid] <@ p.polroles
        AND pg_catalog.pg_get_expr(p.polqual, p.polrelid) IS NOT DISTINCT FROM
          CASE WHEN expected.filters_existing THEN '(bucket_id IS DISTINCT FROM ''vocab-audio''::text)' END
        AND pg_catalog.pg_get_expr(p.polwithcheck, p.polrelid) IS NOT DISTINCT FROM
          CASE WHEN expected.checks_new THEN '(bucket_id IS DISTINCT FROM ''vocab-audio''::text)' END);
$$;
REVOKE ALL ON FUNCTION e2e_private.audio_storage_writes_ready() FROM PUBLIC, anon, authenticated;

-- 018 moved the installed 015 function verbatim. Both versions inspect the
-- owner keys and tombstone triggers. Require 016's write-order guard as well.
ALTER FUNCTION e2e_private.e2e_patrol_contract() RENAME TO e2e_patrol_owner_contract;
REVOKE ALL ON FUNCTION e2e_private.e2e_patrol_owner_contract() FROM PUBLIC, anon, authenticated;
CREATE FUNCTION e2e_private.e2e_patrol_contract()
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT CASE WHEN e2e_private.e2e_patrol_owner_contract() IN ('owner-scoped-v1', 'write-order-v1')
    AND public.vocabulary_sync_write_ready()
    THEN 'write-order-v1' END;
$$;
REVOKE ALL ON FUNCTION e2e_private.e2e_patrol_contract() FROM PUBLIC, anon, authenticated;

-- Keep every later readiness check. The new stamp lets preflight reject a
-- server that predates the Storage repair, even if it advertises v1.
ALTER FUNCTION public.e2e_patrol_contract() RENAME TO e2e_patrol_study_contract;
ALTER FUNCTION public.e2e_patrol_study_contract() SET SCHEMA e2e_private;
REVOKE ALL ON FUNCTION e2e_private.e2e_patrol_study_contract() FROM PUBLIC, anon, authenticated;
CREATE FUNCTION public.e2e_patrol_contract()
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT CASE WHEN e2e_private.e2e_patrol_study_contract() = 'study-catalog-v1'
    AND e2e_private.audio_storage_writes_ready()
    THEN 'study-catalog-v2' END;
$$;
REVOKE ALL ON FUNCTION public.e2e_patrol_contract() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.e2e_patrol_contract() TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.reset_e2e_account(p_scenario_id text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF public.e2e_patrol_contract() IS DISTINCT FROM 'study-catalog-v2' THEN
    RAISE EXCEPTION 'Patrol schema is unavailable; reset refused' USING ERRCODE = '55000';
  END IF;
  RETURN e2e_private.reset_e2e_account(p_scenario_id);
END $$;
REVOKE ALL ON FUNCTION public.reset_e2e_account(text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.reset_e2e_account(text) TO authenticated;

NOTIFY pgrst, 'reload schema';
COMMIT;
