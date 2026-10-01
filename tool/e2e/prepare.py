"""Validate credentials/reset access before building; never print response bodies."""
import json
import os
import sys
from urllib.request import Request, urlopen


def prepare():
    config = {name: os.environ[name] for name in (
        'SUPABASE_URL', 'SUPABASE_ANON_KEY', 'TEST_EMAIL', 'TEST_PASSWORD')}
    if not all(config.values()) or not config['SUPABASE_URL'].startswith('https://'):
        raise ValueError('Missing E2E configuration or invalid Supabase URL')

    def post(path, data, token=None):
        headers = {'apikey': config['SUPABASE_ANON_KEY'], 'Content-Type': 'application/json'}
        if token:
            headers['Authorization'] = f'Bearer {token}'
        request = Request(config['SUPABASE_URL'].rstrip('/') + path,
                          data=json.dumps(data).encode(), headers=headers, method='POST')
        with urlopen(request, timeout=30) as response:
            return json.load(response)

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
    except Exception as error:
        print(f'E2E preparation failed ({type(error).__name__}). Check project availability, '
              'credentials, migration 008 and account enrollment.', file=sys.stderr)
        sys.exit(1)
