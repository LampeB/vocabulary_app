"""Validate the scenario credential map before building; never print response bodies."""
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
        'invalid_credentials': 'Check the scenario credentials.',
        'email_not_confirmed': 'Confirm the dedicated account email.',
        '42501': 'Check E2E account enrollment and RPC permissions.',
        'PGRST202': 'Install migrations 008 and 009 in the project targeted by GitHub secrets.',
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
    from accounts import scenarios, validate_accounts, write_private
    config = {name: os.environ[name] for name in ('SUPABASE_URL', 'SUPABASE_ANON_KEY')}
    if not all(config.values()) or not config['SUPABASE_URL'].startswith('https://'):
        raise ValueError('Missing Supabase configuration')
    accounts = validate_accounts(json.loads(os.environ['E2E_ACCOUNTS_JSON']), scenarios())
    # No account is modified here. Only the scenario about to run resets itself.
    config.update(TEST_ACCOUNTS_JSON=json.dumps(accounts), TEST_MODE='true',
                  TEST_LOCALE='fr', TEST_CARD_LIMIT='3', SIMULATE_SPEECH='correct',
                  REVENUECAT_API_KEY='YOUR_REVENUECAT_KEY')
    write_private('.env.json', config)
    print(f'Validated {len(accounts)} distinct scenario accounts; no server data changed.')


if __name__ == '__main__':
    try:
        prepare()
    except PreparationError as error:
        print(f"E2E preparation failed: {error}", file=sys.stderr)
        sys.exit(1)
    except Exception as error:
        print(f'E2E preparation failed ({type(error).__name__}). Check project availability, '
              'E2E_ACCOUNTS_JSON and scenario enrollment.', file=sys.stderr)
        sys.exit(1)
