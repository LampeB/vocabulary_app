# VocabApp (VocabKR) — Project Status

*Status report as of 26 June 2026. Compiled from the Notion workspace and the local repo.*

## What the app is

VocabApp (product name **VocabKR**) is a mobile app for learning vocabulary between **French and Korean**, built ground-up in **Flutter / Dart** (the current rewrite started June 2026 and supersedes an earlier, now-archived plan to move to React Native).

It is **audio-first**: every word is read aloud and the learner answers by speaking, with a dedicated eyes-free "hands-free" mode. Reviews are scheduled with **spaced repetition (FSRS)** targeting 90% retention. The app is **offline-first** with cloud sync, and runs a **freemium** model. Content today is French ↔ Korean only, but the data model is designed to grow into other language pairs.

## Overall state: healthy and mature

The code, the documentation, and the design system are all consistent with each other. This is not an early prototype — it's a substantially complete build.

- All **15 screens** are implemented (onboarding, home, lists, quiz modes, stats, social, profile, paywall, settings).
- Clean four-layer architecture (presentation → domain ← data, plus services).
- **216 unit + integration tests**.
- A complete, documented **design system** ("VocabKR — Design System & Screen Reference") with tokens, components, motion, and a full screen set; design screenshots were committed to the repo yesterday.
- The latest commit (26 Jun) added the design screen reference and screenshots; recent commits before that restyled the paywall, onboarding, import, settings, and notification screens.

## Tech at a glance

Flutter + Riverpod (state), drift/SQLite (local DB), Supabase (auth + cloud sync), freezed (models), RevenueCat (subscriptions). Audio uses ElevenLabs (premium TTS) and flutter_tts (free) via Supabase edge functions; voice input uses on-device STT with an OpenAI Whisper proxy available. Secrets are injected at build time via `--dart-define`.

## Where it left off — open threads

### 1. Speech recognition — the biggest open item (planned, not built)

There is an uncommitted document, `docs/stt-improvement-plan.md`, explicitly marked *"proposed / not yet implemented."* It identifies voice recognition — the core interaction of the whole app — as **the weakest part of the experience**. Real symptoms noted: slight background noise throws it off, it mishears short single words (especially Korean spoken by a non-native), and it frequently marks a correct spoken answer as wrong.

The plan's key insight: the quiz already knows the expected answer, so this should be **constrained recognition** ("did they say *this* word?"), not open-ended dictation as it does today. It also notes a second, better-designed Whisper implementation already exists in the code but is currently unplugged. The plan proposes a tiered approach: a free on-device engine (a "bake-off" between two options) and a premium cloud option (Azure Pronunciation Assessment). **This is written but no code has been done yet.**

### 2. Open UI polish tasks (on the Notion board)

- **Quiz Setup** — UI polish: mode grid, direction tile opacity and selected color.
- **Quiz screen** — light/dark card redesign (remove the always-black center block).

### 3. Dark theme not fully designed

The design system notes that dark surfaces exist on a few screens, but a **full dark theme of every screen is not yet designed**. Token mappings are sketched but need to be confirmed with design before shipping.

## Recommendation

The design side is in good shape, so the highest-impact next move is **the speech recognition rework** — it's the core interaction, it's the most-complained-about, and there's already a detailed plan plus a half-built Whisper path to build on. The two quiz UI tasks are smaller and good to knock out alongside it. The full dark theme is worth doing but is the least urgent of the three.

## Sources

- [VocabApp — Flutter App (Notion)](https://app.notion.com/p/38a7700fd0fb81a4a8f0ca3cdd9f7dff)
- [VocabKR — Design System & Screen Reference (Notion)](https://app.notion.com/p/38b7700fd0fb81298f95fbce440b7fde)
- VocabApp — Tasks board (Notion database)
- Local repo: `vocabulary_app` (latest commit `25b25d0`, 26 Jun 2026) and `docs/stt-improvement-plan.md`
