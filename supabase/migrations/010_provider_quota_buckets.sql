-- Only trusted Edge Functions may consume paid-provider quotas. The user ID
-- comes from an Auth getUser verification, never from a client request body.
CREATE TABLE public.provider_quota_buckets (
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  metric text NOT NULL,
  window_start timestamptz NOT NULL,
  calls integer NOT NULL DEFAULT 0 CHECK (calls >= 0),
  PRIMARY KEY (user_id, metric, window_start)
);
CREATE TABLE public.provider_speech_leases (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  token uuid NOT NULL,
  expires_at timestamptz NOT NULL
);
ALTER TABLE public.provider_quota_buckets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.provider_speech_leases ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.provider_quota_buckets FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.provider_speech_leases FROM PUBLIC, anon, authenticated;

CREATE FUNCTION public.consume_provider_quota(p_user_id uuid, p_metric text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_limit integer;
  v_window timestamptz := date_trunc('day', now() AT TIME ZONE 'UTC') AT TIME ZONE 'UTC';
  v_hour timestamptz := date_trunc('hour', now() AT TIME ZONE 'UTC') AT TIME ZONE 'UTC';
  v_token uuid;
BEGIN
  IF p_user_id IS NULL THEN RETURN jsonb_build_object('allowed', false); END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended(p_user_id::text, 1031));
  CASE p_metric
    WHEN 'cloud_stt' THEN v_limit := 300;
    WHEN 'translate' THEN v_limit := 200;
    WHEN 'suggest' THEN v_limit := 25;
    WHEN 'grammar_exercises' THEN v_limit := 20;
    WHEN 'audio_provision' THEN v_limit := 500;
    ELSE RAISE EXCEPTION 'Unknown provider quota metric';
  END CASE;
  IF EXISTS (SELECT 1 FROM public.provider_quota_buckets
      WHERE user_id = p_user_id AND metric = p_metric AND window_start = v_window
        AND calls >= v_limit) THEN
    RETURN jsonb_build_object('allowed', false);
  END IF;
  IF p_metric = 'cloud_stt' THEN
    IF EXISTS (SELECT 1 FROM public.provider_speech_leases
        WHERE user_id = p_user_id AND expires_at > now()) OR
       EXISTS (SELECT 1 FROM public.provider_quota_buckets
        WHERE user_id = p_user_id AND metric = 'cloud_stt_hour'
          AND window_start = v_hour AND calls >= 80) THEN
      RETURN jsonb_build_object('allowed', false);
    END IF;
    v_token := gen_random_uuid();
    INSERT INTO public.provider_speech_leases VALUES (p_user_id, v_token, now() + interval '90 seconds')
      ON CONFLICT (user_id) DO UPDATE SET token = EXCLUDED.token, expires_at = EXCLUDED.expires_at;
    INSERT INTO public.provider_quota_buckets VALUES (p_user_id, 'cloud_stt_hour', v_hour, 1)
      ON CONFLICT (user_id, metric, window_start) DO UPDATE
      SET calls = public.provider_quota_buckets.calls + 1;
  END IF;
  INSERT INTO public.provider_quota_buckets VALUES (p_user_id, p_metric, v_window, 1)
    ON CONFLICT (user_id, metric, window_start) DO UPDATE
    SET calls = public.provider_quota_buckets.calls + 1;
  DELETE FROM public.provider_quota_buckets
    WHERE user_id = p_user_id AND window_start < now() - interval '32 days';
  RETURN jsonb_build_object('allowed', true, 'lease', v_token);
END;
$$;

CREATE FUNCTION public.release_provider_speech(p_user_id uuid, p_token uuid)
RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path = '' AS $$
  DELETE FROM public.provider_speech_leases WHERE user_id = p_user_id AND token = p_token;
$$;

REVOKE ALL ON FUNCTION public.consume_provider_quota(uuid, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.release_provider_speech(uuid, uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.consume_provider_quota(uuid, text) TO service_role;
GRANT EXECUTE ON FUNCTION public.release_provider_speech(uuid, uuid) TO service_role;
