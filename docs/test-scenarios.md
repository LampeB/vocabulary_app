# Test scenarios — VocabKR

> A **scenario catalogue** for thoroughly validating the app, derived from the
> Notion functional + domain docs and the live codebase. This is the *what to
> prove* list. For *how to write each test* see [`writing-tests.md`](./writing-tests.md);
> for *what already exists* see [`../TESTS.md`](../TESTS.md).
>
> **How to use it:** each row is one provable behaviour at its cheapest layer
> (§1 of the how-to). Pick an unchecked 🆕 row, implement it in the indicated
> folder using the existing step/key vocabulary, and check it off. Items marked
> 🔧 need a new step / widget-key / helper first — those are gathered in §7.

## Legend

| Mark | Meaning |
|------|---------|
| ✅ | Already covered — file named in the row; **do not re-prove**. |
| 🆕 | Proposed new test — infra already exists, just write it. |
| 🔧 | Proposed, but needs a new step / `WidgetKeys` constant / seed helper first (see §7). |
| 🖐️ | Device/manual only — not a CI scenario (real STT, real purchase, real audio, permissions). |

Layer abbreviations: **U**=unit (`test/unit/`), **I**=integration (`test/integration/`), **W**=widget (`test/widget/`), **E**=E2E Patrol (`patrol_test/`).

---

## 1. Domain logic — unit tests (`test/unit/`)

The cheapest layer. Most scoring/scheduling/validation rules belong here and
must **not** be re-proven in a slow E2E.

### 1.1 FSRS scheduling — `core/utils/fsrs_algorithm.dart`
Largely covered by `fsrs_algorithm_test.dart` (21 tests). Verify these specific
behaviours exist; add any missing.

| # | Behaviour | Layer | Status |
|---|-----------|-------|--------|
| 1.1.1 | New card + `good`/`hard`/`again` → `learning`, ~1 day | U | ✅ |
| 1.1.2 | New card + `easy` → `review` directly, multi-day interval | U | ✅ |
| 1.1.3 | `learning` + `good`/`easy` → `review`; interval from stability | U | ✅ |
| 1.1.4 | `review` + `again` → `relearning`, `lapses` incremented by 1 | U | ✅ |
| 1.1.5 | `review` + `good`/`easy` → stays `review`, no lapse, interval lengthens | U | ✅ |
| 1.1.6 | `relearning` + `good`/`easy` → `review` | U | ✅ |
| 1.1.7 | Difficulty stays clamped to `[1.0, 10.0]` across many ratings | U | ✅ |
| 1.1.8 | `reps` increments on every schedule call | U | ✅ |
| 1.1.9 | Retrievability `R(t) = (1 + factor·t/S)^decay` at t=0 is 1.0, decays monotonically | U | ✅ |
| 1.1.10 | Worked sequence good→good→easy yields ~1d, ~2d, then a large (~25d) jump (easy bonus) | U | 🆕 if not present |
| 1.1.11 | `nextInterval` never returns < 1 day (min-1 clamp) | U | 🆕 if not present |
| 1.1.12 | `nextReview` == `now + scheduledDays` (date arithmetic, no off-by-one) | U | 🆕 if not present |

### 1.2 Answer validation — `core/utils/answer_validator.dart`
Covered by `answer_validator_test.dart` (13 tests). Korean particle/jamo paths
are the highest-value additions.

| # | Behaviour | Layer | Status |
|---|-----------|-------|--------|
| 1.2.1 | Empty / whitespace input → `incorrect` | U | ✅ |
| 1.2.2 | Exact match (case-insensitive) → `exact`, score ≈ 1.0 | U | ✅ |
| 1.2.3 | French accents normalised (é vs e) still matches | U | ✅ |
| 1.2.4 | Multiple accepted answers — matches any one | U | ✅ |
| 1.2.5 | Typing threshold stricter than driving/voice threshold (same near-miss: typo in typing, acceptable in voice) | U | ✅ |
| 1.2.6 | Korean exact Hangul match → correct | U | ✅ |
| 1.2.7 | Korean single-jamo typo (간 vs 칸) scored via jamo path, classified `typo` not `incorrect` | U | 🆕 |
| 1.2.8 | Korean trailing particle stripped (답을 → 답) still matches | U | 🆕 |
| 1.2.9 | Expected word is a **prefix** of a longer STT transcript → accepted | U | 🆕 |
| 1.2.10 | Extra STT words → word-by-word fallback finds the match | U | 🆕 |
| 1.2.11 | Result `type` boundaries: exact ≥0.98, typo band, acceptable band, incorrect below threshold | U | 🆕 |

