"""Print the complete E2E SQL activation as a single transaction (no secrets)."""
from pathlib import Path

root = Path(__file__).resolve().parents[2]
print('-- Install E2E reset and per-scenario isolation together. No account is deleted.\nBEGIN;')
for name in ('008_e2e_reset.sql', '009_e2e_scenario_accounts.sql'):
    print(f'\n-- {name}')
    for line in (root / 'supabase/migrations' / name).read_text().splitlines():
        if line.strip() not in ('BEGIN;', 'COMMIT;'):
            print(line)
print('\nCOMMIT;')
