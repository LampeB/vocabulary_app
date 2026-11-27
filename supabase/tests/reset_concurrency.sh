#!/usr/bin/env bash
# Disposable PostgreSQL only, after bootstrap + migrations through 012.
set -euo pipefail
if [[ "${PGDATABASE:-}" != *_test ]]; then
  echo 'Refusing concurrency test outside an explicitly named *_test database' >&2
  exit 1
fi
psql -v ON_ERROR_STOP=1 <<'SQL'
INSERT INTO auth.users(id,email,raw_user_meta_data,raw_app_meta_data) VALUES
 ('50000000-0000-0000-0000-000000000001','race_a@example.invalid','{"username":"race_a"}',
  '{"e2e_managed_by":"vocabkr","e2e_scenario_id":"concurrency.a"}'),
 ('50000000-0000-0000-0000-000000000002','race_b@example.invalid','{"username":"race_b"}','{}');
SELECT public.enroll_e2e_account('50000000-0000-0000-0000-000000000001','concurrency.a','race_a');
INSERT INTO public.vocabulary_lists(id,owner_id,name) VALUES
 ('50000000-0000-0000-0000-000000000003','50000000-0000-0000-0000-000000000001','Concurrency fixture');
CREATE FUNCTION public.test_pause_reset() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN
  IF OLD.id='50000000-0000-0000-0000-000000000003' THEN
    PERFORM pg_advisory_lock(812012); PERFORM pg_sleep(3); PERFORM pg_advisory_unlock(812012);
  END IF; RETURN OLD;
END $$;
CREATE TRIGGER test_pause_reset BEFORE DELETE ON public.vocabulary_lists
  FOR EACH ROW EXECUTE FUNCTION public.test_pause_reset();
SQL
# First connection is paused after the shared-data check, inside deletion.
psql -v ON_ERROR_STOP=1 -c "SELECT set_config('request.jwt.claim.sub','50000000-0000-0000-0000-000000000001',false); SELECT public.reset_e2e_account('concurrency.a');" &
reset_pid=$!
observed=false
for _ in {1..50}; do
  if [[ "$(psql -Atc "SELECT EXISTS(SELECT 1 FROM pg_locks WHERE locktype='advisory' AND objid=812012 AND granted)")" == t ]]; then
    observed=true
    break
  fi
  sleep 0.1
done
if [[ "$observed" != true ]]; then
  wait "$reset_pid"
  echo 'Did not reach reset deletion boundary' >&2
  exit 1
fi
# Second connection attempts to create a cross-account relationship. It must
# wait for reset, then persist; it must never be deleted by that earlier reset.
psql -v ON_ERROR_STOP=1 -c "SET application_name='ponderin-reset-concurrent-writer'; INSERT INTO public.friendships(user_a_id,user_b_id) VALUES ('50000000-0000-0000-0000-000000000001','50000000-0000-0000-0000-000000000002');" &
writer_pid=$!
blocked=false
for _ in {1..20}; do
  if [[ "$(psql -Atc "SELECT EXISTS(SELECT 1 FROM pg_stat_activity WHERE application_name='ponderin-reset-concurrent-writer' AND wait_event_type='Lock')")" == t ]]; then
    blocked=true
    break
  fi
  sleep 0.1
done
wait "$reset_pid"
wait "$writer_pid"
if [[ "$blocked" != true ]]; then
  echo 'Concurrent relationship was not blocked across reset check/delete' >&2
  exit 1
fi
psql -v ON_ERROR_STOP=1 <<'SQL'
DO $$ BEGIN
  IF NOT EXISTS(SELECT 1 FROM public.friendships WHERE
    user_a_id='50000000-0000-0000-0000-000000000001' AND user_b_id='50000000-0000-0000-0000-000000000002') THEN
    RAISE EXCEPTION 'Reset deleted a relation created concurrently after its check';
  END IF;
END $$;
DROP TRIGGER test_pause_reset ON public.vocabulary_lists;
DROP FUNCTION public.test_pause_reset();
DELETE FROM public.friendships WHERE user_a_id='50000000-0000-0000-0000-000000000001';
DELETE FROM auth.users WHERE id IN ('50000000-0000-0000-0000-000000000001','50000000-0000-0000-0000-000000000002');
SQL