### 1.3 Hangul decomposer — `core/utils/hangul_decomposer.dart`
Covered by `core/hangul_decomposer_test.dart` (14 tests): syllable→jamo with/without
jongseong, boundaries U+AC00/U+D7A3, `containsHangul`. ✅ — no gaps identified.

### 1.4 SubmitAnswerUseCase — `domain/usecases/quiz/submit_answer_usecase.dart`
Covered by `quiz/submit_answer_usecase_test.dart` (11 tests).

| # | Behaviour | Layer | Status |
|---|-----------|-------|--------|
| 1.4.1 | `timesShown` +1 every submit | U | ✅ |
| 1.4.2 | `timesCorrect` +1 only when `rating != again` | U | ✅ |
| 1.4.3 | `masteryLevel = timesCorrect / timesShown` recomputed | U | ✅ |
| 1.4.4 | Delegates to `AppFsrs.schedule` (FSRS fields written through) | U | ✅ |
| 1.4.5 | `isSynced` reset to false after the update | U | ✅ |
| 1.4.6 | `isCorrect` is derived as `rating != again` (only `again` counts as wrong) | U | 🆕 if not asserted |

### 1.5 SignUpUseCase validation — `domain/usecases/auth/sign_up_usecase.dart`
Covered by `auth/sign_up_usecase_test.dart` + `auth/sign_up_duplicate_test.dart`.

| # | Behaviour | Layer | Status |
|---|-----------|-------|--------|
| 1.5.1 | Username < 3 chars → `ValidationException` | U | ✅ |
| 1.5.2 | Username with disallowed chars (space, accent, hyphen) → rejected; `[a-zA-Z0-9_]` only | U | ✅ |
| 1.5.3 | Username normalised (trim + lowercase) before delegate | U | ✅ |
| 1.5.4 | Duplicate username / email pre-check → failure | U | ✅ |
| 1.5.5 | Username > 32 chars → rejected (upper bound) | U | 🆕 if not present |

### 1.6 Mastery rule — `domain/entities/variant_progress.dart`
The `isMastered` extension: `state == review && scheduledDays >= 21`. Worth a
tiny dedicated table since Stats + summary depend on it.

| # | Behaviour | Layer | Status |
|---|-----------|-------|--------|
| 1.6.1 | `review` + `scheduledDays == 21` → mastered (boundary, inclusive) | U | 🆕 |
| 1.6.2 | `review` + `scheduledDays == 20` → not mastered | U | 🆕 |
| 1.6.3 | `learning`/`relearning`/`newCard` with `scheduledDays >= 21` → not mastered (state gate) | U | 🆕 |

### 1.7 SubscriptionType — `domain/entities` enum
Covered by `domain/subscription_type_test.dart` (8 tests): `hasAccess` for
free/student/premium, `displayLabel`, `fromString`. ✅

### 1.8 QuizSession.accuracy getter — `domain/entities/quiz_session.dart`

| # | Behaviour | Layer | Status |
|---|-----------|-------|--------|
| 1.8.1 | `accuracy = correctCount / cardCount` as a percent; 0 cards → 0 (no divide-by-zero) | U | 🆕 |
| 1.8.2 | Rounding matches what the summary screen shows (e.g. 2/3 → 67%) | U | 🆕 |

