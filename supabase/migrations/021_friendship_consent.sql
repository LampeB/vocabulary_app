BEGIN;

-- Correct older installations of 012 as well as fresh ones.
REVOKE ALL ON public.review_events FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.review_events TO authenticated;

-- Earlier policies allowed either side to invent these rows. Retain existing
-- social history without treating it as proof of consent for list access.
ALTER TABLE public.friend_requests ADD COLUMN sender_verified boolean NOT NULL DEFAULT false;
ALTER TABLE public.friendships ADD COLUMN consent_verified boolean NOT NULL DEFAULT false;
ALTER TABLE public.friend_requests DROP CONSTRAINT friend_requests_from_user_id_to_user_id_key;
CREATE UNIQUE INDEX pending_verified_friend_request ON public.friend_requests(
  least(from_user_id,to_user_id),greatest(from_user_id,to_user_id))
  WHERE sender_verified AND status='pending';

REVOKE ALL ON public.friend_requests, public.friendships FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.friend_requests TO authenticated;
GRANT SELECT, DELETE ON public.friendships TO authenticated;
DROP POLICY IF EXISTS "Send friend request" ON public.friend_requests;
DROP POLICY IF EXISTS "Recipient can update status" ON public.friend_requests;
DROP POLICY IF EXISTS "Create friendship" ON public.friendships;
CREATE POLICY client_request_insert_denied ON public.friend_requests
  AS RESTRICTIVE FOR INSERT TO anon, authenticated WITH CHECK (false);
CREATE POLICY client_request_update_denied ON public.friend_requests
  AS RESTRICTIVE FOR UPDATE TO anon, authenticated USING (false) WITH CHECK (false);
CREATE POLICY client_request_delete_denied ON public.friend_requests
  AS RESTRICTIVE FOR DELETE TO anon, authenticated USING (false);
CREATE POLICY client_friendship_insert_denied ON public.friendships
  AS RESTRICTIVE FOR INSERT TO anon, authenticated WITH CHECK (false);
CREATE POLICY client_friendship_update_denied ON public.friendships
  AS RESTRICTIVE FOR UPDATE TO anon, authenticated USING (false) WITH CHECK (false);
CREATE POLICY client_friendship_member_remove ON public.friendships
  AS RESTRICTIVE FOR DELETE TO anon, authenticated
  USING (auth.uid() IN (user_a_id, user_b_id));

ALTER POLICY lists_friends ON public.vocabulary_lists USING (
  visibility = 'friends' AND is_deleted IS NOT TRUE AND EXISTS (
    SELECT 1 FROM public.friendships f
    WHERE f.consent_verified
      AND ((f.user_a_id = auth.uid() AND f.user_b_id = vocabulary_lists.owner_id)
        OR (f.user_b_id = auth.uid() AND f.user_a_id = vocabulary_lists.owner_id))
  )
);

