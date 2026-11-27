import json
import os
from pathlib import Path
import re
import unittest
from unittest.mock import patch
from uuid import UUID

from accounts import scenarios
from matrix import QUIZ_UMBRELLA, scenario_ids_for_target, targets
from prepare import prepare


class PrepareTest(unittest.TestCase):
    def test_each_build_contains_only_the_target_account_fields(self):
        catalog = scenarios()
        credentials = {
            scenario: dict(user_id=str(UUID(int=i)), email=f'test-{i}@example.invalid',
                           password=f'fixture-{i}', username=f'fixture_{i}', extra='not for APK')
            for i, scenario in enumerate(catalog, 1)
        }
        umbrella = Path(QUIZ_UMBRELLA).read_text(encoding='utf-8')
        included = {f'patrol_test/{name}' for name in re.findall(r"^import '([^']+)'", umbrella, re.M)}
        for target in targets('all') + [QUIZ_UMBRELLA]:
            with self.subTest(target=target):
                files = included if target == QUIZ_UMBRELLA else {target}
                expected = {scenario for scenario, entry in catalog.items() if entry['file'] in files}
                with patch.dict(os.environ, {
                    'SUPABASE_URL': 'https://test.invalid',
                    'SUPABASE_ANON_KEY': 'fixture-anon',
                    'E2E_ACCOUNTS_JSON': json.dumps(credentials),
                    'E2E_TARGET': target,
                }), patch('accounts.write_private') as write:
                    prepare()
                destination, config = write.call_args.args
                self.assertEqual(destination, '.env.json')
                selected = json.loads(config['TEST_ACCOUNTS_JSON'])
                self.assertEqual(set(selected), expected)
                self.assertGreater(len(selected), 0)
                self.assertLess(len(selected), len(credentials))
                self.assertTrue(all('extra' not in account for account in selected.values()))

    def test_preparation_rejects_invalid_and_aggregate_targets(self):
        for target in ('all', '', 'patrol_test/missing_test.dart'):
            with self.subTest(target=target), self.assertRaises(ValueError):
                scenario_ids_for_target(target)