### 1.9–1.11 Supporting utilities
- `string_ext` (accents, isKorean/isFrench, language detection) — `core/string_ext_test.dart` ✅
- `Result<T>` sealed type (isSuccess/Failure, valueOrNull, fold) — `core/result_test.dart` ✅
- `VariantProgressDto.toRemoteMap()` snake_case + enum + nullable dates — `data/variant_progress_dto_test.dart` ✅
- **Import/export JSON shape** (list + concepts + variants serialise, enums as expected keys) — **U** 🆕 (see also 2.7 for the repo roundtrip)

---

## 2. Data & persistence — integration tests (`test/integration/`)

Real in-memory drift DB + a `_FakeRemote` returning `Success`. Prove
save-then-read-back, streams, soft-delete, no-cascade. Timestamp assertions need
a **>1s** wait (second-precision column).

### 2.1 Vocabulary list repository — `vocabulary_repository_test.dart`, `vocabulary_list_test.dart`

| # | Behaviour | Layer | Status |
|---|-----------|-------|--------|
| 2.1.1 | Create → read back; `watchMyLists` emits it | I | ✅ |
| 2.1.2 | Update name bumps `updatedAt`; reorders `watchMyLists` (DESC by updatedAt) | I | ✅ |
| 2.1.3 | Delete is **soft** (`isDeleted=true` in raw row); disappears from stream | I | ✅ |
| 2.1.4 | `wordCount` reflects concepts added/removed | I | ✅ |
| 2.1.5 | Deleting a list does **not** cascade-delete its concepts (rows remain) | I | ✅ |

### 2.2 Concept + variant repository — `concept_variant_test.dart`

| # | Behaviour | Layer | Status |
|---|-----------|-------|--------|
| 2.2.1 | `addConceptWithVariants` inserts concept + 2 variants atomically | I | ✅ |
| 2.2.2 | Variant `langCode` is fr/ko; one per language | I | ✅ |
| 2.2.3 | Update / soft-delete concept; variants not cascade-deleted | I | ✅ |
| 2.2.4 | `watchConcepts(listId)` emits live updates | I | ✅ |
| 2.2.5 | Owning list `wordCount` tracks concept add/delete | I | ✅ |

### 2.3 Progress repository — `progress_repository_test.dart` (26 tests)

| # | Behaviour | Layer | Status |
|---|-----------|-------|--------|
| 2.3.1 | `getProgress` returns sensible defaults for an unseen variant | I | ✅ |
| 2.3.2 | `updateProgress` persists FSRS fields; resets `isSynced` | I | ✅ |
| 2.3.3 | `getDueCards`: new cards (no progress row) selected up to limit | I | ✅ |
| 2.3.4 | `getDueCards`: due cards (`nextReview <= now`) selected | I | ✅ |
| 2.3.5 | `getDueCards`: future-scheduled cards excluded from due **and** not treated as new | I | ✅ |
| 2.3.6 | `getDueCards`: early-review fallback returns scheduled cards when nothing due/new (never an empty quiz) | I | ✅ |
| 2.3.7 | `watchDueCount` emits the count and updates after a submit | I | ✅ |
| 2.3.8 | FR→KO and KO→FR progress rows are **isolated** (one direction’s answer doesn’t move the other) | I | ✅ |
| 2.3.9 | **New-cards-per-day cap = 10 (free)**: `getDueCards` introduces ≤10 brand-new cards in a day | I | 🆕 (verify the cap lives in repo/usecase, else move to U on the usecase) |
| 2.3.10 | `getMasteredVariants` returns only `state==review && scheduledDays>=21` rows | I | 🆕 |

### 2.4 Sync queue & isSynced — `sync_queue` table + remote datasource

| # | Behaviour | Layer | Status |
|---|-----------|-------|--------|
| 2.4.1 | A local create/update/delete enqueues a `sync_queue` row (tableName, rowId, operation, payload) | I | 🆕 |
| 2.4.2 | After a successful remote push (fake remote returns Success) the entity flips `isSynced=true` and the queue row is consumed | I | 🆕 |
| 2.4.3 | Remote failure → `retryCount` increments, entity stays `isSynced=false`, queue row retained | I | 🆕 |

### 2.5 Import / export / share — `import_export_usecase.dart`, repo

