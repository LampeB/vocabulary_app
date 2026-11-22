-- Run only against a disposable database with the migrations installed.
-- Fixtures and the intentional failure trigger are rolled back at the end.
BEGIN;
-- Emulate the optional hosted history table, absent from the base schema.
CREATE TABLE IF NOT EXISTS public.review_events (id uuid DEFAULT gen_random_uuid(), user_id uuid REFERENCES auth.users(id));
INSERT INTO auth.users (id, email, raw_user_meta_data) VALUES
  ('00000000-0000-0000-0000-000000000001', 'reset-test@example.invalid', '{"username":"reset_test"}'),
  ('00000000-0000-0000-0000-000000000002', 'other-test@example.invalid', '{"username":"other_test"}');
INSERT INTO e2e_private.accounts VALUES ('00000000-0000-0000-0000-000000000001', 'reset_test');
INSERT INTO public.vocabulary_lists (id, owner_id, name) VALUES
  ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'remove me'),
  ('10000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000002', 'keep me');
INSERT INTO public.concepts (id, list_id) VALUES
  ('20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001');
INSERT INTO public.word_variants (id, concept_id, word, lang_code) VALUES
  ('30000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', 'bonjour', 'fr');
INSERT INTO public.variant_progress (user_id, variant_id, direction) VALUES
  ('00000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001', 'frToKo');
INSERT INTO public.subscriptions (user_id, tier) VALUES ('00000000-0000-0000-0000-000000000001', 'premium');
INSERT INTO public.notifications (user_id, type) VALUES ('00000000-0000-0000-0000-000000000001', 'test');
INSERT INTO public.leaderboard_entries (user_id, period, score) VALUES ('00000000-0000-0000-0000-000000000001', 'test', 100);
INSERT INTO public.friend_requests (from_user_id, to_user_id) VALUES
  ('00000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000001');
INSERT INTO public.friendships (user_a_id, user_b_id) VALUES
  ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002');
INSERT INTO public.challenges (list_id, challenger_id, challenged_id) VALUES
  ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000001');
INSERT INTO public.review_events (user_id) VALUES ('00000000-0000-0000-0000-000000000001');
UPDATE public.profiles SET is_premium = true, subscription_type = 'premium', current_streak = 12,
  bio = 'old state' WHERE id = '00000000-0000-0000-0000-000000000001';

DO $$ BEGIN
  IF NOT (SELECT relrowsecurity FROM pg_class WHERE oid = 'e2e_private.accounts'::regclass) THEN
    RAISE EXCEPTION 'Allowlist RLS must be enabled';
  END IF;
  IF has_function_privilege('anon', 'public.reset_e2e_account()', 'EXECUTE')
    OR has_table_privilege('authenticated', 'e2e_private.accounts', 'INSERT') THEN
    RAISE EXCEPTION 'Reset permissions are too broad';
  END IF;
  PERFORM set_config('request.jwt.claim.sub', '', true);
  BEGIN
    PERFORM public.reset_e2e_account();
    RAISE EXCEPTION 'Unauthenticated reset was accepted';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  PERFORM set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000002', true);
  BEGIN
    PERFORM public.reset_e2e_account();
    RAISE EXCEPTION 'Non-enrolled user reset was accepted';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;

SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000001', true);
SET LOCAL ROLE authenticated;
SELECT public.reset_e2e_account();
SELECT public.reset_e2e_account(); -- Idempotence under the real caller role.
RESET ROLE;
DO $$ BEGIN
  IF (SELECT count(*) FROM public.vocabulary_lists) <> 1
    OR NOT EXISTS (SELECT 1 FROM public.vocabulary_lists WHERE name = 'keep me')
    OR (SELECT count(*) FROM auth.users) <> 2
    OR EXISTS (SELECT 1 FROM public.concepts)
    OR EXISTS (SELECT 1 FROM public.word_variants)
    OR EXISTS (SELECT 1 FROM public.variant_progress)
    OR EXISTS (SELECT 1 FROM public.review_events)
    OR EXISTS (SELECT 1 FROM public.subscriptions)
    OR EXISTS (SELECT 1 FROM public.notifications)
    OR EXISTS (SELECT 1 FROM public.leaderboard_entries)
    OR EXISTS (SELECT 1 FROM public.friend_requests)
    OR EXISTS (SELECT 1 FROM public.friendships)
    OR EXISTS (SELECT 1 FROM public.challenges)
    OR NOT EXISTS (SELECT 1 FROM public.profiles WHERE username = 'reset_test'
      AND is_premium = false AND subscription_type = 'free' AND current_streak = 0 AND bio IS NULL)
    OR NOT EXISTS (SELECT 1 FROM public.profiles WHERE username = 'other_test')
  THEN RAISE EXCEPTION 'Reset, cascade, identity preservation or isolation failed'; END IF;
END $$;

-- A failing final profile insert must undo all earlier deletes.
INSERT INTO public.vocabulary_lists (owner_id, name) VALUES ('00000000-0000-0000-0000-000000000001', 'rollback me');
CREATE FUNCTION e2e_private.fail_profile_insert() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN RAISE EXCEPTION 'Injected failure' USING ERRCODE = '23514'; END $$;
CREATE TRIGGER e2e_fail BEFORE INSERT ON public.profiles FOR EACH ROW EXECUTE FUNCTION e2e_private.fail_profile_insert();
DO $$ BEGIN
  BEGIN
    PERFORM public.reset_e2e_account();
    RAISE EXCEPTION 'Expected injected failure';
  EXCEPTION WHEN check_violation THEN NULL; END;
  IF NOT EXISTS (SELECT 1 FROM public.vocabulary_lists WHERE name = 'rollback me')
    OR NOT EXISTS (SELECT 1 FROM public.profiles WHERE username = 'reset_test') THEN
    RAISE EXCEPTION 'Reset did not roll back atomically';
  END IF;
END $$;
ROLLBACK;
