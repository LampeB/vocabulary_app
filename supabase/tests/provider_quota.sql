-- Disposable PostgreSQL only, after migration 010. No paid-provider calls.
BEGIN;
INSERT INTO auth.users (id,email,raw_user_meta_data) VALUES
 ('00000000-0000-0000-0000-000000000010','provider_quota@example.invalid',
  '{"username":"provider_quota"}');
DO $$
DECLARE
  uid uuid := '00000000-0000-0000-0000-000000000010';
  first jsonb;
  next jsonb;
  i integer;
BEGIN
  IF has_function_privilege('authenticated', 'public.consume_provider_quota(uuid,text)', 'EXECUTE') OR
     has_function_privilege('anon', 'public.consume_provider_quota(uuid,text)', 'EXECUTE') OR
     has_function_privilege('authenticated', 'public.release_provider_speech(uuid,uuid)', 'EXECUTE') THEN
    RAISE EXCEPTION 'Client roles can access the trusted quota API';
  END IF;
  IF NOT has_function_privilege('service_role', 'public.consume_provider_quota(uuid,text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'Edge Functions cannot consume quotas';
  END IF;
  FOR i IN 1..200 LOOP
    IF NOT (public.consume_provider_quota(uid, 'translate')->>'allowed')::boolean THEN
      RAISE EXCEPTION 'Translation limit denied early at %', i;
    END IF;
  END LOOP;
  IF (public.consume_provider_quota(uid, 'translate')->>'allowed')::boolean THEN
    RAISE EXCEPTION 'Translation limit bypassed';
  END IF;
  first := public.consume_provider_quota(uid, 'cloud_stt');
  IF NOT (first->>'allowed')::boolean THEN RAISE EXCEPTION 'First speech denied'; END IF;
  next := public.consume_provider_quota(uid, 'cloud_stt');
  IF (next->>'allowed')::boolean THEN RAISE EXCEPTION 'Concurrent speech allowed'; END IF;
  PERFORM public.release_provider_speech(uid, gen_random_uuid());
  IF (public.consume_provider_quota(uid, 'cloud_stt')->>'allowed')::boolean THEN
    RAISE EXCEPTION 'An unrelated token released the lease';
  END IF;
  PERFORM public.release_provider_speech(uid, (first->>'lease')::uuid);
  FOR i IN 2..80 LOOP
    next := public.consume_provider_quota(uid, 'cloud_stt');
    IF NOT (next->>'allowed')::boolean THEN RAISE EXCEPTION 'Hourly limit denied early'; END IF;
    PERFORM public.release_provider_speech(uid, (next->>'lease')::uuid);
  END LOOP;
  IF (public.consume_provider_quota(uid, 'cloud_stt')->>'allowed')::boolean THEN
    RAISE EXCEPTION 'Hourly speech cap bypassed';
  END IF;
  DELETE FROM public.provider_quota_buckets WHERE metric = 'cloud_stt_hour';
  UPDATE public.provider_quota_buckets SET calls = 300 WHERE metric = 'cloud_stt';
  IF (public.consume_provider_quota(uid, 'cloud_stt')->>'allowed')::boolean THEN
    RAISE EXCEPTION 'Daily speech cap bypassed';
  END IF;
  DELETE FROM public.provider_quota_buckets WHERE metric LIKE 'cloud_stt%';
  first := public.consume_provider_quota(uid, 'cloud_stt');
  UPDATE public.provider_speech_leases SET expires_at = now() - interval '1 second';
  next := public.consume_provider_quota(uid, 'cloud_stt');
  IF NOT (next->>'allowed')::boolean THEN RAISE EXCEPTION 'Expired lease did not recover'; END IF;
  PERFORM public.release_provider_speech(uid, (first->>'lease')::uuid);
  IF (public.consume_provider_quota(uid, 'cloud_stt')->>'allowed')::boolean THEN
    RAISE EXCEPTION 'Late release removed a newer lease';
  END IF;
  BEGIN
    PERFORM public.consume_provider_quota(uid, 'client_selected_metric');
    RAISE EXCEPTION 'Unknown metric accepted';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM <> 'Unknown provider quota metric' THEN RAISE; END IF;
  END;
END;
$$;
ROLLBACK;
