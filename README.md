# VocabApp (vocab_kr)

Multi-language vocabulary & grammar learning app (Flutter). Originally
French↔Korean, now generalized: any ordered pair among **fr · en · it ·
de · es · ko**, with FSRS spaced repetition, voice quizzes (on-device
STT race + TTS), a seeded starter curriculum and a per-language grammar
engine.

**Stack:** Flutter/Dart · Riverpod · go_router · Drift (SQLite) ·
Supabase (auth, sync, edge functions) · easy_localization (7 UI
locales) · fl_chart · Patrol (E2E).

## Prerequisites

- **Flutter** stable with Dart SDK ≥ 3.4 (`flutter --version`)
- **Android SDK** + `adb` for device runs (iOS builds via CI)
- **libsqlite3** — the test suite runs Drift against the native
  library:
  - Debian/Ubuntu/Mint: `sudo apt install libsqlite3-dev` (CI does this)
  - If your distro's lib isn't found, put `libsqlite3.so` somewhere and
    prefix test runs with `LD_LIBRARY_PATH="$HOME/.local/lib:$LD_LIBRARY_PATH"`
- `python3` only if you touch the one-shot generators in `tool/seed/`

## Getting started

```bash
git clone https://github.com/LampeB/vocabulary_app.git
cd vocabulary_app
flutter pub get
```

Create **`.env.json`** at the repo root (gitignored — ask a teammate or
take the values from the Supabase/RevenueCat dashboards):

```json
{
  "SUPABASE_URL": "https://<project>.supabase.co",
  "SUPABASE_ANON_KEY": "<anon key>",
  "REVENUECAT_API_KEY": "<key>"
}
```

⚠️ Every run/build needs `--dart-define-from-file=.env.json`. Without
it the app compiles with a placeholder Supabase URL and login fails
with a network error (errno 7).

```bash
# run on a device/emulator
flutter run --dart-define-from-file=.env.json

# release APK
flutter build apk --release --dart-define-from-file=.env.json
```

Debug builds use the application id `com.vocabkr.vocab_kr.debug`
(suffix), so a debug and a release install can coexist on one phone.

## Tests

```bash
# host suite (unit + widget + integration; ~650 tests, must stay green)
LD_LIBRARY_PATH="$HOME/.local/lib:$LD_LIBRARY_PATH" flutter test
```

- The **seed validity gate** (`test/seed/seed_catalog_validity_test.dart`)
  enforces the content contracts; grammar rules carry `test_vectors`
  executed against their language module.
- **E2E** (Patrol, real quiz on an emulator) runs in CI
  (`.github/workflows/e2e.yml`); config in `patrol.toml`.
- CI: `test.yml` (host suite) + `e2e.yml` gate PRs; `build-apk.yml` and
  `ios-testflight.yml` produce artifacts and inject `.env.json` from
  repo secrets.

Discipline: run the suite and read its verdict **before** building or
committing — never chain test+build+commit blindly.

## Repo tour

| Path | What |
|---|---|
| `lib/core/` | languages registry, validators, grammar engine (`grammar/`, `grammar/latin/`) |
| `lib/domain/` · `lib/data/` | entities · Drift DB, DAOs, repositories, sync, `data/seed/` (StarterSeeder) |
| `lib/presentation/` | Riverpod providers + screens |
| `lib/services/` | quiz orchestration (VoiceTurnMachine, AudioDirector) + speech (SttRace engines) |
| `assets/seed/` | starter curriculum: `vocab/registry.json` + `vocab/lang/<code>.json` layers, `grammar/<lang>/rules.json` |
| `assets/translations/` | 7 UI locales (flat dotted keys) |
| `supabase/` | SQL migrations (applied to the hosted project) + edge functions |
| `docs/` | all plans & design docs (see below) |
| `tool/seed/` | one-shot content generators · `test/` mirrors lib layout |

## Where to read next

- **`docs/design/v2-ux-architecture.md`** — the v2 product/UX blueprint
  (screens, flows, diagrams).
- **`docs/design/map/app-map.md`** — the decision map: per area, what's
  decided / proposed / open. **Keep it updated with every decision.**
- `docs/implementation-plan-v2.md` — build milestones M1-M10.
- `docs/content-roadmap.md` + `docs/seed-content-authoring.md` — the
  content pipeline (orderable units U1-U9, format contracts). Content
  is generated via the `seed-content` skill / `seed-content-author`
  agent (`.claude/`), one unit per run, gate green.
- Task tracking lives on the Notion board **“VocabApp — Tasks”**.

## House rules

- **Never rename a `seed_id`** (list or concept) — seeded rows and
  grammar prerequisites reconcile by these ids.
- **Voice changes go through the seams**: `VoiceTurnMachine`,
  `AudioDirector`, `SttRace` — never ad-hoc audio/STT calls in screens.
- New curriculum content must pass the validity gate and follow the
  style rule: every example sentence must be usable in real travel /
  conversation.
- Multi-language by design: nothing ships Korean-only by accident;
  every feature states its story for all studyable pairs.
