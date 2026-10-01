"""Non-secret scenario catalog and strict per-scenario credential validation."""
import json
import re
from pathlib import Path
from uuid import UUID

CATALOG = Path(__file__).with_name('scenarios.json')


def scenarios():
    return json.loads(CATALOG.read_text())


def validate_accounts(accounts, required):
    if not isinstance(accounts, dict) or not accounts:
        raise ValueError('E2E_ACCOUNTS_JSON must be a nonempty account map')
    users, emails = set(), set()
    for scenario, account in accounts.items():
        if not re.fullmatch(r'[a-z0-9_]+\.[a-z0-9_]+', scenario):
            raise ValueError('Invalid scenario ID')
        if not isinstance(account, dict) or any(
            not isinstance(account.get(k), str) or not account[k].strip()
            for k in ('user_id', 'email', 'password', 'username')
        ):
            raise ValueError(f'Incomplete account for scenario {scenario}')
        user = str(UUID(account['user_id']))
        email = account['email'].strip().lower()
        if user in users or email in emails:
            raise ValueError('An account cannot be shared by multiple scenarios')
        users.add(user)
        emails.add(email)
    missing = set(required) - accounts.keys()
    if missing:
        raise ValueError('Missing scenario accounts: ' + ', '.join(sorted(missing)))
    return accounts


def write_private(path, value):
    import os
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + '.tmp')
    fd = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    os.fchmod(fd, 0o600)
    with os.fdopen(fd, 'w') as output:
        json.dump(value, output, indent=2)
        output.write('\n')
    temporary.replace(path)
