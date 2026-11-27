"""Non-secret scenario catalog and strict per-scenario credential validation."""
from functools import cache
import json
import os
import re
from pathlib import Path
import subprocess
import tempfile
from uuid import UUID

CATALOG = Path(__file__).with_name('scenarios.json')


def scenarios():
    return json.loads(CATALOG.read_text(encoding='utf-8'))


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


@cache
def _windows_user_sid():
    system = Path(os.environ['SystemRoot']) / 'System32'
    result = subprocess.run(
        [system / 'whoami.exe', '/user', '/fo', 'csv', '/nh'],
        capture_output=True, check=True,
    )
    sid = result.stdout.strip().rsplit(b',', 1)[-1].strip(b'"').decode('ascii')
    if not re.fullmatch(r'S-\d+(?:-\d+)+', sid):
        raise ValueError('Could not determine the Windows user SID')
    return sid


def write_private(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    output = tempfile.NamedTemporaryFile(
        mode='w', encoding='utf-8', dir=path.parent, delete=False,
    )
    temporary = Path(output.name)
    try:
        with output:
            if os.name == 'nt':
                # Restrict the new file before any credentials are written.
                system = Path(os.environ['SystemRoot']) / 'System32'
                subprocess.run(
                    [system / 'icacls.exe', temporary, '/grant:r',
                     f'*{_windows_user_sid()}:(F)', '/inheritance:r'],
                    capture_output=True, check=True,
                )
            else:
                os.fchmod(output.fileno(), 0o600)
            json.dump(value, output, indent=2)
            output.write('\n')
        temporary.replace(path)
    except BaseException:
        temporary.unlink(missing_ok=True)
        raise
