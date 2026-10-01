-- Each permanent account belongs to exactly one immutable scenario ID.
-- Existing shared accounts remain unassigned and cannot use the new RPC.
BEGIN;
ALTER TABLE e2e_private.accounts
  ADD COLUMN IF NOT EXISTS scenario_id text UNIQUE
    CHECK (scenario_id ~ '^[a-z0-9_]+[.][a-z0-9_]+$');

-- Keep the transactional reset implementation private. Remove the public
-- no-argument entry point so old clients cannot bypass scenario binding.
DO $$ BEGIN
  IF to_regprocedure('public.reset_e2e_account()') IS NOT NULL THEN
    IF to_regprocedure('e2e_private.reset_e2e_account()') IS NULL THEN
      ALTER FUNCTION public.reset_e2e_account() SET SCHEMA e2e_private;
    ELSE
      DROP FUNCTION public.reset_e2e_account();
    END IF;
  END IF;
END $$;
REVOKE ALL ON FUNCTION e2e_private.reset_e2e_account() FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.reset_e2e_account(p_scenario_id text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  uid uuid := auth.uid();
  registered text;
  result jsonb;
BEGIN
  SELECT scenario_id INTO registered FROM e2e_private.accounts
    WHERE user_id = uid FOR UPDATE;
  IF uid IS NULL OR registered IS NULL OR p_scenario_id IS NULL
      OR registered <> p_scenario_id THEN
    RAISE EXCEPTION 'Account does not belong to this E2E scenario' USING ERRCODE = '42501';
  END IF;
  -- Fail instead of deleting shared rows or cascading into another learner.
  IF EXISTS (SELECT 1 FROM public.friendships WHERE user_a_id = uid OR user_b_id = uid)
    OR EXISTS (SELECT 1 FROM public.friend_requests WHERE from_user_id = uid OR to_user_id = uid)
    OR EXISTS (SELECT 1 FROM public.challenges WHERE challenger_id = uid OR challenged_id = uid
      OR list_id IN (SELECT id FROM public.vocabulary_lists WHERE owner_id = uid))
    OR EXISTS (SELECT 1 FROM public.variant_progress p
      JOIN public.word_variants w ON w.id = p.variant_id
      JOIN public.concepts c ON c.id = w.concept_id
      JOIN public.vocabulary_lists l ON l.id = c.list_id
      WHERE l.owner_id = uid AND p.user_id IS DISTINCT FROM uid)
  THEN
    RAISE EXCEPTION 'E2E account has shared data; reset refused to protect other accounts'
      USING ERRCODE = '23503';
  END IF;
  result := e2e_private.reset_e2e_account();
  RETURN result || jsonb_build_object('scenario_id', registered);
END $$;
REVOKE ALL ON FUNCTION public.reset_e2e_account(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.reset_e2e_account(text) TO authenticated;

-- Provisioning only: the service-role credential never goes into the test APK.
CREATE OR REPLACE FUNCTION public.enroll_e2e_account(
  p_user_id uuid, p_scenario_id text, p_username text
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id = p_user_id
    AND raw_app_meta_data->>'e2e_managed_by' = 'vocabkr'
    AND raw_app_meta_data->>'e2e_scenario_id' = p_scenario_id) THEN
    RAISE EXCEPTION 'Only provisioned scenario accounts can be enrolled' USING ERRCODE = '42501';
  END IF;
  INSERT INTO e2e_private.accounts (user_id, username, scenario_id)
    VALUES (p_user_id, p_username, p_scenario_id)
    ON CONFLICT (user_id) DO NOTHING;
  IF NOT EXISTS (SELECT 1 FROM e2e_private.accounts WHERE user_id = p_user_id
      AND scenario_id = p_scenario_id AND username = p_username) THEN
    RAISE EXCEPTION 'Account binding cannot be reassigned' USING ERRCODE = '23505';
  END IF;
END $$;
REVOKE ALL ON FUNCTION public.enroll_e2e_account(uuid,text,text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.enroll_e2e_account(uuid,text,text) TO service_role;
NOTIFY pgrst, 'reload schema';
COMMIT;