| # | Behaviour | Layer | Status |
|---|-----------|-------|--------|
| 2.5.1 | Export a list → JSON; import that JSON into a fresh list → identical concepts/variants (roundtrip) | I | 🆕 |
| 2.5.2 | `generateShareLink` produces a `shareToken`; `importFromShareToken` reconstructs the list (against fake remote) | I | 🆕 |
| 2.5.3 | Importing assigns new local ids / new ownerId (no id collision with source) | I | 🆕 |

---

## 3. Widget tests (`test/widget/`)

One widget renders/behaves right. Drive animated widgets with `isAnimating:false`
for deterministic rest states. Find by key/type/icon, read rendered properties.

| # | Widget / behaviour | Layer | Status |
|---|--------------------|-------|--------|
| 3.1 | Feedback flood — correct=teal, wrong=orange, Continue button present | W | ✅ `study_feedback_flood_test.dart` |
| 3.2 | Waveform — listening-state animation renders | W | ✅ `vk_waveform_test.dart` |
| 3.3 | **Scheduling-feedback label** maps an interval to copy: 1d→“Demain”, n→“dans n jours”, soon→“Réviser bientôt” | W | 🆕 |
| 3.4 | **Quiz summary** renders accuracy `%`, correct/total, and restart/home actions from a given `QuizSession` | W | 🆕 |
| 3.5 | **Start-session count chips** render 10/20/50/100 with 20 pre-selected (default) | W | 🆕 |
| 3.6 | **Direction tiles** default to FR→KO selected | W | 🆕 |
| 3.7 | **Offline banner** shows when connectivity provider reports offline, hides when online | W | 🆕 |
| 3.8 | **Home “to review” card** shows the due count from the provider; empty/zero state | W | 🆕 |
| 3.9 | **Streak card** renders current streak; zero-streak state | W | 🆕 |
| 3.10 | **Paywall** lists premium features and both purchase buttons (annual highlighted) | W | 🆕 |
| 3.11 | **Answer-audio policy** — given a mode, the quiz view requests TTS per the rule in 4.3.x (Typing/Voice always, Hands-free only-when-wrong, Flashcard never): assert the audio callback is/ isn’t invoked | W | 🆕 |

---

## 4. E2E journeys — Patrol (`patrol_test/`)

Reserve for true cross-screen journeys. **Body = only `given/when/then` Steps
calls; select by keys.** Always `addTearDown(deleteListsByName(...))`. Keep card
counts small (`TEST_CARD_LIMIT`). New scenario files must be imported by
`patrol_test/quiz_all_test.dart`.

### 4.0 Navigation graph — `navigation_test.dart` ⚠️ BLOCKED (written, not in CI)
The screen-reachability backbone: every signed-in destination must open and
render. Assertions use **screen-root keys** (`WidgetKeys.screen*`), never text.

> **Blocked by a test-binding limitation.** Tapping into Social/Profile/Stats
> performs GoRouter navigation that triggers *"mid-layout Scaffold animation"*
> assertions in Flutter's integration-test binding (the same issue
> [`auth_test.dart`](../patrol_test/auth_test.dart) documents) — it aborts the
> whole run (CI run #3: the 11 quiz tests passed, then the first nav test crashed
> the process with `Gradle code 1`, 0 failures). The file stays in the repo but
> is **excluded from the `quiz_all_test` umbrella**. Unblocking it needs an app
> change: the study/social screen animations (waveform, pulse, `TabController`)
> must freeze when `MediaQuery.disableAnimations` is true (CI sets this). That
> same fix would also remove the ~10 s-per-action settle cost (see §2.9 follow-ups
> in the how-to). Until then, screen presence is partially covered by the quiz +
> user-flow journeys.

