#!/usr/bin/env bash
# Disposable PostgreSQL only, after migration 022.
set -euo pipefail
if [[ "${PGDATABASE:-}" != *_test ]]; then
  echo 'Refusing concurrency test outside an explicitly named *_test database' >&2
  exit 1
fi
psql -v ON_ERROR_STOP=1 <<'SQL'
INSERT INTO auth.users(id,email,raw_user_meta_data) VALUES
  ('82200000-0000-4000-8000-000000000001','study_race@example.invalid','{"username":"study_race"}');
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','82200000-0000-4000-8000-000000000001',false);
SELECT public.record_study_day(auth.uid(),date '2026-11-20' + day)
  FROM generate_series(0,4) day;
RESET ROLE;
SQL
PGAPPNAME=ponderin-study-day-first psql -v ON_ERROR_STOP=1 -c "BEGIN; SET ROLE authenticated; SELECT set_config('request.jwt.claim.sub','82200000-0000-4000-8000-000000000001',true); SELECT public.record_study_day(auth.uid(),'2026-11-26'); SELECT pg_advisory_xact_lock(822022); SELECT pg_sleep(3); COMMIT;" &
first_pid=$!
observed=false
for _ in {1..50}; do
  if [[ "$(psql -Atc "SELECT EXISTS(SELECT 1 FROM pg_locks WHERE locktype='advisory' AND objid=822022 AND granted)")" == t ]]; then
    observed=true
    break
  fi
  sleep 0.1
done
if [[ "$observed" != true ]]; then
  wait "$first_pid"
  echo 'Did not reach the uncommitted later study day' >&2
  exit 1
fi
PGAPPNAME=ponderin-study-day-second psql -v ON_ERROR_STOP=1 <<'SQL' &
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','82200000-0000-4000-8000-000000000001',false);
SELECT public.record_study_day(auth.uid(),'2026-11-25');
SQL
second_pid=$!
blocked=false
for _ in {1..20}; do
  if [[ "$(psql -Atc "SELECT EXISTS(SELECT 1 FROM pg_stat_activity writer JOIN pg_stat_activity first ON first.pid=ANY(pg_blocking_pids(writer.pid)) WHERE writer.application_name='ponderin-study-day-second' AND first.application_name='ponderin-study-day-first')")" == t ]]; then
    blocked=true
    break
  fi
  sleep 0.1
done
wait "$first_pid"
wait "$second_pid"
if [[ "$blocked" != true ]]; then
  echo 'Concurrent study days did not serialize on the profile' >&2
  exit 1
fi
psql -v ON_ERROR_STOP=1 <<'SQL'
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id='82200000-0000-4000-8000-000000000001'
    AND (current_streak,longest_streak,last_study_date)=(7,7,date '2026-11-26')) THEN
    RAISE EXCEPTION 'Concurrent out-of-order study days lost the streak';
  END IF;
END $$;
DELETE FROM auth.users WHERE id='82200000-0000-4000-8000-000000000001';
SQL
