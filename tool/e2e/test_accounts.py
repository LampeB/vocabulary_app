import json
from pathlib import Path
import re
import tempfile
import unittest
from uuid import UUID

from accounts import scenarios, validate_accounts
from provision import provision


class AccountsTest(unittest.TestCase):
    def test_catalog_covers_every_declaration_once(self):
        found = {}
        for path in Path('patrol_test').glob('*_test.dart'):
            for scenario in re.findall(r"scenarioId:\s*'([^']+)'", path.read_text()):
                self.assertNotIn(scenario, found)
                found[scenario] = str(path)
        self.assertEqual(found, {key: row['file'] for key, row in scenarios().items()})
        self.assertGreater(len(found), 0)

    def test_duplicate_accounts_and_missing_scenario_are_rejected(self):
        first = dict(user_id=str(UUID(int=1)), email='a@example.invalid', password='x', username='a')
        for second in [dict(first, email='b@example.invalid'), dict(first, user_id=str(UUID(int=2)), email=' A@EXAMPLE.INVALID ')]:
            with self.assertRaises(ValueError):
                validate_accounts({'quiz.a': first, 'quiz.b': second}, ['quiz.a', 'quiz.b'])
        with self.assertRaises(ValueError):
            validate_accounts({'quiz.a': first}, ['quiz.b'])

    def test_provision_is_resumable_and_never_rotates_or_resets(self):
        users, calls = [], []
        fail_enroll = True

        def request(method, path, body=None):
            nonlocal fail_enroll
            calls.append((method, path))
            if method == 'GET':
                return {'users': users}
            if path == '/auth/v1/admin/users':
                user = dict(body, id=str(UUID(int=len(users) + 1)))
                users.append(user)
                return user
            if path == '/rest/v1/rpc/enroll_e2e_account':
                if fail_enroll:
                    fail_enroll = False
                    raise TimeoutError('interrupted enrollment')
                return None
            self.fail('Unexpected endpoint')

        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'accounts.json'
            with self.assertRaises(TimeoutError):
                provision(request, ['quiz.a', 'quiz.b'], path)
            password = json.loads(path.read_text())['quiz.a']['password']
            result = provision(request, ['quiz.a', 'quiz.b'], path)
            self.assertEqual(password, result['quiz.a']['password'])
            self.assertNotEqual(result['quiz.a']['user_id'], result['quiz.b']['user_id'])
            self.assertEqual(len(users), 2)
            self.assertEqual(result, provision(request, ['quiz.a', 'quiz.b'], path))
            self.assertEqual(len(users), 2)
            self.assertEqual(path.stat().st_mode & 0o777, 0o600)
            # Credentials are required to resume existing accounts; don't take over.
            path.unlink()
            with self.assertRaises(ValueError):
                provision(request, ['quiz.a'], path)
        self.assertFalse(any(method in ('PUT', 'DELETE') or 'reset' in path for method, path in calls))


if __name__ == '__main__':
    unittest.main()
