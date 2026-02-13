# Feature Tracker - Vocabulary App

## Hands-Free / Driving Mode

Goal: A fully hands-free vocabulary practice experience for use while driving. Minimize screen interaction — everything should be audio-based.

### Completed

- [x] **Hands-free voice mode toggle** — AppBar button to toggle hands-free mode on/off in the quiz screen. Auto-plays question audio, auto-starts mic, auto-validates, plays correct/incorrect sound, auto-advances to next question.
- [x] **Sound effects** — Correct (chime) and incorrect (buzz) WAV sounds via dedicated `SoundEffectsService` with separate `AudioPlayer` instance.
- [x] **Audio completion detection** — `playAudioSmartAndWait()` in `AudioPlayerService` and `speakAndWait()` in `FlutterTtsService` so the hands-free cycle can sequence: play audio → wait → start mic.
- [x] **Preference persistence** — Hands-free toggle saved to SharedPreferences, restored on next quiz launch.
- [x] **Auto-validation in hands-free mode** — STT result always auto-validates (no confidence threshold gate).
- [x] **STT failure auto-pause** — After 3 consecutive STT failures, hands-free mode pauses with a message.
- [x] **Speak correct answer when wrong** — In hands-free mode, after an incorrect answer, TTS speaks the correct answer word before auto-advancing.
- [x] **Verbal score at end** — In hands-free mode, TTS announces "Quiz terminé. X sur Y correct. Z pourcent." before showing the results dialog.
- [x] **Longer STT patience** — In hands-free mode, listen timeout increased from 4s to 8s, max consecutive failures from 3 to 5.
- [x] **Driving-friendly setting** — "Mode conduite" toggle in Settings screen. When enabled, quiz always launches in hands-free mode. Persisted via SharedPreferences.

### To Do

#### 1. Auto-start hands-free on quiz launch
- Add a "Mode conduite" button on the list detail page (next to the existing quiz button)
- Tapping it launches the quiz with `handsFree: true` parameter
- Quiz screen reads this parameter and starts in hands-free mode immediately

**Files:** `lib/screens/list_detail_screen.dart`, `lib/screens/quiz_screen_stt.dart`

#### 2. Simplified driving UI
When hands-free / driving mode is active:
- Hide the text input field, direction label, and manual buttons
- Show a large centered mic icon (animated when listening)
- Full-screen green flash for correct, red flash for incorrect
- Large question word text
- Minimal chrome — just the word + mic state + score

**Files:** `lib/screens/quiz_screen_stt.dart` (build method)

#### 3. Voice commands
Intercept recognized text before answer validation:
- "repeat" / "répète" → replay question audio, restart listening
- "skip" / "passe" → skip to next question (mark as incorrect)
- "stop" / "arrête" → exit quiz, show results

**Files:** `lib/screens/quiz_screen_stt.dart` (`_startListening` onResult callback)

#### 4. Continuous session
When quiz finishes in hands-free mode:
- TTS-announce score
- Brief pause (3s)
- Auto-load a new set of questions (prioritize weak/due words via SRS)
- Continue the hands-free cycle without user interaction
- Keep a running total score across rounds

**Files:** `lib/screens/quiz_screen_stt.dart` (`_showResults`, `_loadQuestions`)

#### 5. Bluetooth audio support
- Verify TTS output routes through Bluetooth SCO/A2DP
- Verify STT input works from Bluetooth mic
- May need `android.media.AudioManager` configuration via platform channel
- Test with car Bluetooth system

**Files:** Platform-specific (Android `MainActivity.kt`), possibly `SpeechRecognitionService`

---

## Other Features (non-driving)

### Completed
- [x] STT quiz screen with mic button
- [x] Audio playback (TTS + file-based) for question words
- [x] Answer validation with 85% similarity threshold
- [x] SRS (Spaced Repetition System) progress tracking
- [x] Bidirectional quiz (FR→KO and KO→FR)
- [x] Retry mechanism in Appium test BasePage (500ms attempts, 200ms delay)
- [x] Appium BDD tests for quiz features (voice-input.feature)
- [x] `withOpacity` → `withValues` deprecation fixes
- [x] Reliable app data reset between test runs (`pm clear`)
