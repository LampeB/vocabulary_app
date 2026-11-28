#!/usr/bin/env bash
set -euo pipefail
# Each matrix job owns exactly one suite. Retry failed jobs explicitly in GitHub.
target=${E2E_TARGET:?E2E_TARGET must select one suite}
case "$target" in
  patrol_test/*_test.dart)
    [[ "$target" != *..* && -f "$target" ]] || exit 2 ;;
  *) echo 'Invalid Patrol target' >&2; exit 2 ;;
esac
# Includes compilation and instrumented execution; each Dart scenario has 3 min.
# Kill a stuck child after a grace period so the runner cannot hang indefinitely.
exec timeout --kill-after=30s 35m patrol test --target "$target" --dart-define-from-file=.env.json
