BEGIN;

-- Private audio is authorized by the server's owner-scoped namespace, never
-- by a client-writable audio_path reference on a vocabulary row.
-- A trusted publishing manifest also prevents legacy incorrectly generated
-- seed/ objects from remaining globally readable after this migration.
CREATE TABLE public.published_audio_assets(path text PRIMARY KEY CHECK (path LIKE 'seed/%'));
ALTER TABLE public.published_audio_assets ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.published_audio_assets FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.published_audio_assets TO authenticated;
GRANT ALL ON public.published_audio_assets TO service_role;
CREATE POLICY published_audio_read ON public.published_audio_assets FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "vocab audio pending activation" ON storage.objects;
DROP POLICY IF EXISTS "vocab audio authenticated read" ON storage.objects;
CREATE POLICY "vocab audio authenticated read" ON storage.objects FOR SELECT TO authenticated
USING (bucket_id = 'vocab-audio');
-- Storage policies from other buckets can be permissive. These restrictive
-- rules still apply to every vocab-audio read for the respective client role.
CREATE POLICY "vocab audio authenticated boundary" ON storage.objects
AS RESTRICTIVE FOR SELECT TO authenticated
USING (bucket_id IS DISTINCT FROM 'vocab-audio'
  OR EXISTS(SELECT 1 FROM public.published_audio_assets p WHERE p.path = storage.objects.name)
  OR (split_part(name, '/', 1) = 'users' AND split_part(name, '/', 2) = auth.uid()::text));
CREATE POLICY "vocab audio anonymous boundary" ON storage.objects
AS RESTRICTIVE FOR SELECT TO anon
USING (bucket_id IS DISTINCT FROM 'vocab-audio');

DROP POLICY IF EXISTS lists_public ON public.vocabulary_lists;
CREATE POLICY lists_public ON public.vocabulary_lists FOR SELECT TO authenticated
USING (visibility = 'public' AND is_deleted IS NOT TRUE);
CREATE POLICY concepts_public_read ON public.concepts FOR SELECT TO authenticated
USING (is_deleted IS NOT TRUE AND EXISTS (
  SELECT 1 FROM public.vocabulary_lists l WHERE l.id = list_id
    AND l.visibility = 'public' AND l.is_deleted IS NOT TRUE));
CREATE POLICY variants_public_read ON public.word_variants FOR SELECT TO authenticated
USING (is_deleted IS NOT TRUE AND EXISTS (
  SELECT 1 FROM public.concepts c JOIN public.vocabulary_lists l ON l.id = c.list_id
  WHERE c.id = concept_id AND c.is_deleted IS NOT TRUE
    AND l.visibility = 'public' AND l.is_deleted IS NOT TRUE));

-- Append-only review history. Variant IDs remain text because grammar cards
-- use synthetic IDs; history is retained independently from content deletion.
CREATE TABLE public.review_events (
  id uuid PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  variant_id text NOT NULL CHECK (length(variant_id) BETWEEN 1 AND 256),
  direction text NOT NULL CHECK (length(direction) BETWEEN 3 AND 24),
  list_id uuid,
  mode text NOT NULL CHECK (mode IN ('flashcard', 'typing', 'voice', 'handsFree')),
  correct boolean NOT NULL,
  rating text NOT NULL CHECK (rating IN ('again', 'hard', 'good', 'easy')),
  response_time_ms integer CHECK (response_time_ms >= 0),
  retry_count integer CHECK (retry_count >= 0),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX review_events_user_time ON public.review_events(user_id, created_at DESC);
ALTER TABLE public.review_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.review_events FROM PUBLIC, anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.review_events TO authenticated;
CREATE POLICY review_events_own ON public.review_events TO authenticated
USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

-- One paid render per immutable object. Expiry exceeds the 60s provider
-- timeout and releases stranded leases after an Edge Function crash.
CREATE TABLE public.audio_generation_leases (
  path text PRIMARY KEY,
  token uuid NOT NULL,
  expires_at timestamptz NOT NULL
);
ALTER TABLE public.audio_generation_leases ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.audio_generation_leases FROM PUBLIC, anon, authenticated;
CREATE FUNCTION public.acquire_audio_generation(p_user_id uuid, p_path text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_token uuid := gen_random_uuid(); v_result uuid;
BEGIN
  IF p_user_id IS NULL OR length(p_path) > 512 OR
    p_path NOT LIKE 'users/' || p_user_id::text || '/%' THEN
    RAISE EXCEPTION 'Invalid audio namespace' USING ERRCODE = '42501';
  END IF;
  INSERT INTO public.audio_generation_leases VALUES(p_path, v_token, now() + interval '90 seconds')
    ON CONFLICT(path) DO UPDATE SET token = EXCLUDED.token, expires_at = EXCLUDED.expires_at
    WHERE public.audio_generation_leases.expires_at <= now()
    RETURNING token INTO v_result;
  RETURN v_result;
END $$;
CREATE FUNCTION public.release_audio_generation(p_path text, p_token uuid)
RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path = '' AS $$
  DELETE FROM public.audio_generation_leases WHERE path = p_path AND token = p_token;
$$;
REVOKE ALL ON FUNCTION public.acquire_audio_generation(uuid,text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.release_audio_generation(text,uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.acquire_audio_generation(uuid,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.release_audio_generation(text,uuid) TO service_role;

-- Prevent a social/progress writer entering between the reset's shared-data
-- check and its deletes. These transaction-duration locks conflict with DML;
-- a writer arriving later waits and then sees the post-reset FK state.
CREATE OR REPLACE FUNCTION public.reset_e2e_account(p_scenario_id text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE uid uuid := auth.uid(); registered text; result jsonb;
BEGIN
  SELECT scenario_id INTO registered FROM e2e_private.accounts WHERE user_id = uid FOR UPDATE;
  IF uid IS NULL OR registered IS NULL OR p_scenario_id IS NULL OR registered <> p_scenario_id THEN
    RAISE EXCEPTION 'Account does not belong to this E2E scenario' USING ERRCODE = '42501';
  END IF;
  LOCK TABLE public.vocabulary_lists, public.concepts, public.word_variants,
    public.variant_progress, public.friendships, public.friend_requests,
    public.challenges IN SHARE ROW EXCLUSIVE MODE;
  IF EXISTS (SELECT 1 FROM public.friendships WHERE user_a_id = uid OR user_b_id = uid)
    OR EXISTS (SELECT 1 FROM public.friend_requests WHERE from_user_id = uid OR to_user_id = uid)
    OR EXISTS (SELECT 1 FROM public.challenges WHERE challenger_id = uid OR challenged_id = uid
      OR list_id IN (SELECT id FROM public.vocabulary_lists WHERE owner_id = uid))
    OR EXISTS (SELECT 1 FROM public.variant_progress p JOIN public.word_variants w ON w.id = p.variant_id
      JOIN public.concepts c ON c.id = w.concept_id JOIN public.vocabulary_lists l ON l.id = c.list_id
      WHERE l.owner_id = uid AND p.user_id IS DISTINCT FROM uid) THEN
    RAISE EXCEPTION 'E2E account has shared data; reset refused to protect other accounts'
      USING ERRCODE = '23503';
  END IF;
  result := e2e_private.reset_e2e_account();
  RETURN result || jsonb_build_object('scenario_id', registered);
END $$;
REVOKE ALL ON FUNCTION public.reset_e2e_account(text) FROM PUBLIC, anon, authenticated;
NOTIFY pgrst, 'reload schema';
COMMIT;
