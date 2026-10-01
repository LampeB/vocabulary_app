"""Select independent Patrol suites; user input is never evaluated as code."""
import json
import os
from pathlib import Path

SUITES = [
    'navigation', 'auth_flows', 'user_flows', 'daily_path',
    'lesson_prerequisites', 'language_pairs', 'quiz', 'quiz_ecrire', 'auth_login',
]


def targets(target):
    if target == 'all':
        return [f'patrol_test/{suite}_test.dart' for suite in SUITES]
    allowed = {entry['file'] for entry in json.loads(
        Path(__file__).with_name('scenarios.json').read_text()).values()}
    allowed.add('patrol_test/quiz_all_test.dart')
    if target not in allowed:
        raise ValueError('Unknown Patrol target')
    return [target]


if __name__ == '__main__':
    matrix = json.dumps({'target': targets(os.environ.get('E2E_TARGET') or 'all')})
    with open(os.environ['GITHUB_OUTPUT'], 'a') as output:
        output.write(f'matrix={matrix}\n')
