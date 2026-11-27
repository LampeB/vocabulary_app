"""Exercise both PR policy entry points and the installed Git hook in a fixture repo."""

import os
from pathlib import Path
import shutil
import subprocess
from tempfile import TemporaryDirectory
import unittest


ROOT = Path(__file__).resolve().parents[1]
HOOK = '.githooks/pre-commit'
POLICY = 'tool/check-pr-policy.ps1'
INSTALLER = 'tool/install-git-hooks.ps1'
FORBIDDEN = 'Generated artifacts or private configuration cannot be committed'


class PolicyTest(unittest.TestCase):
    def setUp(self):
        directory = TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.root = Path(directory.name)
        self.env = {
            name: value for name, value in os.environ.items()
            if not name.startswith('GIT_') and name != 'DOCS_EXEMPT'
        }
        self.git('init', '-q')
        self.git('config', 'user.name', 'Policy fixture')
        self.git('config', 'user.email', 'policy-fixture@example.invalid')
        self.git('config', 'commit.gpgsign', 'false')
        # These synthetic index paths are never checked out. Allow a path
        # with LF in the disposable repository even when Git runs on Windows.
        self.git('config', 'core.protectNTFS', 'false')
        for path in (
            HOOK, POLICY, INSTALLER, '.gitattributes',
            'tool/check-documentation.ps1', 'tool/git-changed-paths.ps1',
        ):
            copy = self.root / path
            copy.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / path, copy)
        self.git('add', '-A')
        self.git('-c', 'core.hooksPath=.git/fixture-no-hooks', 'commit', '-qm', 'Policy fixture base')

    def invoke(self, *command, check=True, input=None, root=None):
        return subprocess.run(command, cwd=root or self.root, env=self.env, input=input,
                              stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=check)

    def git(self, *arguments, input=None):
        return self.invoke('git', *arguments, input=input).stdout.decode('utf-8').strip()

    def pwsh(self, script, *args, check=True):
        return self.invoke('pwsh', '-NoProfile', '-File', script, *args, check=check)

    def stage_fixture(self, path):
        # Stage bytes directly into this disposable index. This also tests LF
        # paths on hosts that cannot create such a pathname in the worktree.
        blob = self.git('hash-object', '-w', '--stdin', input=b'synthetic path test fixture\n')
        self.git('update-index', '-z', '--index-info', input=f'100644 {blob}\t{path}\0'.encode())
        tracked = self.invoke('git', 'ls-files', '-z').stdout.split(b'\0')
        self.assertIn(path.encode(), tracked)

    def assert_blocked(self, result, expected_path):
        output = result.stdout.decode('utf-8', errors='replace')
        self.assertNotEqual(result.returncode, 0, output)
        self.assertIn(FORBIDDEN, output)
        self.assertIn(expected_path, output)

    def make_fixture_revision(self):
        base = self.git('rev-parse', 'HEAD')
        revision = self.git('commit-tree', self.git('write-tree'), '-p', base,
                            '-m', 'Synthetic path in PR diff fixture')
        self.git('update-ref', 'HEAD', revision)
        return base

    def test_index_and_base_diff_keep_non_ascii_and_line_breaks(self):
        for path in ('tool/stt_corpus/voix-é.wav', 'tool/stt_corpus/one\ntwo.wav'):
            with self.subTest(path=path):
                self.stage_fixture(path)
                display = path.replace('\n', r'\n')
                self.assert_blocked(self.pwsh(POLICY, '-Staged', check=False), display)
                base = self.make_fixture_revision()
                self.assert_blocked(self.pwsh(POLICY, '-BaseRef', base, check=False), display)

    def test_ignored_deployment_env_is_rejected_but_example_is_allowed(self):
        path = 'supabase/.env.deploy'
        exclude = self.root / '.git/info/exclude'
        exclude.parent.mkdir(exist_ok=True)
        exclude.write_text(f'/{path}\n', encoding='utf-8')
        (self.root / 'supabase').mkdir()
        (self.root / path).write_text('synthetic deployment config\n', encoding='utf-8')
        self.git('add', '-f', '--', path)
        self.assert_blocked(self.pwsh(POLICY, '-Staged', check=False), path)
        base = self.make_fixture_revision()
        self.assert_blocked(self.pwsh(POLICY, '-BaseRef', base, check=False), path)

        self.stage_fixture(f'{path}.example')
        self.stage_fixture('README.md')
        self.pwsh(POLICY, '-Staged')
        self.pwsh(POLICY, '-BaseRef', self.make_fixture_revision())

    def test_pr_rejects_a_forbidden_path_removed_before_head(self):
        path = 'tool/stt_corpus/capture-fixture.wav'
        self.stage_fixture(path)
        base = self.make_fixture_revision()
        self.git('update-index', '--force-remove', '--', path)
        self.make_fixture_revision()
        self.assertEqual(self.git('diff', '--name-only', base, 'HEAD'), '')
        self.assert_blocked(self.pwsh(POLICY, '-BaseRef', base, check=False), path)
        self.pwsh(POLICY, '-BaseRef', 'HEAD')

    def test_pr_rejects_a_forbidden_path_introduced_by_a_merge(self):
        base = self.git('rev-parse', 'HEAD')
        tree = self.git('write-tree')
        left = self.git('commit-tree', tree, '-p', base, '-m', 'Left fixture parent')
        right = self.git('commit-tree', tree, '-p', base, '-m', 'Right fixture parent')
        path = 'tool/stt_corpus/merge-fixture.wav'
        self.stage_fixture(path)
        merge = self.git('commit-tree', self.git('write-tree'), '-p', left, '-p', right,
                         '-m', 'Introduce synthetic path in merge')
        self.git('update-ref', 'HEAD', merge)
        self.git('update-index', '--force-remove', '--', path)
        self.make_fixture_revision()
        self.assertEqual(self.git('diff', '--name-only', base, 'HEAD'), '')
        self.assert_blocked(self.pwsh(POLICY, '-BaseRef', base, check=False), path)

    def test_pr_does_not_recheck_unchanged_paths_from_the_base_branch(self):
        self.stage_fixture('tool/stt_corpus/base-history-fixture.wav')
        self.make_fixture_revision()
        self.stage_fixture('README.md')
        base = self.make_fixture_revision()
        self.pwsh(POLICY, '-BaseRef', base)

    def test_installed_hook_rejects_a_real_commit(self):
        mode = self.invoke('git', 'ls-files', '--stage', HOOK, root=ROOT).stdout.split()[0]
        self.assertEqual(mode, b'100755')
        source = ROOT / HOOK
        self.assertNotIn(b'\r\n', source.read_bytes())
        if os.name != 'nt':
            self.assertTrue(os.access(source, os.X_OK), 'Checkout did not make hook executable')

        self.pwsh(INSTALLER)
        self.assertEqual(self.git('config', '--get', 'core.hooksPath'), '.githooks')
        base = self.git('rev-parse', 'HEAD')
        self.stage_fixture('tool/stt_corpus/commit-fixture.wav')
        result = self.invoke('git', 'commit', '-m', 'Must be rejected', check=False)
        self.assert_blocked(result, 'tool/stt_corpus/commit-fixture.wav')
        self.assertEqual(self.git('rev-parse', 'HEAD'), base)

    def test_documentation_guard_accepts_an_accented_markdown_path(self):
        docs = self.root / 'docs'
        docs.mkdir()
        (docs / 'modèle.md').write_text('# Contract fixture\n', encoding='utf-8')
        self.git('add', 'docs')
        self.stage_fixture('lib/contract_fixture.txt')
        self.pwsh(POLICY, '-Staged')
