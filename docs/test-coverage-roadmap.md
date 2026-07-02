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

- [ ] Run locally: `LD_LIBRARY_PATH=... flutter test --coverage`
      → produces `coverage/lcov.info`.
- [ ] Summarize it. Without lcov installed, a quick summary works:
      count `DA:` hit/total per `SF:` block in `lcov.info` (small script), or
      `apt-get install lcov` and use `lcov --summary` / `genhtml`.
- [ ] Produce a short ranked list: the 15 least-covered files under `lib/`
      **excluding** generated code (`*.g.dart`, `*.freezed.dart`) and screens
      (screens are Phase 3's concern). Paste that list into this document
      under "Coverage findings" below.
- [ ] Add coverage to CI: in `.github/workflows/test.yml` change the test step
      to `flutter test --coverage`, then add a step that prints the total line
      coverage % to the job log (and optionally uploads `lcov.info` as an
      artifact). **Do not add a hard threshold gate yet** — set the threshold
      in Phase 5 once the number is stable, to avoid blocking unrelated work.
- [ ] Note the baseline % here: **baseline = ____ %** (fill in).

**Done when:** CI prints a coverage number on every push and the findings list
below is filled in.

### Coverage findings (fill in during Phase 1)

_TODO: ranked list of least-covered non-generated, non-screen files._

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

- [ ] **Extract the list mechanics** (steps 2, 3, 7 — interleave, truncate,
      pad-cyclically) into pure top-level functions in a new file
      `lib/presentation/providers/quiz/session_assembly.dart` (or into
      `quiz_provider.dart` as top-level functions like `shouldSpeakAnswer`).
      Behavior-preserving refactor: `loadCards` calls them. Unit-test
      exhaustively in `test/unit/quiz/session_assembly_test.dart`:
      odd/even `cardLimit` halving, unequal FR/KO lengths, empty one side,
      truncation order (interleaved prefix), padding cycles the *assembled*
      list, single-card padding.
- [ ] **Test `loadCards` end-to-end at the provider level** in
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

**Done when:** both files pass, `flutter analyze` clean, full suite green.

---

## Phase 3 — Screen-level widget tests

**Why:** currently only 3 component widget tests exist (`test/widget/`). A
button pushed off-screen, a dialog that no longer opens, or a provider wiring
mistake is invisible to unit tests, and E2E only walks a few flows on an
emulator. Screen-level widget tests catch these host-side in milliseconds.

**Harness to build first (one-time):**

- [ ] `test/helpers/pump_screen.dart` — a `pumpScreen(tester, widget, {overrides})`
      helper that wraps the widget in `ProviderScope(overrides: ...)` +
      `MaterialApp` + `EasyLocalization` (check how `lib/app.dart` initializes
      easy_localization; in widget tests you can also stub translations by
      loading the real `assets/translations` or using
      `EasyLocalization.ensureInitialized()` in `setUpAll`). Reuse the fake
      repo/provider patterns from `paywall_gate_test.dart`.
      **If easy_localization proves painful**, it is acceptable to assert on
      `WidgetKeys` and icons instead of translated strings — keys are the
      project's stable selector convention (`lib/core/widget_keys.dart`).

**Screens, in value order** (use `WidgetKeys` for all finds/taps):

- [ ] **Start-session screen** (`lib/presentation/screens/quiz/` — the screen
      with `startSection(i)` / `startType(name)` keys): every section renders,
      selecting direction/count/type updates the pending args, start button
      fires with the chosen `QuizArgs` (capture via overridden provider).
      Free-vs-premium differences if any section is gated.
- [ ] **List detail screen**: add-word flow opens dialog and calls
      `addConcept` with typed words; edit mode toggles; delete confirmation
      calls `deleteWord`; the word-count and tiles render from a fake
      concepts stream.
- [ ] **Paywall screen** (`lib/presentation/screens/paywall/paywall_screen.dart`):
      renders offerings from a fake `offeringsProvider`, purchase button calls
      the purchase notifier, error/loading states, "already premium" state.
- [ ] **Settings screen**: theme toggle calls `themeModeProvider.set`,
      premium row reflects `isPremiumProvider` both ways, audio sliders call
      `setSpeechRate`/`setPitch`.
- [ ] **Home screen**: renders with fake lists/user; notification bell
      navigates (router can be faked with a `GoRouter` test instance or by
      asserting navigation intent).

**Done when:** each screen has a `test/widget/screens/<name>_test.dart` that
would fail if its main interactive elements disappeared or stopped calling
their providers.

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