| # | Scenario | Reaches | Status |
|---|----------|---------|--------|
| 4.0.1 | Bottom-nav tabs open Home / Lists / Social / Profile | home, lists, social, profile | ✅ |
| 4.0.2 | Raised Study button opens Start-a-session | startSession | ✅ |
| 4.0.3 | Home header bell opens Notification settings | notifications | ✅ |
| 4.0.4 | Profile tiles open Stats / Settings / Notifications | stats, settings, notifications | ✅ |
| 4.0.5 | Tapping a list opens its detail | listDetail | ✅ |
| 4.0.6 | Sign-out tile returns to Welcome | — | 🔧 `then.onWelcome()` (key `profileSignOut` now exists) |
| 4.0.7 | Paywall reachable (via freemium trigger or upgrade tile) | paywall | 🔧 see 4.4 (key `screenPaywall` exists) |
| 4.0.8 | Import screen reachable via `vocabkr://import?token=…` | importLink | 🔧 see 4.8 (key `screenImport` exists) |
| 4.0.9 | Android system **back** button pops a pushed screen correctly | — | 🔧 `when.goesBack()` via `$.native.pressBack()` |

> Infra added for this net: nav-tab keys (`WidgetKeys.navTab`), a screen-root key
> on every screen's Scaffold (`WidgetKeys.screen*`), the Home bell + Profile tile
> keys, and steps `when.tapsNavTab` / `when.opensProfileTile` /
> `when.opensNotificationsFromBell` / `when.opensList` / `then.onScreen`. Paywall
> and Import screens are keyed (`screenPaywall`, `screenImport`) but reached only
> once their trigger scenarios (4.4 / 4.8) exist.

### 4.1 Auth — `auth_test.dart`, `sign_up_test.dart`

| # | Scenario (one-line behaviour) | Status |
|---|-------------------------------|--------|
| 4.1.1 | Sign in → lands on Today/home | ✅ |
| 4.1.2 | Profile data loaded after sign-in | ✅ |
| 4.1.3 | Sign-up duplicate email → inline error | ✅ |
| 4.1.4 | Sign-up duplicate username → inline error | ✅ |
| 4.1.5 | Sign-up invalid username (too short / bad chars) → inline validation error, no account | 🔧 `when.submitsSignUp(...)`, `then.signUpErrorShown()` + keys on auth fields |
| 4.1.6 | Sign out from Profile → returns to Welcome | 🔧 `when.signsOut()`, `then.onWelcome()` |

### 4.2 List & word management

> ⚠️ **`vocab_list_test.dart` is stale and NOT in CI** (only `quiz_all_test` runs).
> It drives the UI by French text + positional `TextField` finders, and it never
> enters edit mode — but the current List-Detail UI only shows the edit/delete
> icons in edit mode, so its edit/delete cases would fail today. The keyed,
> CI-run replacement is the UI-driven steps + the §4.9 user-flow journey.

| # | Scenario | Status |
|---|----------|--------|
| 4.2.1 | Create list via FAB + dialog → appears in Lists | ✅ §4.9 (keyed, in CI) |
| 4.2.2 | Add word via dialog → visible in List Detail | ✅ §4.9 |
| 4.2.3 | Word count reflected in list view | 🆕 (`then.seesText('2 mots')` — easy add) |
| 4.2.4 | Edit a word (enter edit mode → pre-populated dialog → save) | ✅ §4.9 |
| 4.2.5 | Delete a word (edit mode → trash + confirm) | ✅ §4.9 |
| 4.2.6 | Cancel delete leaves the word | 🆕 (add `when.cancelsWordDelete()` — key the dialog Cancel) |
| 4.2.7 | **Rename list** via per-list menu → new name shown | 🔧 `when.renamesList(old,new)` + keys on list-card menu (`listNameField/Confirm` already exist for the dialog) |
| 4.2.8 | **Add a second word** (multi-concept, not just one-word) | ✅ §4.9 (journey adds two words) |
| 4.2.9 | **Export list** → share/export sheet appears | 🔧 `when.exportsList()`, key on export action |

### 4.3 Quiz modes — `quiz_test.dart` (the main event)
Happy/sad paths per mode are covered. Gaps are: the **KO→FR direction**, **mixed
accuracy**, and **per-card verdict** assertions.

