"""Exercise hosted source selection without invoking Supabase or Deno."""

import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch


SCRIPT = Path(__file__).with_name('deploy-edge-functions.py')
SPEC = importlib.util.spec_from_file_location('deploy_edge_functions', SCRIPT)
deploy = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(deploy)


class HostedDeployTest(unittest.TestCase):
    def setUp(self):
        directory = TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.root = Path(directory.name)
        env = {key: value for key, value in os.environ.items() if not key.startswith('GIT_')}
        self.enterContext(patch.dict(os.environ, env, clear=True))
        self.enterContext(patch.object(deploy, 'ROOT', self.root))
        self.enterContext(patch('sys.stdout', io.StringIO()))
        self.enterContext(patch('sys.stderr', io.StringIO()))

        self.function = deploy.FUNCTIONS / 'audio-provision' / 'index.ts'
        self.helper = deploy.FUNCTIONS / '_shared' / 'audio.ts'
        self.lock = deploy.FUNCTIONS / 'deno.lock'
        self.manifest = deploy.FUNCTIONS / 'deployable-functions.json'
        self.write(self.function, '// committed entrypoint')
        self.write(self.helper, '// committed helper')
        self.write(self.lock, 'committed lock')
        self.write(deploy.PROBE, '// committed probe')
        self.write(self.manifest, json.dumps(['audio-provision']))
        self.write(deploy.FUNCTIONS / 'tracked-experiment' / 'index.ts', '// excluded by manifest')
        self.git('init', '-q')
        self.git('add', '--all')
        self.git('-c', 'user.name=Tests', '-c', 'user.email=tests@example.invalid',
                 '-c', 'commit.gpgsign=false', '-c', 'core.hooksPath=.git/fixture-hooks',
                 'commit', '-qm', 'versioned deployment fixture')
        self.commit = self.git('rev-parse', 'HEAD').strip()
        self.git('update-ref', 'refs/remotes/origin/main', self.commit)

        self.check_inputs = []
        self.deployments = []
        check_output = subprocess.check_output

        def fake_deno_version(command, *args, **kwargs):
            if command == ['deno', '--version']:
                return f'deno {deploy.DENO_VERSION}\n'
            return check_output(command, *args, **kwargs)

        self.enterContext(patch.object(deploy.subprocess, 'check_output', side_effect=fake_deno_version))
        self.enterContext(patch.object(deploy, 'run', self.record))

    def git(self, *arguments):
        return subprocess.check_output(['git', *arguments], cwd=self.root, text=True)

    def write(self, path, content):
        path = self.root / path
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding='utf-8')

    def record(self, *command):
        if command[:2] == ('deno', 'check'):
            functions = command[3].parent
            source = functions.parent.parent
            self.check_inputs.append({
                'entries': [entry.parent.name for entry in command[5:]],
                'entry': (source / self.function).read_text(),
                'helper': (source / self.helper).read_text(),
                'lock': (source / self.lock).read_text(),
                'probe': (source / deploy.PROBE).read_text(),
            })
        elif command[:2] == ('deno', 'bundle'):
            shutil.copyfile(command[-1], command[-2])
        elif command[:3] == ('supabase', 'functions', 'deploy'):
            staged = command[-1] / deploy.FUNCTIONS
            self.deployments.append({
                path.parent.name: path.read_text() for path in staged.glob('*/index.ts')
            })

    def deploy(self, commit=None):
        deploy.main(['--project-ref', 'a' * 20, '--commit', commit or self.commit])

    def test_deploys_only_versioned_manifest_entries(self):
        self.write(deploy.FUNCTIONS / 'worktree-experiment' / 'index.ts', '// untracked')
        self.write(self.manifest, json.dumps(['audio-provision', 'worktree-experiment']))
        self.deploy()
        self.assertEqual(self.check_inputs[0]['entries'], ['audio-provision'])
        self.assertEqual(self.deployments, [{'audio-provision': '// committed entrypoint'}])

    def test_dirty_tracked_sources_lock_and_probe_cannot_change_deploy_snapshot(self):
        for path in [self.function, self.helper, self.lock, deploy.PROBE]:
            self.write(path, 'dirty worktree')
        self.deploy()
        self.assertEqual(self.check_inputs, [{
            'entries': ['audio-provision'],
            'entry': '// committed entrypoint',
            'helper': '// committed helper',
            'lock': 'committed lock',
            'probe': '// committed probe',
        }])
        self.assertEqual(self.deployments, [{'audio-provision': '// committed entrypoint'}])

    def test_deploy_requires_the_explicit_fetched_main_sha(self):
        for arguments in (['--project-ref', 'a' * 20],
                          ['--project-ref', 'a' * 20, '--commit', 'f' * 40]):
            with self.subTest(arguments=arguments), self.assertRaises(SystemExit):
                deploy.main(arguments)
        self.assertEqual(self.check_inputs, [])
        self.assertEqual(self.deployments, [])

    def test_local_ci_uses_the_same_allowlist_without_deploying(self):
        self.write(deploy.FUNCTIONS / 'worktree-experiment' / 'index.ts', '// untracked')
        deploy.main([])
        self.assertEqual(self.check_inputs[0]['entries'], ['audio-provision'])
        self.assertEqual(self.deployments, [])


if __name__ == '__main__':
    unittest.main()
