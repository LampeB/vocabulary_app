"""One-time/resumable provisioning. Admin key is never written or published."""
import argparse
import getpass
import hashlib
import json
import os
from pathlib import Path
import secrets
import subprocess
import sys
from urllib.error import HTTPError
from urllib.request import Request, urlopen

from accounts import scenarios, validate_accounts, write_private
from prepare import http_failure, PreparationError


def provision(request, catalog, path):
    path = Path(path)
    accounts = json.loads(path.read_text()) if path.exists() else {}
    remote = {}
    page = 1
    while True:
        users = request('GET', f'/auth/v1/admin/users?page={page}&per_page=1000')['users']
        remote.update({u.get('email', '').lower(): u for u in users})
        if len(users) < 1000:
            break
        page += 1
    for scenario in catalog:
        suffix = hashlib.sha256(scenario.encode()).hexdigest()[:20]
        email = f'vocabkr-e2e-{suffix}@example.invalid'
        username = f'e2e_{suffix}'
        user = remote.get(email)
        if scenario not in accounts:
            if user:
                raise ValueError(f'Credentials missing locally for existing scenario {scenario}; restore the account map backup')
            accounts[scenario] = dict(email=email, username=username,
                                      password=secrets.token_urlsafe(32), user_id='')
            # Persist the password before creating the remote user, so an
            # interrupted HTTP request can be safely recovered on the next run.
            write_private(path, accounts)
        account = accounts[scenario]
        if account['email'] != email or account['username'] != username:
            raise ValueError(f'Unexpected local identity for {scenario}')
        if user is None:
            if account['user_id']:
                raise ValueError(f'Permanent account disappeared for {scenario}; refusing replacement')
            user = request('POST', '/auth/v1/admin/users', {
                'email': email, 'password': account['password'], 'email_confirm': True,
                'user_metadata': {'username': username},
                'app_metadata': {'e2e_managed_by': 'vocabkr', 'e2e_scenario_id': scenario}})
        metadata = user.get('app_metadata', {})
        if (metadata.get('e2e_managed_by') != 'vocabkr' or
                metadata.get('e2e_scenario_id') != scenario or
                user.get('email', '').lower() != email or
                (account['user_id'] and account['user_id'] != user['id'])):
            raise ValueError(f'Refusing to adopt or reassign an unrelated account for {scenario}')
        account['user_id'] = user['id']
        write_private(path, accounts)
        request('POST', '/rest/v1/rpc/enroll_e2e_account', {
            'p_user_id': user['id'], 'p_scenario_id': scenario, 'p_username': username})
        print(f'Account ready: {scenario}')
    return validate_accounts(accounts, catalog)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--config', default='.env.json')
    parser.add_argument('--publish-github', action='store_true',
                        help='Write E2E_ACCOUNTS_JSON to LampeB/vocabulary_app after successful provisioning')
    args = parser.parse_args()
    config = json.loads(Path(args.config).read_text())
    url = config['SUPABASE_URL'].rstrip('/')
    if not url.startswith('https://'):
        raise ValueError('Expected HTTPS Supabase URL')
    identity_file = Path('.e2e/project.json')
    if identity_file.exists() and json.loads(identity_file.read_text())['url'] != url:
        raise ValueError('Local accounts belong to another Supabase project')
    write_private(identity_file, {'url': url})
    key = os.environ.get('SUPABASE_SERVICE_ROLE_KEY') or getpass.getpass('Supabase service_role/secret key (not stored): ')
    if not key:
        raise ValueError('Missing admin credential')

    def request(method, path, body=None):
        headers = {'apikey': key, 'Content-Type': 'application/json', 'User-Agent': 'VocabKR-E2E-Provision/1.0'}
        if key.startswith('eyJ'):
            headers['Authorization'] = 'Bearer ' + key
        req = Request(url + path, method=method, headers=headers,
                      data=None if body is None else json.dumps(body).encode())
        try:
            with urlopen(req, timeout=30) as response:
                content = response.read()
                return json.loads(content) if content else None
        except HTTPError as error:
            raise http_failure('provisioning', error) from None

    accounts = provision(request, scenarios(), '.e2e/accounts.json')
    local = {k: config[k] for k in ('SUPABASE_URL', 'SUPABASE_ANON_KEY')}
    local.update(TEST_ACCOUNTS_JSON=json.dumps(accounts), TEST_MODE='true',
                 TEST_LOCALE='fr', TEST_CARD_LIMIT='3', SIMULATE_SPEECH='correct')
    write_private('test.accounts.env.json', local)
    if args.publish_github:
        subprocess.run(['gh', 'secret', 'set', 'E2E_ACCOUNTS_JSON', '--repo', 'LampeB/vocabulary_app'],
                       input=json.dumps(accounts), text=True, check=True)
        print('GitHub scenario credentials updated; admin credential not published.')
    print('Keep a private backup of .e2e/accounts.json; use test.accounts.env.json for local Patrol.')


if __name__ == '__main__':
    try:
        main()
    except PreparationError as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
    except Exception as error:
        # No raw exception: requests/subprocess exceptions may contain credentials.
        print(f'Provisioning stopped ({type(error).__name__}); saved progress is resumable. '
              'Check configuration, migrations and the private account map.', file=sys.stderr)
        sys.exit(1)