| # | Scenario | Status |
|---|----------|--------|
| 4.3.1 | Voice — all correct → 100% | ✅ |
| 4.3.2 | Voice — all wrong → 0% | ✅ |
| 4.3.3 | Hands-free — auto-answer correct → 100% | ✅ |
| 4.3.4 | Flashcard — all “Je savais” → 100% | ✅ |
| 4.3.5 | Flashcard — all “À revoir” → 0% | ✅ |
| 4.3.6 | Typing — correct typed answer → 100% | ✅ |
| 4.3.7 | Typing — wrong typed answer → 0% | ✅ |
| 4.3.8 | **Per-card verdict** — a correct typed answer flashes teal (`then.verdictIsCorrect()`). Proven via typing because its flood is manual (persists); voice/hands-free auto-advance. | ✅ |
| 4.3.9 | **Per-card verdict** — a wrong typed answer flashes orange (`then.verdictIsWrong()`) | ✅ |
| 4.3.10 | **KO→FR direction** — typing the French answer → 100% (`when.choosesDirection(Dir.koToFr)`) | ✅ |
| 4.3.11 | **Mixed accuracy** — 1 of 2 correct → 50% (proves the summary maths end-to-end, complements 1.8) | 🔧 needs a 2-word seed + per-card scripted outcomes (`given.aListWithWords`, alternating STT) |
| 4.3.12 | **Voice “Clavier” fallback** — tap keyboard toggle, type the answer instead of speaking → counts as answered | 🔧 `when.switchesToKeyboardInVoice()`, `when.typesCurrentAnswer(word)` (keys `voiceKeyboard`, `ecrireInput` exist) |
| 4.3.13 | **Hands-free skip/repeat** — `hfSkip` advances a card; `hfRepeat` re-plays/re-listens | 🔧 `when.skipsHandsFreeCard()`, `when.repeatsHandsFreeCard()` (keys `hfSkip`/`hfRepeat` exist) |
| 4.3.14 | **Card count selection** — choosing 10 drives a 10-card session that completes at 100% (`when.choosesCardCount` overrides `TEST_CARD_LIMIT`) | ✅ |

> Real-STT timeout/retry/“pas entendu” behaviour is **🖐️ device-only** — leave
> the simulator off, don’t write CI scenarios (per how-to §2.4).
>
> **Intentionally deferred (CI-unfriendly):** 4.3.11 mixed-accuracy and 4.3.13
> hands-free skip/repeat need per-card outcome control the global STT simulator
> can’t give deterministically (hands-free also auto-advances too fast to tap
> reliably) — mixed-accuracy maths is proven at the unit layer (1.8) instead.
> 4.3.12 voice “Clavier” fallback needs a new widget key on the
> `_VoiceKeyboardInput` field before it can be driven.

### 4.4 Freemium → paywall — new file `paywall_test.dart`

| # | Scenario | Status |
|---|----------|--------|
| 4.4.1 | Free user creates a **4th list** → Paywall appears | 🔧 `given.freeUserWith(nLists)` seed, `then.paywallShown()`, key `summary`-style key on paywall scaffold |
| 4.4.2 | Free user adds a **51st word** to a list → Paywall appears | 🔧 same `then.paywallShown()` |
| 4.4.3 | Paywall shows premium feature list + annual/monthly buttons | 🔧 (or cover at widget layer 3.10 instead — prefer widget) |

> Actual purchase (RevenueCat) is **🖐️ device-only**.

### 4.5 Settings & notifications — new file `settings_test.dart`

| # | Scenario | Status |
|---|----------|--------|
| 4.5.1 | Change theme Light→Dark persists across navigation | 🔧 `when.opensSettings()`, `when.choosesTheme(Theme.dark)`, `then.themeIs(dark)` + keys |
| 4.5.2 | Change UI language (locale) updates visible copy | 🔧 keys on language picker; prefer asserting a keyed label changes |
| 4.5.3 | Notification daily-reminder toggle on → time picker enabled | 🔧 `when.opensNotificationSettings()`, keys on toggles |

> Sending a real OS notification / permission prompts are **🖐️ device-only**.

