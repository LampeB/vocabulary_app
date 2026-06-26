# Speech Recognition Improvement Plan

> Status: **proposed / not yet implemented**. This is a design doc, not a record of
> shipped work. Author: planning session 2026-06-26.

## 1. Problem

Voice recognition is the core interaction of the app ("say the vocab word"), and
it is the weakest part of the experience. Real-world symptoms:

- Slight ambient noise throws recognition "all over the place".
- It mishears short single words, especially Korean spoken by a non-native.
- It frequently marks a correct spoken answer as wrong.

### Root cause: wrong *kind* of recognition

The quiz already knows the expected answer and a small set of accepted variants
(`QuizCard.answerWords`). The task is therefore **constrained recognition**
("did they say *this* word, or one of these few?") — not open-vocabulary
dictation.

The current engine ([`speech_recognition_service.dart`](../lib/services/speech/speech_recognition_service.dart),
the on-device `speech_to_text` plugin) does open dictation: it transcribes
against the entire language, knows nothing about the expected answer, and uses
aggressive endpointing that triggers on noise. That is exactly the observed
failure mode.

There is also a **dead second implementation**
([`whisper_stt_service.dart`](../lib/services/speech/whisper_stt_service.dart) +
the `whisper-proxy` edge function): it is never instantiated, and
`enableWhisperSTT` is never read. It was designed with `expected_word` prompt
biasing — the right idea — but is unplugged.

### Noise sensitivity has three independent causes

| # | Cause | Current state | Fix area |
|---|-------|---------------|----------|
| 1 | **Capture** — raw mic signal quality | `RecordConfig` sets no cleanup flags; VAD is a crude amplitude gate | Phase 0 |
| 2 | **Recognizer** — weak on short/accented/noisy input | platform `speech_to_text` | Phase 2 / 3 |
| 3 | **Not exploiting the constraint** — transcribe → fuzzy-match → guess | no biasing, no confidence gate | Phase 0 + all engines |

The validator's Korean particle-stripping / jamo logic
([`answer_validator.dart`](../lib/core/utils/answer_validator.dart)) is good, but
today it carries weight it shouldn't — it patches a recognizer that mishears the
word. After this work it becomes a safety net, not the primary accuracy
mechanism.

## 2. Goals & constraints

- **Best achievable accuracy** for short Korean/French words in noise, by
  non-native speakers.
- **Free tier must be ~free to run** → on-device, $0 per recognition, offline.
- **Paid tier may be more expensive/complex** → cloud, best accuracy + a real
  premium feature.
- Tiers already exist: `SubscriptionType {free, student, premium}`,
  `isPremiumProvider` (`hasAccess`).
- Hands-free / "driving" mode needs **offline** + low-latency → reinforces an
  on-device default.

### Decisions taken (planning session)

- Sequencing: **written plan first** (this doc).
- Free-tier engine: **bake-off** between sherpa-onnx and on-device Whisper, then
  decide on measured results.
- Paid-tier engine: **Azure Pronunciation Assessment** (scores pronunciation
  against the known target word — a premium *feature*, not just better STT).

## 3. Target architecture

One engine interface, implementation chosen by tier. All STT orchestration moves
out of the widget into a testable controller.

```
QuizScreen (UI only)
   │ renders state, calls controller.start(card)
   ▼
SttController  (Notifier)              ← owns the state machine:
   │  - listen lifecycle / partials      token guarding, retries,
   │  - confidence gate + re-prompt       failsafe timeout, re-prompt
   │  - validation against answerWords
   ▼
SttEngine  (interface)                ← selected by tier
   ├─ PlatformSttEngine     (current speech_to_text — kept as fallback)
   ├─ OnDeviceSttEngine     (sherpa-onnx OR whisper.cpp — bake-off winner) [FREE default]
   └─ CloudPronunciationEngine (Azure via proxy)                          [PREMIUM]
        │
        ▼
   AudioCapture  (record + noiseSuppress/echoCancel/autoGain + Silero VAD)
```

### Interface sketch (subject to refinement)