CREATE FUNCTION public.send_friend_request(p_to_user_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  sender uuid := auth.uid();
BEGIN
  IF sender IS NULL OR p_to_user_id IS NULL OR sender = p_to_user_id THEN
    RAISE EXCEPTION 'Friend request unavailable' USING ERRCODE = '42501';
  END IF;
  LOCK TABLE public.friendships IN ROW EXCLUSIVE MODE;
  PERFORM pg_advisory_xact_lock(hashtextextended(
    least(sender,p_to_user_id)::text || greatest(sender,p_to_user_id)::text, 21));
  IF EXISTS (SELECT 1 FROM public.friendships
    WHERE user_a_id = least(sender, p_to_user_id) AND user_b_id = greatest(sender, p_to_user_id)
      AND consent_verified) THEN RETURN; END IF;

  INSERT INTO public.friend_requests(from_user_id,to_user_id,status,sender_verified)
    VALUES (sender,p_to_user_id,'pending',true)
    ON CONFLICT (least(from_user_id,to_user_id),greatest(from_user_id,to_user_id))
      WHERE sender_verified AND status='pending' DO NOTHING;
END $$;

CREATE FUNCTION public.respond_friend_request(p_request_id uuid, p_accept boolean)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  recipient uuid := auth.uid();
  sender uuid;
  next_status text := CASE WHEN p_accept THEN 'accepted' ELSE 'declined' END;
BEGIN
  IF recipient IS NULL OR p_accept IS NULL THEN
    RAISE EXCEPTION 'Friend request unavailable' USING ERRCODE = '42501';
  END IF;
  -- Use the same table lock order as the scenario reset.
  LOCK TABLE public.friendships IN ROW EXCLUSIVE MODE;
  SELECT from_user_id INTO sender FROM public.friend_requests
    WHERE id=p_request_id AND to_user_id=recipient AND from_user_id<>recipient AND sender_verified;
  IF NOT FOUND THEN RAISE EXCEPTION 'Friend request unavailable' USING ERRCODE = '42501'; END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended(
    least(sender,recipient)::text || greatest(sender,recipient)::text, 21));
  UPDATE public.friend_requests SET status=next_status
    WHERE id=p_request_id AND to_user_id=recipient AND from_user_id<>recipient
      AND status='pending' AND sender_verified;
  IF NOT FOUND THEN
    IF EXISTS (SELECT 1 FROM public.friend_requests WHERE id=p_request_id
      AND to_user_id=recipient AND from_user_id<>recipient AND status=next_status
      AND sender_verified) THEN RETURN; END IF;
    RAISE EXCEPTION 'Friend request unavailable' USING ERRCODE = '42501';
  END IF;
  IF p_accept THEN
    INSERT INTO public.friendships(user_a_id,user_b_id,consent_verified)
      VALUES (least(sender,recipient),greatest(sender,recipient),true)
      ON CONFLICT(user_a_id,user_b_id) DO UPDATE SET consent_verified=true;
  END IF;
END $$;

REVOKE ALL ON FUNCTION public.send_friend_request(uuid), public.respond_friend_request(uuid,boolean)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.send_friend_request(uuid), public.respond_friend_request(uuid,boolean)
  TO authenticated;

ALTER FUNCTION public.e2e_patrol_contract() RENAME TO e2e_patrol_challenge_contract;
ALTER FUNCTION public.e2e_patrol_challenge_contract() SET SCHEMA e2e_private;
REVOKE ALL ON FUNCTION e2e_private.e2e_patrol_challenge_contract() FROM PUBLIC, anon, authenticated;
CREATE FUNCTION public.e2e_patrol_contract()
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT CASE WHEN e2e_private.e2e_patrol_challenge_contract() = 'challenge-boundaries-v1'
    AND public.vocabulary_purge_ready()
    AND has_function_privilege('authenticated', 'public.send_friend_request(uuid)', 'EXECUTE')
    AND has_function_privilege('authenticated', 'public.respond_friend_request(uuid,boolean)', 'EXECUTE')
    AND NOT has_table_privilege('authenticated', 'public.friend_requests', 'INSERT,UPDATE,DELETE,TRUNCATE')
    AND NOT has_table_privilege('authenticated', 'public.friendships', 'INSERT,UPDATE,TRUNCATE')
    AND NOT has_table_privilege('authenticated', 'public.review_events', 'TRUNCATE,REFERENCES,TRIGGER')
    AND EXISTS (SELECT 1 FROM pg_catalog.pg_policy p
      WHERE polrelid = to_regclass('public.vocabulary_lists') AND polname = 'lists_friends'
        AND pg_catalog.pg_get_expr(p.polqual, p.polrelid) LIKE '%consent_verified%')
    THEN 'friend-consent-v1' END;
$$;
REVOKE ALL ON FUNCTION public.e2e_patrol_contract() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.e2e_patrol_contract() TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.reset_e2e_account(p_scenario_id text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF public.e2e_patrol_contract() IS DISTINCT FROM 'friend-consent-v1' THEN
    RAISE EXCEPTION 'Patrol schema is unavailable; reset refused' USING ERRCODE = '55000';
  END IF;
  RETURN e2e_private.reset_e2e_account(p_scenario_id);
END $$;
REVOKE ALL ON FUNCTION public.reset_e2e_account(text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.reset_e2e_account(text) TO authenticated;

NOTIFY pgrst, 'reload schema';
COMMIT;
