"""Select independent Patrol suites; user input is never evaluated as code."""
import json
import os

from accounts import scenarios

SUITES = [
    'navigation', 'auth_flows', 'user_flows', 'daily_path',
    'lesson_prerequisites', 'language_pairs', 'quiz', 'quiz_ecrire', 'auth_login',
]

# The local umbrella imports these suites and is also accepted as one manual target.
QUIZ_UMBRELLA = 'patrol_test/quiz_all_test.dart'
QUIZ_UMBRELLA_SUITES = ('auth_flows', 'navigation', 'quiz_ecrire', 'quiz', 'user_flows')


def suite_path(suite):
    return f'patrol_test/{suite}_test.dart'


def targets(target):
    if target == 'all':
        return [suite_path(suite) for suite in SUITES]
    allowed = {entry['file'] for entry in scenarios().values()}
    allowed.add(QUIZ_UMBRELLA)
    if target not in allowed:
        raise ValueError('Unknown Patrol target')
    return [target]


def scenario_ids_for_target(target):
    if target == 'all':
        raise ValueError('Each build must select one Patrol target')
    files = {target}
    if target == QUIZ_UMBRELLA:
        files = {suite_path(suite) for suite in QUIZ_UMBRELLA_SUITES}
    selected = {scenario for scenario, entry in scenarios().items() if entry['file'] in files}
    if not selected:
        raise ValueError('Unknown Patrol target')
    return selected


if __name__ == '__main__':
    matrix = json.dumps({'target': targets(os.environ.get('E2E_TARGET') or 'all')})
    with open(os.environ['GITHUB_OUTPUT'], 'a') as output:
        output.write(f'matrix={matrix}\n')