### 4.6 Stats after a session — new file `stats_test.dart`

| # | Scenario | Status |
|---|----------|--------|
| 4.6.1 | Complete a quiz, open Stats → session count incremented, latest session row shows the mode + accuracy just achieved | 🔧 `when.opensStats()`, `then.statsShowRecentSession(mode, percent)` + keys on stats chips/rows |

### 4.7 Social — new file `social_test.dart` (lower priority; feature partly scaffolded)

| # | Scenario | Status |
|---|----------|--------|
| 4.7.1 | Friends tab renders; add-friend search dialog opens | 🔧 keys on social tabs/dialog |
| 4.7.2 | Leaderboard tab switches Week/Month/All-time; current user highlighted | 🔧 keys on period tabs |

> Friend accept/challenge flows need a second account / server fixtures — treat
> as 🖐️ or integration-against-fake-remote rather than CI E2E.

### 4.8 Import a shared list — new file `import_test.dart`

| # | Scenario | Status |
|---|----------|--------|
| 4.8.1 | Open `vocabkr://import?token=…` (seed a known token via fake remote) → Import screen → list added and visible in Lists | 🔧 deep-link launch helper + `then.listExists(name)` |

### 4.9 End-to-end user flows — `user_flows_test.dart` ✅ IMPLEMENTED
Full journeys driven **entirely through the real UI** (no provider seeding),
the way a learner actually uses the app. All selectors are widget keys.

| # | Flow | Status |
|---|------|--------|
| 4.9.1 | **Headline journey**: connect → create a list (FAB + dialog) → add two words → edit one (enter edit mode → dialog) → delete the other (trash + confirm) → leave the list → start a quiz choosing a value in **every** start-session section (type · list · mode · direction · count) → answer → 100% | ✅ |
| 4.9.2 | **Build-then-study**: connect → create a list → add a word → start a flashcard session → grade "known" → 100% (UI-built data flows straight into study) | ✅ |

> Infra added: keys on the create/rename dialog (`listsFab`, `listNameField/Confirm`),
> the List-Detail add bar / ⋮ menu / edit-mode item / back, the add & edit word
> dialogs (`addWord*` / `editWord*`), per-word edit/delete icons keyed by French
> word (`conceptEditIcon`/`conceptDeleteIcon`), the delete-confirm, and the
> start-session **Type** section header + Vocabulaire tile (`startSection`/`startType`).
> Steps: `given.aCleanSlate` (deletes **all** lists via the data layer so the
> free-plan quota is empty before a UI create) / `given.noListNamed`;
> `when.createsList` / `addsWord` / `entersEditMode` / `editsWord` / `deletesWord`
> / `leavesListDetail` / `choosesSessionType`; `then.seesText` / `doesNotSeeText`.
> These unlock most of §4.2 as keyed CI tests.

---

## 5. Cross-cutting / device-only (🖐️ — not CI)

Document these so they’re consciously verified by hand on a device, not silently
assumed:

- Real on-device **STT**: Samsung late-final-result (~2.5s wait), audio-focus retry (max 2), empty-result→wrong, permanent-error snackbar.
- Real **TTS** answer audio: Typing/Voice always play; Hands-free plays only when wrong; Flashcard plays nothing.
- **Microphone permission** grant/deny paths.
- **RevenueCat** purchase, restore-purchases, entitlement unlock.
- **Push notifications**: daily reminder fires at chosen time; streak-protection warning; test-notification button.
- **Offline → online sync**: go offline (offline banner shows), make edits, come back online, edits push and `isSynced` clears. (The queue mechanics themselves are CI-testable — see 2.4.)
- **OAuth** (Google/Apple) and **password reset** email flows.

---

## 6. Priority order (suggested)

