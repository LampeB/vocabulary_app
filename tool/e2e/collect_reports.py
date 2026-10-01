"""Retain text Android reports only, with configured credentials removed."""
import html
import json
from pathlib import Path
import re
from urllib.parse import quote


def secrets(value):
    if isinstance(value, dict):
        for key, item in value.items():
            if key == 'TEST_ACCOUNTS_JSON':
                yield from secrets(json.loads(item))
            elif isinstance(item, str) and (key in ('email', 'password', 'user_id', 'username') or 'KEY' in key or 'SESSION' in key):
                yield item
            elif isinstance(item, (dict, list)):
                yield from secrets(item)
    elif isinstance(value, list):
        for item in value:
            yield from secrets(item)


def scrub(text, sensitive):
    for value in sorted(sensitive, key=len, reverse=True):
        if value:
            for form in (value, html.escape(value), quote(value, safe='')):
                text = text.replace(form, '[REDACTED]')
    return re.sub(r'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+', '[REDACTED_JWT]', text)


if __name__ == '__main__':
    sensitive = list(secrets(json.loads(Path('.env.json').read_text())))
    destination = Path('e2e-reports')
    destination.mkdir(exist_ok=True)
    count = 0
    for base in ('build/app/reports/androidTests', 'build/app/outputs/androidTest-results'):
        for path in Path(base).rglob('*'):
            if path.is_file() and path.suffix in ('.xml', '.html', '.txt', '.log', '.css', '.js'):
                target = destination / path
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_text(scrub(path.read_text(errors='replace'), sensitive))
                count += 1
    (destination / 'README.txt').write_text(f'{count} text report files collected. No APK or environment file included.\n')
    print(f'Collected {count} sanitized report files.')
