import os
import unittest
from urllib.error import HTTPError
from unittest.mock import MagicMock, patch

from check_activation import main, require_isolation_ready


class CheckActivationTest(unittest.TestCase):
    def test_read_only_check_uses_public_api_key(self):
        for key in ('sb_publishable_fixture', 'eyJ.fixture'):
            with self.subTest(key=key), patch('check_activation.build_opener') as build:
                response = build.return_value.open.return_value.__enter__.return_value
                response.status = 200
                response.read.return_value = b'"progress-boundaries-v1"'
                require_isolation_ready('https://project.invalid/', key)
                request = build.return_value.open.call_args.args[0]
                self.assertEqual(request.full_url, 'https://project.invalid/rest/v1/rpc/e2e_patrol_contract')
                self.assertEqual(request.get_method(), 'GET')
                self.assertEqual(request.get_header('Apikey'), key)
                self.assertEqual(request.get_header('Authorization'), f'Bearer {key}' if key.startswith('eyJ') else None)

    def test_uncertain_or_inactive_project_fails_closed(self):
        for status, body in [
            (200, b'true'), (200, b'false'), (200, b'null'), (200, b'"isolated-v1"'),
            (200, b'"owner-scoped-v1"'), (200, b'"write-order-v1"'), (200, b'"true"'), (200, b'{}'), (200, b'html'),
            (203, b'"progress-boundaries-v1"'),
        ]:
            with self.subTest(status=status, body=body), patch('check_activation.build_opener') as build:
                response = build.return_value.open.return_value.__enter__.return_value
                response.status = status
                response.read.return_value = body
                with self.assertRaises(ValueError):
                    require_isolation_ready('https://project.invalid', 'fixture')

    def test_missing_rpc_fails_the_workflow_step_without_printing_the_response(self):
        with (
            patch.dict(os.environ, {'SUPABASE_URL': 'https://project.invalid', 'SUPABASE_ANON_KEY': 'fixture'}, clear=True),
            patch('check_activation.build_opener') as build,
            patch('sys.stderr', new_callable=MagicMock) as stderr,
        ):
            build.return_value.open.side_effect = HTTPError('https://project.invalid', 404, 'body fixture', {}, None)
            self.assertEqual(main([]), 1)
            self.assertIn('could not be verified', str(stderr.write.call_args_list))
            self.assertNotIn('body fixture', str(stderr.write.call_args_list))
