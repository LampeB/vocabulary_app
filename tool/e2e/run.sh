#!/usr/bin/env bash
set -euo pipefail
targets=(
  patrol_test/navigation_test.dart
  patrol_test/auth_flows_test.dart
  patrol_test/user_flows_test.dart
  patrol_test/daily_path_test.dart
  patrol_test/lesson_prerequisites_test.dart
  patrol_test/language_pairs_test.dart
  patrol_test/quiz_test.dart
  patrol_test/quiz_ecrire_test.dart
  patrol_test/auth_login_test.dart
)
target=${E2E_TARGET:-all}
if [[ "$target" != all ]]; then
  case "$target" in
    patrol_test/*_test.dart)
      [[ "$target" != *..* && -f "$target" ]] || exit 2 ;;
    *) echo 'Invalid Patrol target' >&2; exit 2 ;;
  esac
  targets=("$target")
fi
failed=()
for target in "${targets[@]}"; do
  ok=0
  for attempt in 1 2 3; do
    echo "=== $target attempt $attempt/3 ==="
    if timeout 15m patrol test --target "$target" --dart-define-from-file=.env.json; then
      ok=1
      break
    fi
  done
  [[ "$ok" == 1 ]] || { echo "::error::$target failed 3 attempts"; failed+=("$target"); }
done

[[ ${#failed[@]} == 0 ]]
