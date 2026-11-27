"""Print the first E2E activation after its prerequisite migrations (no secrets)."""
from pathlib import Path

root = Path(__file__).resolve().parents[2]
print('-- Install E2E reset and per-scenario isolation together. No account is deleted.\nBEGIN;')
print('''DO $$ BEGIN
  IF to_regnamespace('e2e_private') IS NOT NULL
    OR to_regclass('public.review_events') IS NOT NULL THEN
    RAISE EXCEPTION 'E2E or security migrations already exist; apply only pending migrations';
  END IF;
END $$;''')
for name in (
    '008_e2e_reset.sql',
    '009_e2e_scenario_accounts.sql',
    '012_security_boundaries.sql',
    '013_e2e_isolation.sql',
):
    print(f'\n-- {name}')
    for line in (root / 'supabase/migrations' / name).read_text(encoding='utf-8').splitlines():
        if line.strip() not in ('BEGIN;', 'COMMIT;'):
            print(line)
print('\nCOMMIT;')