1. **Korean validation edges** (1.2.7–1.2.11) — highest-risk pure logic, cheapest layer.
2. **FSRS interval/date correctness** (1.1.10–1.1.12) and **mastery boundary** (1.6) — Stats/summary depend on them.
3. **Sync queue** (2.4) and **import/export roundtrip** (2.5) — currently untested data paths.
4. **Per-card verdict + KO→FR + mixed-accuracy E2E** (4.3.8–4.3.11) — small, mostly-existing vocabulary.
5. **Freemium → paywall** (4.4) — a core monetization gate with zero coverage.
6. Summary/scheduling **widget** tests (3.3–3.4) — fast, protect the numbers users see.
7. Settings / Stats / Import / Social E2E (4.5–4.8) — broader journeys, more new steps.

---

## 7. New steps, keys & helpers to add (consolidated)

Per how-to §2.6, **add to the shared library, never inline**. Each new selector
is a `WidgetKeys` constant wired into the widget on both sides.

**New `given` (seed via provider layer + pair with teardown):**
- `given.aListWithWords({name, pairs})` — multi-word seed (enables 4.2.8, 4.3.11).
- `given.freeUserWith({lists, wordsInList})` — pre-fill to a freemium boundary (4.4).
- `given.aSharedListExists({name, token})` — seed a share token on the fake remote (4.8).

**New `when`:**
- `when.choosesDirection(Dir d)` — key `startDirection` already exists (4.3.10).
- `when.choosesCardCount(int n)` — key `startCount` already exists (4.3.14).
- `when.switchesToKeyboardInVoice()` / `when.typesCurrentAnswer(word)` — keys `voiceKeyboard`, `ecrireInput` exist (4.3.12).
- `when.skipsHandsFreeCard()` / `when.repeatsHandsFreeCard()` — keys `hfSkip`, `hfRepeat` exist (4.3.13).
- `when.renamesList(old, new)` / `when.exportsList()` — need rename/export menu keys (4.2.7/4.2.9).
- `when.signsOut()` — needs a key on the Profile sign-out tile (4.1.6).
- `when.submitsSignUp({email, username, password})` — keys on auth fields (4.1.5).
- `when.opensSettings()` / `when.choosesTheme()` / `when.opensNotificationSettings()` (4.5).
- `when.opensStats()` (4.6); `when.opensSocial()` (4.7).

**New `then`:**
- `then.verdictIsCorrect()` / `then.verdictIsWrong()` — **already exist**, just unused in scenarios (4.3.8/4.3.9).
- `then.paywallShown()` (4.4); `then.onWelcome()` (4.1.6); `then.signUpErrorShown()` (4.1.5).
- `then.listExists(name)` (4.8); `then.statsShowRecentSession(mode, percent)` (4.6); `then.themeIs(...)` (4.5).

**New `WidgetKeys` constants needed:**
`paywallRoot`, profile `signOut`, list-menu `rename`/`export`, auth `emailField`/`usernameField`/`passwordField`/`submit`, settings `themeOption(...)`/`localeOption(...)`, notification `dailyToggle`/`streakToggle`, stats `sessionRow`/summary chips, social `tabFriends`/`tabLeaderboard`/`periodTab(...)`.

**Build defines already available** (how-to §2.5): `TEST_EMAIL`, `TEST_PASSWORD`,
`SIMULATE_SPEECH`, `TEST_LOCALE=fr`, `TEST_MODE`, `TEST_CARD_LIMIT`. A freemium
E2E may want a **second test account** that is on the free tier (today’s account
state must be reset between runs) — note this when implementing 4.4.

---

## 8. Checklist when adding any scenario from this catalogue

- [ ] Lowest sufficient layer chosen (don’t re-prove logic in E2E).
- [ ] E2E body is only `given/when/then`; selectors are keys, not text.
- [ ] New step is single-purpose, sentence-named, in `steps.dart`.
- [ ] New selector is a `WidgetKeys` constant wired into the widget.
- [ ] Seeded data torn down with `addTearDown`.
- [ ] One-line comment states the behaviour proven.
- [ ] New E2E file imported by `quiz_all_test.dart`.
- [ ] `flutter analyze` clean; host tests pass with `LD_LIBRARY_PATH="$HOME/.local/lib:…"`.
- [ ] Row checked off here (✅) with the test file name.
