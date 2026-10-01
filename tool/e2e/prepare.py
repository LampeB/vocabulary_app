"""Validate credentials/reset access before building; never print response bodies."""
import json
import os
import re
import sys
from urllib.request import Request, urlopen
from urllib.error import HTTPError


class PreparationError(Exception):
    """Safe diagnostics only; never include a response body or credentials."""


def http_failure(stage, error):
    body = error.read(8192)
    try:
        payload = json.loads(body)
    except (ValueError, UnicodeDecodeError):
        payload = {}
    if not isinstance(payload, dict):
        payload = {}
    code = str(payload.get('code') or payload.get('error_code') or '')
    if not re.fullmatch(r'[A-Za-z0-9_]{1,64}', code):
        code = 'unknown'
    hint = {
        'invalid_credentials': 'Check TEST_EMAIL and TEST_PASSWORD.',
        'email_not_confirmed': 'Confirm the dedicated account email.',
        '42501': 'Check E2E account enrollment and RPC permissions.',
        'PGRST202': 'Install migration 008 in the project targeted by GitHub secrets.',
        '42P01': 'A table required by reset is missing from the hosted schema.',
        '42703': 'A column required by reset is missing from the hosted schema.',
        '23503': 'A foreign-key dependency prevents reset.',
    }.get(code, 'Check the Supabase configuration for this stage.')
    # Schema identifiers are useful and contain no user data. Do not print
    # arbitrary server messages, detail or hint fields.
    message = str(payload.get('message', ''))
    schema = re.search(r'(?:column|relation) [\"a-zA-Z0-9_.]+ does not exist', message)
    if code in ('42P01', '42703') and schema:
        hint += ' ' + schema.group(0)
    if b'1010' in body and not payload:
        hint = 'Gateway rejected the HTTP client (1010).'
    return PreparationError(f'{stage}: HTTP {error.code}, code={code}. {hint}')


def prepare():
    config = {name: os.environ[name] for name in (
        'SUPABASE_URL', 'SUPABASE_ANON_KEY', 'TEST_EMAIL', 'TEST_PASSWORD')}
    if not all(config.values()) or not config['SUPABASE_URL'].startswith('https://'):
        raise ValueError('Missing E2E configuration or invalid Supabase URL')

    def post(path, data, token=None):
        stage = "sign-in" if path.startswith("/auth/") else "account reset"
        headers = {'apikey': config['SUPABASE_ANON_KEY'], 'Content-Type': 'application/json'}
        if token:
            headers['Authorization'] = f'Bearer {token}'
        request = Request(config['SUPABASE_URL'].rstrip('/') + path,
                          data=json.dumps(data).encode(), headers=headers, method='POST')
        try:
            with urlopen(request, timeout=30) as response:
                return json.load(response)
        except HTTPError as error:
            raise http_failure(stage, error) from None

    session = post('/auth/v1/token?grant_type=password', {
        'email': config['TEST_EMAIL'], 'password': config['TEST_PASSWORD']})
    if session['user']['email'].lower() != config['TEST_EMAIL'].lower():
        raise ValueError('Unexpected test account identity')
    baseline = post('/rest/v1/rpc/reset_e2e_account', {}, session['access_token'])
    if (baseline.get('user_id') != session['user']['id'] or
            baseline.get('baseline') != 'empty-free-v1'):
        raise ValueError('Reset baseline was not confirmed')
    config.update(TEST_USERNAME=baseline['username'], TEST_MODE='true',
                  TEST_LOCALE='fr', TEST_CARD_LIMIT='3', SIMULATE_SPEECH='correct',
                  REVENUECAT_API_KEY='YOUR_REVENUECAT_KEY')
    # No shared TEST_SESSION: each isolated scenario authenticates afresh.
    descriptor = os.open('.env.json', os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    os.fchmod(descriptor, 0o600)
    with os.fdopen(descriptor, 'w') as output:
        json.dump(config, output, indent=2)
    print('E2E reset authorized; configuration ready.')


if __name__ == '__main__':
    try:
        prepare()
    except PreparationError as error:
        print(f"E2E preparation failed: {error}", file=sys.stderr)
        sys.exit(1)
    except Exception as error:
        print(f'E2E preparation failed ({type(error).__name__}). Check project availability, '
              'credentials, migration 008 and account enrollment.', file=sys.stderr)
        sys.exit(1)