```dart
abstract class SttEngine {
  Future<bool> initialize();

  /// One constrained recognition attempt for a single card.
  Future<SttResult> recognize({
    required String langCode,           // language being SPOKEN (answer lang)
    required String expectedWord,       // primary target → biasing / reference text
    required List<String> acceptedWords,// full accepted set → re-rank target
    void Function(String partial)? onPartial,
  });

  Future<void> cancel();
  void dispose();

  // Capability flags so the controller/UI adapt:
  bool get supportsPartials;
  bool get supportsOffline;
  bool get supportsPronunciationScore;
}

enum SttOutcome { recognized, lowConfidence, noSpeech, error }

class SttResult {
  final SttOutcome outcome;
  final String transcript;
  final double? confidence;            // normalized 0..1
  final String? matchedAnswer;         // best accepted answer, if any
  final PronunciationScore? pronunciation; // premium only
  final String? errorCode;
}

class PronunciationScore {        // Azure
  final double accuracy;          // 0..100
  final double fluency;
  final double completeness;
  final double prosody;
  final List<PhonemeScore> phonemes; // for "your 'eu' needs work" UI
}
```

`SttController` is responsible for everything currently crammed into
`_QuizScreenState` (the ~200-line in-widget state machine): retry policy,
stale-callback token guarding, failsafe timeout, and the new **confidence
gate → re-prompt** loop. This makes it unit-testable with a fake `SttEngine`.

## 4. Phased plan

### Phase 0 — Cross-cutting wins (help every engine, low risk)

These improve the *current* platform STT immediately and are prerequisites for
the engines below.

