BEGIN;

-- Both callers use the same atomic lease without sharing path privileges.
CREATE FUNCTION vocabulary_private.acquire_audio_generation_lease(p_path text)
RETURNS uuid LANGUAGE sql SET search_path = '' AS $$
  INSERT INTO public.audio_generation_leases AS lease(path, token, expires_at)
  VALUES (p_path, gen_random_uuid(), now() + interval '90 seconds')
  ON CONFLICT(path) DO UPDATE SET token = EXCLUDED.token, expires_at = EXCLUDED.expires_at
  WHERE lease.expires_at <= now()
  RETURNING token;
$$;
REVOKE ALL ON FUNCTION vocabulary_private.acquire_audio_generation_lease(text)
  FROM PUBLIC, anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION public.acquire_audio_generation(p_user_id uuid, p_path text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF p_user_id IS NULL OR p_path IS NULL OR length(p_path) > 512 OR
    p_path NOT LIKE 'users/' || p_user_id::text || '/%' THEN
    RAISE EXCEPTION 'Invalid audio namespace' USING ERRCODE = '42501';
  END IF;
  RETURN vocabulary_private.acquire_audio_generation_lease(p_path);
END $$;

CREATE FUNCTION public.acquire_seed_audio_generation(p_path text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF p_path IS NULL OR p_path COLLATE "C" !~ '^seed/v1/(fr|en|ko)/[0-9a-f]{64}\.mp3$' THEN
    RAISE EXCEPTION 'Invalid seed audio path' USING ERRCODE = '42501';
  END IF;
  RETURN vocabulary_private.acquire_audio_generation_lease(p_path);
END $$;
REVOKE ALL ON FUNCTION public.acquire_seed_audio_generation(text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.acquire_seed_audio_generation(text) TO service_role;

NOTIFY pgrst, 'reload schema';
COMMIT;
