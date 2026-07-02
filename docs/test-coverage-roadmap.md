# Test-coverage roadmap

> **Purpose of this document.** The remaining test-coverage work, ordered by
> importance, written so that anyone — a future Claude session, a different
> model, or a human — can pick it up cold and execute it without any other
> context. If you are an AI agent reading this: work through the phases in
> order, tick the checkboxes as you complete items (edit this file), commit
> per phase, and keep the suite green at every commit.
>
> Status: phases 0–9 of the original coverage plan (auth, settings,
> import/export, audio, offline, notifications, stats, social, paywall) are
> **done** — 293 host tests green as of 2026-07-03. This document is the
> follow-up plan.

---

## Ground rules (read first)

1. **Read `docs/writing-tests.md` before writing any test.** It has the
   project conventions (no `/` in Patrol test names, cleanup rules, step
   library usage).
2. **Two CI gates**, both must stay green:
   - **Host tests** — `.github/workflows/test.yml`, runs `flutter test` on
     every push. ~1.5 min. This is the primary regression gate.
   - **E2E** — `.github/workflows/e2e.yml`, Patrol on an Android emulator,
     manual dispatch (`workflow_dispatch`), 20-test umbrella
     `patrol_test/quiz_all_test.dart`, with a `target` input to run a single
     file.
