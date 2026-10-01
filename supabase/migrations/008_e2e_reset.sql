-- Opt-in only: the allowlist starts empty and is writable only by administrators.
BEGIN;
CREATE SCHEMA IF NOT EXISTS e2e_private;
REVOKE ALL ON SCHEMA e2e_private FROM PUBLIC, anon, authenticated;
CREATE TABLE IF NOT EXISTS e2e_private.accounts (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username text UNIQUE NOT NULL CHECK (length(username) >= 3)
);
REVOKE ALL ON e2e_private.accounts FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.reset_e2e_account()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  uid uuid := auth.uid();
  baseline_username text;
  history_table text;
  remaining boolean;
BEGIN
  SELECT username INTO baseline_username FROM e2e_private.accounts
    WHERE user_id = uid FOR UPDATE;
  IF uid IS NULL OR baseline_username IS NULL THEN
    RAISE EXCEPTION 'This account is not enrolled for E2E reset' USING ERRCODE = '42501';
  END IF;

  -- These histories are local in the base schema; some hosted projects also
  -- expose them for sync. Explicit names only, never arbitrary caller input.
  FOREACH history_table IN ARRAY ARRAY['review_events', 'quiz_sessions', 'grammar_progress'] LOOP
    IF to_regclass('public.' || history_table) IS NOT NULL THEN
      EXECUTE format('DELETE FROM public.%I WHERE user_id = $1', history_table) USING uid;
      EXECUTE format('SELECT EXISTS (SELECT 1 FROM public.%I WHERE user_id = $1)', history_table)
        INTO remaining USING uid;
      IF remaining THEN RAISE EXCEPTION 'E2E history reset failed'; END IF;
    END IF;
  END LOOP;

  -- Remove dependent social rows first, including challenges targeting a list.
  DELETE FROM public.challenges WHERE challenger_id = uid OR challenged_id = uid
    OR list_id IN (SELECT id FROM public.vocabulary_lists WHERE owner_id = uid);
  DELETE FROM public.friend_requests WHERE from_user_id = uid OR to_user_id = uid;
  DELETE FROM public.friendships WHERE user_a_id = uid OR user_b_id = uid;
  DELETE FROM public.notifications WHERE user_id = uid;
  DELETE FROM public.leaderboard_entries WHERE user_id = uid;
  DELETE FROM public.subscriptions WHERE user_id = uid;
  -- Includes progress on someone else's lists; own-list descendants cascade.
  DELETE FROM public.variant_progress WHERE user_id = uid;
  DELETE FROM public.vocabulary_lists WHERE owner_id = uid;
  DELETE FROM public.profiles WHERE id = uid;
  INSERT INTO public.profiles (id, username, display_name)
    VALUES (uid, baseline_username, baseline_username);

  IF EXISTS (SELECT 1 FROM public.vocabulary_lists WHERE owner_id = uid)
    OR EXISTS (SELECT 1 FROM public.variant_progress WHERE user_id = uid)
    OR EXISTS (SELECT 1 FROM public.subscriptions WHERE user_id = uid)
    OR EXISTS (SELECT 1 FROM public.notifications WHERE user_id = uid)
    OR EXISTS (SELECT 1 FROM public.leaderboard_entries WHERE user_id = uid)
    OR EXISTS (SELECT 1 FROM public.friend_requests WHERE from_user_id = uid OR to_user_id = uid)
    OR EXISTS (SELECT 1 FROM public.friendships WHERE user_a_id = uid OR user_b_id = uid)
    OR EXISTS (SELECT 1 FROM public.challenges WHERE challenger_id = uid OR challenged_id = uid)
  THEN
    RAISE EXCEPTION 'E2E reset postcondition failed';
  END IF;
  RETURN jsonb_build_object('user_id', uid, 'baseline', 'empty-free-v1',
    'username', baseline_username);
END;
$$;
REVOKE ALL ON FUNCTION public.reset_e2e_account() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.reset_e2e_account() TO authenticated;
COMMIT;
