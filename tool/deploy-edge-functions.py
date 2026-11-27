"""Prepare locked Edge bundles and optionally deploy them to one explicit project."""
import argparse
from pathlib import Path
import re
import subprocess
from tempfile import TemporaryDirectory

ROOT = Path(__file__).resolve().parents[1]
FUNCTIONS = ROOT / 'supabase' / 'functions'
DENO_VERSION = '2.9.6'


def run(*command):
    subprocess.run(command, cwd=ROOT, check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project-ref', help='deploy to this project after all checks pass')
    args = parser.parse_args()
    if args.project_ref and not re.fullmatch('[a-z]{20}', args.project_ref):
        parser.error('expected a 20-letter Supabase project ref')
    version = subprocess.check_output(['deno', '--version'], text=True).splitlines()[0]
    if version.split()[:2] != ['deno', DENO_VERSION]:
        parser.error(f'Deno {DENO_VERSION} is required')
    if not (FUNCTIONS / 'deno.lock').is_file():
        parser.error('the tracked Deno lockfile is required')

    entries = sorted(FUNCTIONS.glob('*/index.ts'))
    locked = ('--config', FUNCTIONS / 'deno.json', '--frozen')
    run('deno', 'check', *locked, *entries)
    run('deno', 'test', *locked, '--allow-env', FUNCTIONS / '_shared')

    with TemporaryDirectory(prefix='ponderin-edge-') as directory:
        stage = Path(directory) / 'supabase'
        (stage / 'functions').mkdir(parents=True)
        (stage / 'config.toml').write_text('project_id = "ponderin-edge"\n', encoding='utf-8')
        bundles = []
        for entry in entries:
            bundle = stage / 'functions' / entry.parent.name / 'index.ts'
            bundle.parent.mkdir()
            run('deno', 'bundle', *locked, '--output', bundle, entry)
            bundles.append(bundle.as_uri())

        # Exercise exactly the staged files, with no npm/URL resolution or network.
        run('deno', 'run', '--no-config', '--no-remote', '--no-npm',
            f'--allow-read={stage}',
            '--allow-env=SUPABASE_URL,SUPABASE_ANON_KEY,SUPABASE_SERVICE_ROLE_KEY,ELEVENLABS_API_KEY',
            ROOT / 'tool' / 'check-edge-bundles.ts', *bundles)
        print(f'Validated {len(bundles)} frozen Edge bundles.', flush=True)
        if args.project_ref:
            run('supabase', 'functions', 'deploy', f'--remote={args.project_ref}',
                '--use-api', '--workdir', stage.parent)


if __name__ == '__main__':
    main()
