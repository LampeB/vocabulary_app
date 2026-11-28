#!/usr/bin/env bash
set -euo pipefail
if [[ "${PGDATABASE:-}" != *_test ]]; then
  echo 'Refusing concurrency test outside an explicitly named *_test database' >&2
  exit 1
fi
psql -v ON_ERROR_STOP=1 <<'SQL'
INSERT INTO auth.users(id,email,raw_user_meta_data) VALUES
  ('82500000-0000-0000-0000-000000000001','purge_race@example.invalid','{"username":"purge_race"}');
INSERT INTO public.vocabulary_lists(id,owner_id,name) VALUES
  ('82500000-0000-0000-0000-000000000002','82500000-0000-0000-0000-000000000001','Purge race');
SQL
PGAPPNAME=ponderin-list-purge-test psql -v ON_ERROR_STOP=1 -c "BEGIN; DELETE FROM public.vocabulary_lists WHERE id='82500000-0000-0000-0000-000000000002'; SELECT pg_advisory_xact_lock(825020); SELECT pg_sleep(3); COMMIT;" &
purge_pid=$!
observed=false
for _ in {1..50}; do
  if [[ "$(psql -Atc "SELECT EXISTS(SELECT 1 FROM pg_locks WHERE locktype='advisory' AND objid=825020 AND granted)")" == t ]]; then
    observed=true
    break
  fi
  sleep 0.1
done
if [[ "$observed" != true ]]; then
  wait "$purge_pid"
  echo 'Did not reach the uncommitted vocabulary purge' >&2
  exit 1
fi
PGAPPNAME=ponderin-list-purge-writer psql -v ON_ERROR_STOP=1 <<'SQL' &
SELECT set_config('request.jwt.claim.sub','82500000-0000-0000-0000-000000000001',false);
SELECT set_config('request.method','POST',false);
SELECT set_config('request.headers',
  '{"x-ponderin-sync-writer":"82500000-0000-0000-0000-000000000003","x-ponderin-sync-sequence":"1"}',false);
SET ROLE authenticated;
DO $$ BEGIN
  BEGIN
    INSERT INTO public.vocabulary_lists(id,owner_id,name,sync_write_protocol)
      VALUES('82500000-0000-0000-0000-000000000002',auth.uid(),'Late concurrent edit',16)
      ON CONFLICT(owner_id,id) DO UPDATE SET name=excluded.name;
    RAISE EXCEPTION 'An overlapping write recreated a purged list';
  EXCEPTION WHEN SQLSTATE 'PV001' THEN NULL; END;
END $$;
SQL
writer_pid=$!
blocked=false
for _ in {1..20}; do
  if [[ "$(psql -Atc "SELECT EXISTS(SELECT 1 FROM pg_stat_activity writer JOIN pg_stat_activity purge ON purge.pid=ANY(pg_blocking_pids(writer.pid)) WHERE writer.application_name='ponderin-list-purge-writer' AND purge.application_name='ponderin-list-purge-test')")" == t ]]; then
    blocked=true
    break
  fi
  sleep 0.1
done
wait "$purge_pid"
wait "$writer_pid"
if [[ "$blocked" != true ]]; then
  echo 'The stale write did not overlap the uncommitted purge' >&2
  exit 1
fi
psql -v ON_ERROR_STOP=1 <<'SQL'
SELECT set_config('request.jwt.claim.sub','82500000-0000-0000-0000-000000000001',false);
SET ROLE authenticated;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM public.vocabulary_lists
      WHERE id='82500000-0000-0000-0000-000000000002')
    OR (SELECT count(*) FROM public.vocabulary_pull_inventory(auth.uid(),NULL)
      WHERE id='82500000-0000-0000-0000-000000000002' AND is_deleted) <> 1
    THEN RAISE EXCEPTION 'The purge did not leave a single synthetic tombstone'; END IF;
END $$;
RESET ROLE;
DELETE FROM auth.users WHERE id='82500000-0000-0000-0000-000000000001';
SQL
