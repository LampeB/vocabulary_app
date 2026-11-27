"""Restrict Supabase requests to the configured HTTPS project origin."""
from urllib.parse import urlsplit
from urllib.request import HTTPRedirectHandler


def supabase_origin(value):
    if not isinstance(value, str) or any(char.isspace() or char == '\\' for char in value):
        raise ValueError('Invalid Supabase HTTPS project origin')
    project = urlsplit(value)
    if (project.scheme != 'https' or not project.hostname or project.username is not None
            or project.path not in ('', '/') or project.query or project.fragment
            or project.port == 0):
        raise ValueError('Invalid Supabase HTTPS project origin')
    return f'https://{project.netloc}'


class NoRedirects(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None