1. **Capture cleanup.** Add to the recording config:
   `noiseSuppress: true`, `echoCancel: true`, `autoGain: true`
   (`record`'s `RecordConfig` supports all three; best-effort per device).
2. **Real VAD.** Replace the amplitude-gate loop in `_waitForSpeechEnd` with
   **Silero VAD** (via the [`vad`](https://pub.dev/packages/vad) package or
   sherpa-onnx's built-in VAD). Trained on noisy multi-domain audio; isolates the
   speech segment so the recognizer sees clean boundaries.
3. **Confidence gate + re-prompt.** Low-confidence result → "didn't catch that,
   try again" instead of silently scoring a wrong answer. Threshold tuned per
   engine.
4. **Exploit the constraint.** Re-rank the transcript against `acceptedWords`
   and only accept above a confidence/similarity bar; reject garbage rather than
   fuzzy-matching it to the nearest word.

> Even with no engine swap, items 1–4 should noticeably reduce the noise
> failures described in §1.

### Phase 1 — `SttEngine` interface + controller refactor

- Define `SttEngine`, `SttResult`, `SttController`.
- Move orchestration out of [`quiz_screen.dart`](../lib/presentation/screens/quiz/quiz_screen.dart)
  into `SttController`. Widget becomes render-only.
- Wrap the existing `speech_to_text` as `PlatformSttEngine` behind the interface
  so nothing breaks and we keep a universal fallback.
- Keep the `SIMULATE_SPEECH` test seam; add unit tests for the controller state
  machine with a fake engine (retries, token guard, failsafe, confidence gate).
- Decommission the dead `WhisperSttService` (delete, or fold into the cloud
  engine impl) and **secure or remove** the open `whisper-proxy`.

### Phase 2 — Free-tier on-device engine (bake-off, then build)

Two strong candidates; **measure, don't guess**.

| Candidate | Why | Cost |
|-----------|-----|------|
| **sherpa-onnx** ([pub](https://pub.dev/packages/sherpa_onnx)) | Mature Flutter pkg, built-in Silero VAD, contextual biasing / hotwords / keyword-spotter, small models, fast, offline. Can also run Whisper models. | $0 |
| **On-device Whisper** ([whisper_ggml_plus](https://pub.dev/packages/whisper_ggml_plus), [whisper_kit](https://pub.dev/packages/whisper_kit)) | Whisper accuracy + `prompt` biasing for short accented words. | $0 |

#### Bake-off methodology

1. **Dataset.** Build a labelled recording harness (reuse the audio-capture path;
   a hidden debug screen). Capture ~50–100 vocab words ×
   {quiet, moderate noise, loud/background-speech} × at least the primary user
   (more speakers if possible). Both KO and FR. Save: WAV + ground-truth label +
   the card's accepted-answer set + a few deliberate *wrong* and *silence/noise*
   clips.
2. **Configs to test.** sherpa-onnx (zipformer multilingual) · sherpa-onnx running
   a Whisper tiny/base model · whisper_ggml_plus base · whisper_ggml_plus small.
   Each run **twice**: raw transcription, and **constrained** (biased toward
   `expectedWord` + re-rank against `acceptedWords` + confidence gate).
3. **Metrics.**
   - Constrained top-1 accuracy (correct spoken words accepted).
   - **False-accept rate** on wrong/garbage/noise clips (critical — a quiz that
     accepts wrong answers is worse than useless).
   - Latency (median + p90) on a **low-end** Android device.
   - Model size / app-size impact; CPU + battery during hands-free.
4. **Decision rule.** Maximize `(constrained_accuracy − false_accepts)` subject
   to acceptable latency and app size. Document the result in this file.
5. **App-size mitigation.** Download the model on first voice use (with progress
   UI) rather than bundling — keeps the base install small.

### Phase 3 — Paid-tier: Azure Pronunciation Assessment

Premium users get the best recognition **and** pronunciation feedback.

- **Engine.** `CloudPronunciationEngine` → Azure Speech "pronunciation
  assessment". Give it the **reference text** (the expected word) + the
  **language being spoken** (answer language: FR→KO ⇒ Korean reference, KO→FR ⇒
  French reference). Azure returns recognized text + accuracy/fluency/
  completeness/prosody + per-phoneme scores.
  ([pricing](https://azure.microsoft.com/en-us/pricing/details/speech/) ≈ $0.003
  for an 8-second clip, prorated per second;
  [language-learning guide](https://learn.microsoft.com/en-us/azure/ai-services/speech-service/language-learning-with-pronunciation-assessment)).
- **Correctness vs feedback (important nuance).** Use the *recognized text* vs
  `acceptedWords` to decide right/wrong (still constrained). Use the *scores* for
  the premium "pronunciation 82% — your 'eu' needs work" UI on the feedback
  screen. If they said a completely different word, recognized text won't match →
  marked wrong, regardless of scores.
- **Proxy.** New `azure-speech-proxy` edge function holding the Azure key
  server-side. Unlike the existing `whisper-proxy`, it **must** verify the
  Supabase JWT and rate-limit (per-user daily cap) to prevent credit abuse.
- **Gating.** `isPremiumProvider` selects `CloudPronunciationEngine`; free uses
  the on-device engine. Optional Settings toggle ("Pronunciation coaching").
- **Offline / failure fallback.** No network or proxy error → fall back to the
  on-device engine so the quiz never blocks (mirrors the existing STT-unblock
  fixes).
- **Cost guardrail.** Per-second billing on short clips is cheap, but still cap
  calls/user/day and short-circuit to on-device past the cap.

> Alternative considered for paid tier: `gpt-4o-transcribe` (~$0.006/min) /
> `gpt-4o-mini-transcribe` (~$0.003/min) with prompt biasing — cheapest path to
> top-tier *recognition*, reuses the existing proxy skeleton, but gives no
> pronunciation feedback. Kept as a fallback option if Azure integration proves
> too heavy.

## 5. Cross-cutting concerns

- **Mic permission UX.** Rationale prompt + deep-link to settings when denied
  (today `hasPermission()` failing is silent).
- **Locale/model availability.** Handle missing locale/model with a clear path
  (download / fallback) instead of a permanent `error_client`.
- **Privacy.** On-device = no audio leaves the phone. Azure path sends audio to
  Microsoft → update privacy policy; never log raw audio.
- **Telemetry.** Log recognition outcome + confidence (no audio) to measure
  real-world accuracy and tune thresholds.
- **Security.** The current `whisper-proxy` is unauthenticated with
  `Access-Control-Allow-Origin: *` — fix or remove as part of Phase 1.

## 6. Testing

- Unit: `SttController` state machine via fake `SttEngine` (retries, token guard,
  failsafe, confidence gate, re-prompt).
- Extend [`answer_validator_test.dart`](../test/unit/answer_validator_test.dart)
  with confidence-gated and constrained-rerank cases.
- Bake-off harness is a dev tool, not CI.
- Keep `SIMULATE_SPEECH` for integration/manual runs.

## 7. Risks & open questions

- On-device Korean coverage/quality for sherpa zipformer models — **bake-off
  resolves**.
- App-size vs accuracy (Whisper base/small) — mitigate via on-demand download.
- Whisper latency on low-end Android for hands-free — measure in bake-off.
- Azure region latency + GDPR for sending audio — privacy policy + region choice.
- Battery for continuous on-device inference in hands-free mode.

## 8. Rough sequencing

1. **Phase 0** — capture cleanup + VAD + confidence gate. *Smallest, ships
   relief fastest.*
2. **Phase 1** — interface + controller refactor + secure/remove dead Whisper.
   *Prerequisite for tiering; unlocks tests.*
3. **Phase 2** — bake-off → on-device free engine.
4. **Phase 3** — Azure pronunciation engine + proxy + premium UI + gating.

Phases 0 and 1 are independent of the engine choice and de-risk everything after.
