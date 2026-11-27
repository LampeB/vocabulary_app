from email.message import Message
from io import BytesIO
import unittest
from unittest.mock import patch
from urllib.request import HTTPSHandler, build_opener
from urllib.response import addinfourl

from prepare import PreparationError
from provision import admin_requests


class RedirectFixture(HTTPSHandler):
    def __init__(self, status):
        super().__init__()
        self.status = status
        self.requests = []

    def https_open(self, request):
        self.requests.append(request)
        headers = Message()
        if len(self.requests) == 1:
            headers['Location'] = 'https://unrelated.invalid/redirect-target'
            response = addinfourl(BytesIO(b''), headers, request.full_url, self.status)
            response.msg = 'Redirect'
        else:
            response = addinfourl(BytesIO(b'{}'), headers, request.full_url, 200)
            response.msg = 'OK'
        return response


class AdminTransportTest(unittest.TestCase):
    def test_rejects_http_and_invalid_project_origins_before_opening_transport(self):
        for url in ('http://project.invalid', 'https://user@project.invalid',
                    'https://project.invalid/functions', 'https://project.invalid/?query=yes'):
            with self.subTest(url=url), patch('provision.build_opener') as build:
                with self.assertRaises(ValueError):
                    admin_requests(url, 'fixture-admin')
                build.assert_not_called()

    def test_admin_credentials_never_reach_a_redirect_target(self):
        key = 'eyJ.fixture-admin'
        for method, status in [('GET', 301), ('GET', 302), ('POST', 303), ('POST', 307), ('POST', 308)]:
            with self.subTest(method=method, status=status):
                fixture = RedirectFixture(status)
                with patch('provision.build_opener', side_effect=lambda policy: build_opener(policy, fixture)):
                    request = admin_requests('https://project.invalid/', key)
                    with self.assertRaisesRegex(PreparationError, 'redirected the admin request'):
                        request(method, '/auth/v1/admin/users')
                self.assertEqual(len(fixture.requests), 1)
                sent = fixture.requests[0]
                self.assertEqual(sent.full_url, 'https://project.invalid/auth/v1/admin/users')
                self.assertEqual(sent.get_header('Apikey'), key)
                self.assertEqual(sent.get_header('Authorization'), f'Bearer {key}')
