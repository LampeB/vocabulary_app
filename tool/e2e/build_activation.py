"""Print the first E2E activation after its prerequisite migrations (no secrets)."""
from pathlib import Path

root = Path(__file__).resolve().parents[2]
print('-- Install the E2E reset and its security and sync prerequisites together. No account is deleted.\nBEGIN;')
print('''DO $$ BEGIN
  IF to_regnamespace('e2e_private') IS NOT NULL
    OR to_regclass('public.review_events') IS NOT NULL
    OR to_regprocedure('public.keep_vocabulary_tombstone()') IS NOT NULL THEN
    RAISE EXCEPTION 'E2E or security migrations already exist; apply only pending migrations';
  END IF;
END $$;''')
for name in (
    '008_e2e_reset.sql',
    '009_e2e_scenario_accounts.sql',
    '012_security_boundaries.sql',
    '013_e2e_isolation.sql',
    '014_vocabulary_tombstones.sql',
    '015_vocabulary_owner_namespace.sql',
    '016_vocabulary_write_order.sql',
    '017_vocabulary_pull_catchup.sql',
    '018_vocabulary_progress_boundaries.sql',
    '019_challenge_list_boundaries.sql',
    '020_vocabulary_physical_purges.sql',
    '021_friendship_consent.sql',
    '022_study_days.sql',
    '023_purge_catalog_identity.sql',
    '024_vocabulary_content_visibility.sql',
):
    print(f'\n-- {name}')
    for line in (root / 'supabase/migrations' / name).read_text(encoding='utf-8').splitlines():
        if line.strip() not in ('BEGIN;', 'COMMIT;'):
            print(line)
print('\nCOMMIT;')