3. **Running host tests locally on Linux** needs the native sqlite lib:
   ```bash
   LD_LIBRARY_PATH="$HOME/.local/lib:$LD_LIBRARY_PATH" flutter test
   ```
   (On CI it's `apt-get install libsqlite3-dev`.) The two
   "unable to find directory entry … assets/" lines are pre-existing warnings,
   not failures.
4. **Prefer host tests over E2E.** The established pattern for device-coupled
   logic: extract the pure decision/computation into a small function
   (behavior-preserving refactor), unit-test that, leave the plugin call
   untested. Precedents to copy:
   - `lib/core/network/connectivity_status.dart` (from app_shell)
   - `lib/services/notifications/notification_schedule.dart` (from the plugin service)
   - `lib/core/utils/streak.dart` (from the Supabase datasource)
   - `shouldSpeakAnswer` in `lib/presentation/providers/quiz/quiz_provider.dart`
5. **Test-file patterns already in the repo — copy them, don't invent new ones:**
   - Pure logic → `test/unit/<area>/..._test.dart`, plain `flutter_test`.
   - Riverpod notifier with prefs → `SharedPreferences.setMockInitialValues({})`
     + `ProviderContainer` (see `test/unit/settings/settings_provider_test.dart`).
   - Repository against real drift → `AppDatabase.forTesting(NativeDatabase.memory())`
     + `FakeRemote` from `test/helpers/fake_remote.dart`
     (see `test/integration/share_import_test.dart`, `offline_resilience_test.dart`).
   - Provider-level gating with fake repo + overrides →
     `test/integration/paywall_gate_test.dart` (ProviderContainer with
     `overrideWithValue` / `overrideWith`, `noSuchMethod` fakes).
6. **One commit per phase**, message style `test(<area>): <what>`, run the full
   suite before each commit.
7. **Known stubs — do NOT write tests asserting their current hardcoded
   behavior** (they will be implemented later; test them then):
   - `ProgressRepositoryImpl.getListStats` (returns hardcoded zeros)
   - `ProgressRepositoryImpl.resetProgress` (no-op)
   - `SocialRepositoryImpl.watchChallenges` (returns empty stream)
   - `sync_queue` table (defined in drift, no consumer anywhere)

---

## Phase 1 — Measure coverage & make it visible in CI

**Why first:** everything after this should be guided by data, not by area
names. We built coverage by feature area; a line-coverage report will show the
actual blind spots.

- [x] Run locally: `LD_LIBRARY_PATH=... flutter test --coverage`
      → produces `coverage/lcov.info`.
- [x] Summarize it (script: count `DA:` hit/total per `SF:` block).
- [x] Ranked least-covered list → see "Coverage findings" below.
- [x] Coverage in CI: `test.yml` now runs `flutter test --coverage`, prints the
      total % to the log and `$GITHUB_STEP_SUMMARY` (with `LC_ALL=C` — comma
      locales break `printf %.1f`), and uploads `lcov.info` as an artifact.
      No hard threshold yet — that's Phase 5.
- [x] Baseline (2026-07-03): **32.9 %** overall / **46.0 %** excluding
      generated (`*.g.dart`, `*.freezed.dart`) files.

**Done when:** CI prints a coverage number on every push and the findings list
below is filled in. ✅ 2026-07-03

### Coverage findings (2026-07-03)

Ranked by uncovered lines, non-generated and non-screen files. Screens do not
appear in lcov at all — no test imports them (confirms Phase 3).

| % | lines hit | uncovered | file | note |
|---|-----------|-----------|------|------|
| 1.4 | 3/213 | 210 | `presentation/providers/quiz/quiz_provider.dart` | **Phase 2 target** |
| 0.0 | 0/92 | 92 | `data/repositories/auth_repository_impl.dart` | Supabase-coupled; auth is E2E-covered. Profile-row mapping (~l.185) could be extracted+tested |
| 17.9 | 17/95 | 78 | `presentation/providers/lists/vocabulary_provider.dart` | Phase 4 (notifier actions beyond the paywall gate) |
| 0.0 | 0/70 | 70 | `data/datasources/remote/auth_remote_datasource.dart` | Supabase-coupled; low host-test value |
| 0.0 | 0/65 | 65 | `data/datasources/remote/vocabulary_remote_datasource.dart` | Supabase-coupled; exercised indirectly via FakeRemote's interface |
| 79.9 | 243/304 | 61 | `data/repositories/vocabulary_repository_impl.dart` | Phase 4 (delete/update/sync paths) |
| 0.0 | 0/50 | 50 | `presentation/providers/auth/auth_provider.dart` | auth state plumbing; consider with Phase 3 harness |
| 0.0 | 0/42 | 42 | `services/audio/elevenlabs_service.dart` | device/mock-only by decision (see strategy) |
| 18.8 | 9/48 | 39 | `presentation/providers/notifications/notification_provider.dart` | notifier persistence paths untested (only the model is) |
| 0.0 | 0/39 | 39 | `services/notifications/notification_service.dart` | native plugin wrapper — rules extracted+tested, wrapper stays device-only |
| 2.9 | 1/34 | 33 | `presentation/providers/purchases/purchase_provider.dart` | RevenueCat-coupled; isPremium fallback logic partially reachable |
| 0.0 | 0/31 | 31 | `services/audio/flutter_tts_service.dart` | device-only by decision |
| 0.0 | 0/23 | 23 | `services/purchases/purchase_service.dart` | RevenueCat wrapper — device-only |
| 27.6 | 8/29 | 21 | `core/theme/app_text_styles.dart` | cosmetic; covered incidentally by Phase 3 |
| 66.7 | 34/51 | 17 | `core/utils/answer_validator.dart` | pure logic, partly tested — **top up in Phase 2** (cheap win) |

Interpretation: after excluding files that are device/backend-coupled by
deliberate decision, the real host-testable gaps are exactly Phases 2–4 of
this roadmap, plus `answer_validator.dart` (added to Phase 2).

---

## Phase 2 — Quiz session assembly (biggest untested pure logic)

**Target:** `QuizNotifier.loadCards` in
`lib/presentation/providers/quiz/quiz_provider.dart` (~lines 200–325). This
builds every quiz session and is completely untested. It contains real,
bug-prone rules:

1. **"Both directions" split:** `halfLimit = (cardLimit + 1) ~/ 2`, one
   `getDueCards` call per direction.
2. **Interleaving:** FR, KO, FR, KO…, tolerating unequal list lengths.
3. **Truncation:** interleaved result capped at `cardLimit`.
4. **Failure policy:** in "both" mode, error state **only when both calls
   fail**; one failure + one success proceeds with the successful half. In
   single-direction mode, any failure → `errorMessage` state.
5. **Empty result:** `isComplete: true` immediately (no error).
6. **Enrichment/drop rule:** cards whose question variant can't be resolved in
   the local DB are silently dropped.
7. **Padding:** if fewer cards than `cardLimit`, repeat cards cyclically until
   the limit is reached.

**Recommended approach (two layers):**

- [x] **Extract the list mechanics** (steps 2, 3, 7 — interleave, truncate,
      pad-cyclically) into pure top-level functions in a new file
      `lib/presentation/providers/quiz/session_assembly.dart` (or into
      `quiz_provider.dart` as top-level functions like `shouldSpeakAnswer`).
      Behavior-preserving refactor: `loadCards` calls them. Unit-test
      exhaustively in `test/unit/quiz/session_assembly_test.dart`:
      odd/even `cardLimit` halving, unequal FR/KO lengths, empty one side,
      truncation order (interleaved prefix), padding cycles the *assembled*
      list, single-card padding.
      ✅ Done 2026-07-03 — `halfLimit`/`interleaveAndCap`/`padCyclically`, 14 tests, 100% file coverage.
- [x] **Test `loadCards` end-to-end at the provider level** in
      `test/integration/quiz_load_cards_test.dart`, following the
      `paywall_gate_test.dart` harness pattern: `ProviderContainer` with
      overrides for `getDueCardsUseCaseProvider` (fake returning canned
      `VariantProgress` lists per direction), `conceptDaoProvider` (real
      in-memory drift DB pre-seeded with variants, since enrichment reads it),
      `currentUserProvider`, and `audioPlayerServiceProvider` (no-op fake).
      Cover: both-fail → error state; one-fail-one-success → session built;
      empty → `isComplete`; unresolvable variant dropped; answer words match
      the card's direction.
      - Check how `audioPlayerServiceProvider` and `_kTestMode` behave under
        test before writing; if the notifier autoplays audio on load, override
        the audio service with a recording fake.
      ✅ Done 2026-07-03 — `test/integration/quiz_load_cards_test.dart`, 8 tests.
      The notifier provider is named `quizProvider` (not quizNotifierProvider);
      the autoplay-on-load branch needed the `_NoopAudio` override as predicted.
- [x] **Top up `lib/core/utils/answer_validator.dart`** (66.7% — found in
      Phase 1): pure logic. There was NO existing test file (the 66.7% was
      incidental via other tests). Created `test/unit/core/answer_validator_test.dart`,
      12 tests: base verdicts incl. the acceptable/typo Dice-score boundaries,
      the multi-word transcript pass, and both Korean particle passes
      (prefix ≥2 chars; trailing-strip for 1-char answers). File now 100%.

**Done when:** all three items pass, `flutter analyze` clean, full suite green.
✅ Phase 2 complete 2026-07-03 — 327 tests total, coverage 35.2% (51.8% excl.
generated); `quiz_provider.dart` 1.4% → 41.5% (the remainder is submit/voice/
session-complete flows — device-coupled or covered elsewhere).

---

## Phase 3 — Screen-level widget tests

**Why:** currently only 3 component widget tests exist (`test/widget/`). A
button pushed off-screen, a dialog that no longer opens, or a provider wiring
mistake is invisible to unit tests, and E2E only walks a few flows on an
emulator. Screen-level widget tests catch these host-side in milliseconds.

**Harness to build first (one-time):**

- [x] `test/helpers/pump_screen.dart` — DONE 2026-07-03. Key learnings, all
      documented in the helper itself:
      - Do NOT pump the `EasyLocalization` widget: its async delegate can only
        load once per test process (second pump renders an empty shell
        forever). Instead `initTestLocalization()` hydrates the global
        `Localization` table from `fr.json` in `setUpAll` — real French
        strings and `.tr()` work in tests, no async widget.
      - Screens that read `context.locale` were switched to
        `Localizations.localeOf(context)` (identical in-app).
      - Phone-like 360×780 viewport (default 800×600 hides real overflows).
      - drift awaits deadlock under FakeAsync → seed/assert via
        `tester.runAsync`; call `unmountScreen()` at the end of drift-stream
        tests (flushes drift's zero-duration close timers).
      - `settle: false` for screens with perpetual animations (waveform).

**Screens, in value order** (use `WidgetKeys` for all finds/taps):

- [x] **Start-session screen** — 6 tests. (sections, CTA gating, auto-advance, /quiz args capture)
      _Original spec:_ **Start-session screen** (`lib/presentation/screens/quiz/` — the screen
      with `startSection(i)` / `startType(name)` keys): every section renders,
      selecting direction/count/type updates the pending args, start button
      fires with the chosen `QuizArgs` (capture via overridden provider).
      Free-vs-premium differences if any section is gated.
- [x] **List detail screen** — 4 tests against a REAL in-memory-drift repo (tiles, add, edit incl. the variantsProvider regression pin, delete).
      _Original spec:_ **List detail screen**: add-word flow opens dialog and calls
      `addConcept` with typed words; edit mode toggles; delete confirmation
      calls `deleteWord`; the word-count and tiles render from a fake
      concepts stream.
- [x] **Paywall screen** — 4 tests (static content, null/error/loading offerings). Purchase buttons need real RevenueCat Package objects — deferred, purchase flow is device/mock-only by decision.
      _Original spec:_ **Paywall screen** (`lib/presentation/screens/paywall/paywall_screen.dart`):
      renders offerings from a fake `offeringsProvider`, purchase button calls
      the purchase notifier, error/loading states, "already premium" state.
- [x] **Settings screen** — 8 tests (theme pills, audio pills, premium row + /paywall, sign-out confirm/cancel, /notifications).
      _Original spec:_ **Settings screen**: theme toggle calls `themeModeProvider.set`,
      premium row reflects `isPremiumProvider` both ways, audio sliders call
      `setSpeechRate`/`setPitch`.
- [x] **Home screen** — 5 tests (render, list-tile nav, bell, streak-warning arming / not-arming).
      _Original spec:_ **Home screen**: renders with fake lists/user; notification bell
      navigates (router can be faked with a `GoRouter` test instance or by
      asserting navigation intent).

**Done when:** each screen has a `test/widget/screens/<name>_test.dart` that
would fail if its main interactive elements disappeared or stopped calling
their providers.
✅ Phase 3 complete 2026-07-03 — 27 screen tests. The realistic viewport
immediately caught FOUR real layout bugs, all fixed: popup-menu labels
(list detail), audio pills row (settings), feature-list labels (paywall) —
all overflowing at 360dp — and the fixed-height streak card (home)
overflowing at large text scales. 354 tests total; 44.9% / 64.8% excl.
generated.

---

## Phase 4 — Remaining repository/DAO behavior

**Target:** `VocabularyRepositoryImpl` methods that still lack direct tests.
Same harness as `share_import_test.dart` (in-memory drift + `FakeRemote`).
Check against existing tests in `test/integration/` first —
`vocabulary_repository_test.dart` already covers JSON roundtrip; don't
duplicate.

- [ ] `updateList` / rename (via `ListActionsNotifier.renameList` or repo
      directly): persists, bumps `updatedAt`, `isSynced` false.
- [ ] `deleteList`: soft-delete semantics — row still exists with
      `isDeleted: true` (see `softDelete` in the DAO) and disappears from
      `watchMyLists`.
- [ ] `deleteConcept` / `deleteVariant`: word-count bookkeeping
      (`_updateWordCount`) stays consistent.
- [ ] `getListByShareToken`: found/not-found.
- [ ] `updateVariants` (in `vocabulary_provider.dart`): the E2E-found bug —
      after update, `variantsProvider(conceptId)` is invalidated. A regression
      test at provider level: read `variantsProvider`, update, read again →
      fresh data. (This bug shipped once already; pin it.)
- [ ] `syncFromRemote`: with a `FakeRemote` returning remote rows — remote
      lists/concepts land locally; local-only unsynced rows are not clobbered.
      Read the implementation first and test what it *does*; if it has no
      conflict handling yet, test the happy path and note the gap here rather
      than inventing expected behavior.

**Done when:** each box ticked with a passing test or an explicit note here
saying why it was skipped.

---

## Phase 5 — Coverage threshold gate in CI

Only after Phases 2–4 (the number will have moved).

- [ ] Re-run coverage, note the new total: **____ %**.
- [ ] Add a CI step to `.github/workflows/test.yml` that fails if total line
      coverage drops more than ~2 points below that number (simple `lcov
      --summary` + shell arithmetic; no external services needed).
- [ ] Record the enforced floor in this file.

**Done when:** a PR that deletes tests fails CI.

---

## Phase 6 — E2E additions (only high-value journeys)

E2E is expensive and flaky; add only journeys whose breakage would be
release-blocking and that host tests genuinely cannot see. Follow
`docs/writing-tests.md` §2 (naming: **no `/` in test names** — it crashes the
Android orchestrator; cleanup: `given.aCleanSlate()`).

- [ ] **Share/import deep link**: create list → `generatesShareLink` → import
      via `vocabkr://import?token=…` intent (Patrol can launch intents; if
      intent-launching proves unreliable on the CI emulator, drop this and
      rely on the host-side share_import tests — note the decision here).
- [ ] **Stabilize the real-login test** (`patrol_test/auth_login_test.dart`,
      currently isolated and flaky, run via workflow input
      `-f target=patrol_test/auth_login_test.dart`): add retry-with-backoff
      around the login tap, longer settle after auth network round-trip.
      Goal: green 3 consecutive runs, then add it to the umbrella. If it
      can't be stabilized in ~2 attempts, leave it isolated and note why.
- [ ] **Quiz completion journey**: finish a full 3-card session (TEST_CARD_LIMIT=3
      in CI) → completion screen shows → stats/streak reflect the session.

**Done when:** umbrella still ≥ as reliable as before (3 consecutive green
dispatch runs).

---

## Phase 7 — Golden (screenshot) tests — deliberately deferred

**Decision:** do NOT adopt golden tests yet. They are high-maintenance (every
intentional visual tweak breaks them) and the app's design is still moving
(active `feat/study-redesign` work). Revisit when the visual design has been
stable for a few weeks. If adopted: start with 3–5 stable atoms (mastery bar,
streak counter, list tile), `flutter test --update-goldens` workflow,
tolerance for font rendering differences between local and CI (pin a font or
use `golden_toolkit`).

---

## Standing rule (applies forever, not a phase)

Every new feature or stub implementation ships **with its tests in the same
PR**:

- Implementing `getListStats` / `resetProgress` / `watchChallenges` / the
  sync queue → integration tests in the same commit (the sync queue
  especially: enqueue-on-offline-write, drain-on-reconnect, retry counting).
- New screen → widget test (Phase 3 harness makes this cheap).
- New pure rule → unit test next to the precedents listed in Ground rules §4.
- Bug found in production/E2E → regression test pinning the fix (precedent:
  the `variantsProvider` invalidation bug).

---

## Progress log

| Date | Phase | What was done | By |
|------|-------|---------------|-----|
| 2026-07-03 | — | Roadmap written; phases 1–7 defined | Claude (session with Thomas) |
| 2026-07-03 | 1 | **Phase 1 done.** Baseline 32.9% (46.0% excl. generated); CI prints % + uploads lcov artifact; findings table filled; answer_validator added to Phase 2 | Claude (session with Thomas) |
| 2026-07-03 | 2 | **Phase 2 done.** session_assembly extracted (14 tests), loadCards provider-level (8 tests), answer_validator (12 tests, →100%). 327 total, 35.2% / 51.8% | Claude (session with Thomas) |
| 2026-07-03 | 3 | **Phase 3 done.** pump_screen harness + 27 tests over 5 screens; 4 real 360dp/text-scale layout bugs found & fixed. 354 total, 44.9% / 64.8% | Claude (session with Thomas) |
