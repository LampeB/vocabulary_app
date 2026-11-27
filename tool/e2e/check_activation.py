"""Check the hosted reset prerequisites with a read-only Supabase RPC."""
import argparse
from http.client import HTTPException
import json
import os
from pathlib import Path
import sys
from urllib.request import Request, build_opener

from supabase_http import NoRedirects, supabase_origin


PATROL_CONTRACT = 'progress-boundaries-v1'


def require_isolation_ready(url, key):
    if not isinstance(key, str) or not key:
        raise ValueError('Invalid Supabase project configuration')
    headers = {'apikey': key, 'Accept': 'application/json'}
    if key.startswith('eyJ'):
        headers['Authorization'] = f'Bearer {key}'
    req = Request(f"{supabase_origin(url)}/rest/v1/rpc/e2e_patrol_contract", headers=headers)
    with build_opener(NoRedirects()).open(req, timeout=10) as response:
        body = response.read(257)
        if response.status != 200 or len(body) > 256 or json.loads(body) != PATROL_CONTRACT:
            raise ValueError('Hosted Patrol schema is unavailable')


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--config', type=Path, help='Use the Supabase settings in this JSON file')
    args = parser.parse_args(argv)
    try:
        config = os.environ if args.config is None else json.loads(args.config.read_text(encoding='utf-8'))
        require_isolation_ready(config['SUPABASE_URL'], config['SUPABASE_ANON_KEY'])
    except (HTTPException, KeyError, OSError, TypeError, ValueError):
        print('Hosted Patrol schema could not be verified. Follow the activation runbook.', file=sys.stderr)
        return 1
    print('Hosted Patrol schema verified.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
