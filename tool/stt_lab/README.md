# STT Lab — acoustic test harness

Validates the voice pipeline against **real audio through the real Google
recognizer**: noisy environments, parasitic speech, echoes — the things host
tests can't reach. WAV scenarios are injected straight into the Android
emulator's virtual microphone over its gRPC API while the app runs a genuine
hands-free session; outcomes are judged from the app's own STT debug log
(`lib/core/utils/stt_debug_log.dart`).

First catch (2026-07-06): French speech near the phone produced an empty
final recognizer result that the app submitted as an answer, grading the
card wrong before the user spoke. Fixed in `quiz_screen.dart` (empty finals
now belong to the not-heard recovery).

## One-time setup

```sh
cd tool/stt_lab
npm install
cp ~/Android/Sdk/emulator/lib/emulator_controller.proto .
./gen_corpus.sh          # TTS clips + noise beds + mixes → corpus/
```

## Per-run flow

1. **Emulator with gRPC** (Play-Store image so Google's recognizer exists):

   ```sh
   emulator -avd <AVD> -no-window -no-snapshot -grpc 8554
   ```

   Don't bother with host-audio routing (`-audio pa` fails on PipeWire
   hosts; `hostmicon` is a red herring) — gRPC `injectAudio` bypasses the
   host audio stack entirely.

2. **App in a hands-free session**: install the release APK, sign in as the
   lab account (`stt.lab@vocabkr.com`, list "STT Lab": 물/커피/밥/학생/친구),
   grant the mic (`adb shell pm grant com.vocabkr.vocab_kr.debug
   android.permission.RECORD_AUDIO`), start Hands-free / FR→KO / 10 cards.

3. **Run scenarios**:

   ```sh
   ./run_scenarios.sh correct noise foreign correct_noisy wrong
   ```

   Each scenario waits for a listening window, reads the expected answer
   from the log, injects the matching WAV, and judges the outcome:

   | scenario        | audio                       | must produce            |
   |-----------------|-----------------------------|-------------------------|
   | `correct`       | the answer, clean           | CORRECT verdict         |
   | `correct_noisy` | the answer buried in babble | CORRECT verdict         |
   | `noise`         | babble only                 | NO verdict (re-listen)  |
   | `foreign`       | French speech               | NO verdict (re-listen)  |
   | `wrong`         | another word, clean         | INCORRECT verdict       |

## Manual injection

```sh
node inject_audio.js corpus/ko_mul.wav        # speak 물 into the mic
node inject_audio.js corpus/noise_babble.wav 0.5   # optional gain arg
```

## Notes & gotchas

- Scenario runs can collide with the previous card's re-listen recovery —
  if a `correct`/`wrong` scenario reports `verdict: none`, re-run before
  suspecting the app. Short single-syllable clips (밥, 물) are the least
  reliably recognized; prefer multi-syllable words when authoring new
  scenarios.

- The recognizer is Google's cloud-assisted engine: needs network, results
  vary slightly run-to-run. Treat this as a lab, not a deterministic CI
  gate — if it ever goes to CI, use pass-rates over N runs in a separate,
  non-gating workflow (emulator audio has a history of destabilizing our
  E2E; see docs/test-coverage-roadmap.md).
- It tests Google's engine, not Samsung's (the S22 default). Pipeline
  logic generalizes; engine quirks may not. Field evidence comes from the
  on-device STT log: `adb pull /sdcard/Android/data/com.vocabkr.vocab_kr.debug/files/stt_logs`.
- Echo scenarios: inject a recording of the app's own TTS voice during a
  listening window; the mic-waits-for-TTS + noise-guard logic is what's
  under test.
- The lab account/list live in production Supabase — recreate via
  the GoTrue signup endpoint + a SQL seed if ever deleted.
