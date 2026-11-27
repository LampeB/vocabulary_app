"""Prepare locked Edge bundles and optionally deploy them to one explicit project."""
import argparse
from io import BytesIO
import json
from pathlib import Path
import re
import subprocess
from tempfile import TemporaryDirectory
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parents[1]
FUNCTIONS = Path('supabase/functions')
PROBE = Path('tool/check-edge-bundles.ts')
DENO_VERSION = '2.9.6'


def run(*command):
    subprocess.run(command, cwd=ROOT, check=True)


def git(*command):
    return subprocess.check_output(['git', *command], cwd=ROOT)


def snapshot_main(commit, destination):
    main = git('rev-parse', '--verify', 'refs/remotes/origin/main').decode().strip()
    if commit != main:
        raise ValueError('deployment commit must equal the fetched origin/main SHA')
    archive = git('archive', '--format=zip', commit, '--', FUNCTIONS.as_posix(), PROBE.as_posix())
    with ZipFile(BytesIO(archive)) as snapshot:
        snapshot.extractall(destination)


def prepare_bundles(source, stage):
    functions = source / FUNCTIONS
    manifest = json.loads((functions / 'deployable-functions.json').read_text(encoding='utf-8'))
    if (not isinstance(manifest, list) or not manifest
            or any(not isinstance(name, str) or not re.fullmatch('[a-z][a-z0-9-]*', name) for name in manifest)
            or len(set(manifest)) != len(manifest)):
        raise ValueError('invalid deployable Edge function manifest')
    entries = [functions / name / 'index.ts' for name in manifest]
    if any(not entry.is_file() for entry in entries):
        raise ValueError('every deployable function needs a source entrypoint')
    if not (functions / 'deno.lock').is_file():
        raise ValueError('the tracked Deno lockfile is required')

    locked = ('--config', functions / 'deno.json', '--frozen')
    run('deno', 'check', *locked, *entries)
    run('deno', 'test', *locked, '--allow-env', functions / '_shared')

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
        source / PROBE, *bundles)
    print(f'Validated {len(bundles)} frozen Edge bundles.', flush=True)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project-ref', help='deploy to this project after all checks pass')
    parser.add_argument('--commit', help='full, validated SHA of origin/main to deploy')
    args = parser.parse_args(argv)
    if args.project_ref is not None and not re.fullmatch('[a-z]{20}', args.project_ref):
        parser.error('expected a 20-letter Supabase project ref')
    if (args.project_ref is None) != (args.commit is None):
        parser.error('--project-ref and --commit must be used together')
    if args.commit is not None and not re.fullmatch('[0-9a-f]{40}', args.commit):
        parser.error('expected a full, lowercase 40-character commit SHA')
    version = subprocess.check_output(['deno', '--version'], text=True).splitlines()[0]
    if version.split()[:2] != ['deno', DENO_VERSION]:
        parser.error(f'Deno {DENO_VERSION} is required')

    with TemporaryDirectory(prefix='ponderin-edge-') as directory:
        temp = Path(directory)
        source = ROOT
        stage = temp / 'stage' / 'supabase'
        try:
            if args.commit is not None:
                source = temp / 'source'
                snapshot_main(args.commit, source)
                print(f'Preparing Edge deployment from origin/main at {args.commit}.', flush=True)
            prepare_bundles(source, stage)
        except (OSError, ValueError) as error:
            parser.error(str(error))
        if args.project_ref is not None:
            run('supabase', 'functions', 'deploy', f'--remote={args.project_ref}',
                '--use-api', '--workdir', stage.parent)


if __name__ == '__main__':
    main()
