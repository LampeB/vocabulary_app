#!/usr/bin/env bash
# Acoustic scenario runner. With the app in a hands-free session on the
# emulator (see README), this watches the STT debug log via logcat and, on
# every listening window, injects the audio for the next scenario in the
# list, then judges the outcome from the app's own pipeline log.
#
# Usage: ./run_scenarios.sh correct noise foreign correct_noisy wrong ...
#
# Scenario → audio → expected pipeline outcome:
#   correct        the card's answer clip, clean      → graded CORRECT
#   correct_noisy  the answer buried in babble        → graded CORRECT
#   noise          babble only                        → NO verdict (re-listen / not-heard)
#   foreign        French speech                      → NO verdict (re-listen / not-heard)
#   wrong          a different word's clip, clean     → graded INCORRECT (control)
set -uo pipefail
cd "$(dirname "$0")"

LOG=$(mktemp /tmp/stt_lab_XXXX.log)
adb -e logcat -c
adb -e logcat -v time -s flutter:I > "$LOG" 2>&1 &
LOGCAT_PID=$!
trap 'kill $LOGCAT_PID 2>/dev/null' EXIT

wav_for() { # scenario expected_answer
  local answer_key
  case "$2" in
    물) answer_key=ko_mul;; 커피) answer_key=ko_keopi;; 밥) answer_key=ko_bap;;
    학생) answer_key=ko_haksaeng;; 친구) answer_key=ko_chingu;; *) answer_key=ko_mul;;
  esac
  case "$1" in
    correct)       echo "corpus/$answer_key.wav";;
    correct_noisy) echo "corpus/${answer_key}_noisy.wav";;
    noise)         echo "corpus/noise_babble.wav";;
    foreign)       echo "corpus/fr_parasite.wav";;
    wrong)         [ "$answer_key" = ko_mul ] && echo "corpus/ko_bap.wav" || echo "corpus/ko_mul.wav";;
  esac
}

pass=0; fail=0
for scenario in "$@"; do
  mark=$(wc -l < "$LOG")
  echo "── scenario: $scenario — waiting for a listening window…"
  if ! timeout 90 sh -c "until tail -n +$mark '$LOG' | grep -q 'STT now listening'; do sleep 0.5; done"; then
    echo "   TIMEOUT waiting for mic (is a hands-free session running?)"; fail=$((fail+1)); continue
  fi
  expected=$(grep -oE '\[HF\] Card trigger.*answers=\[[^]]*\]' "$LOG" | tail -1 | sed 's/.*answers=\[//; s/\].*//' | cut -d, -f1)
  sleep 0.4   # let the recognizer's input stream settle before injecting
  wav=$(wav_for "$scenario" "$expected")
  echo "   card expects: $expected   injecting: $wav"
  node inject_audio.js "$wav" >/dev/null
  sleep 8
  window=$(tail -n +$mark "$LOG")
  verdict="none"
  echo "$window" | grep -q '\[VAL\] ✅' && verdict="correct"
  echo "$window" | grep -qE '\[VAL\] ❌ INCORRECT' && [ "$verdict" = none ] && verdict="incorrect"
  ok=false
  case "$scenario" in
    correct|correct_noisy) [ "$verdict" = correct ] && ok=true;;
    noise|foreign)         [ "$verdict" = none ] && ok=true;;
    wrong)                 [ "$verdict" = incorrect ] && ok=true;;
  esac
  if $ok; then echo "   ✅ PASS (verdict: $verdict)"; pass=$((pass+1));
  else echo "   ❌ FAIL (verdict: $verdict)"; fail=$((fail+1));
       echo "$window" | grep -E "onResult|VAL\]|🔇|no_match" | tail -6 | sed 's/^/     /'; fi
done
echo "── $pass passed, $fail failed"
[ $fail -eq 0 ]
