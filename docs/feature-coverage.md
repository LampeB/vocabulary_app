# Feature coverage — what the tests actually verify

> Per-**feature** assessment (2026-07-03, 392 host tests + 21 E2E tests in the
> gate). Line coverage says how much code ran; this says which **user-facing
> behaviors** are protected against regressions, and by which layer.
>
> Legend: ✅ verified · ⚠️ partly verified (what's missing is stated) ·
> ❌ gap (testable, not tested) · 📵 device-only by nature (cannot be verified
> in CI; listed so it's a decision, not an oversight) · 🚧 feature is a stub
> (test it when it's built).

## 1. Authentication

| Behavior | Status | Verified by |
|---|---|---|
| Sign in (success → Home) | ✅ | widget `auth_screen_test` + **live E2E** `auth_login_test` (in gate) |
| Sign in (bad credentials → inline error) | ✅ | widget |
| Form validation blocks bad input | ✅ | widget + unit `sign_up_usecase_test` |
| Sign up (username + account) | ⚠️ | unit + widget with fake repo. No E2E (creating real accounts each run pollutes Supabase — accepted) |
| Sign out (confirm dialog → Welcome) | ✅ | widget `settings` + E2E `auth_flows` |
| Password reset request | ✅ | widget dialog + E2E (accepts success OR rate-limit). 📵 actual email delivery |
| Session restore on launch | ✅ | unit `auth_notifier_test` (profile preferred over basic user) + reactive sign-out event |

## 2. Lists & words

| Behavior | Status | Verified by |
|---|---|---|
| Create list (dialog → tile → persisted) | ✅ | widget `lists_screen` + integration + E2E `user_flows` |
| Rename list | ⚠️ | integration only — no UI-level test drives the rename dialog |
| Delete list (soft-delete, no cascade) | ⚠️ | integration only — the UI delete flow on lists_screen is untested |
| Add / edit / delete word | ✅ | widget `list_detail` (edit = the variantsProvider-staleness regression pin) + integration + E2E |
| Word-count bookkeeping | ✅ | integration `concept_variant_test` |
| Free quota: 3 lists → paywall | ✅ | integration `paywall_gate` + widget (UI path → /paywall, nothing created) |
| Free quota: 50 words/list | ⚠️ | integration gate only — UI path not driven |

## 3. Study (the core loop)

| Behavior | Status | Verified by |
|---|---|---|
| Session setup (list/mode/direction/count accordion) | ✅ | widget `start_session` (args captured exactly) + E2E |
| Session assembly (both-directions interleave, cap, padding, drop rule, failure policy) | ✅ | unit `session_assembly` + provider `quiz_load_cards` |
| Flashcard: flip, self-grade, FSRS persisted | ✅ | widget `quiz_screen` + E2E `Cartes ×2` |
| Typing: verdicts, KO→FR direction, card-count 10 | ✅ | widget + unit `answer_validator` + E2E `Écrire ×6` |
| Voice mode | ⚠️ | E2E via the STT **simulator** (deterministic). 📵 real microphone recognition |
| Hands-free mode (auto-advance, earcon/haptic, STT retry/failsafe timers) | ⚠️ | E2E via simulator. The Samsung-STT retry/failsafe logic in quiz_screen is 📵 (device timing) |
| Answer validation (accents, typos, Korean particles, multi-word STT) | ✅ | unit, 100% file coverage |
| FSRS scheduling (state machine, intervals, lapses) | ✅ | unit |
| Session summary (score) | ✅ | E2E asserts 100%/0% scores; widget renders it |
| **Session history recording** (`_recordSession` → quiz_sessions table) | ❌ | **nothing** — the stats screen shows history, but nothing verifies a finished session writes it |
| In-app review prompt (5th session) | 📵 | native plugin, try/caught |

## 4. Stats & progression

| Behavior | Status | Verified by |
|---|---|---|
| Streak day-boundary rules (same-day, +1, reset) | ✅ | unit `streak_test` |
| Streak display (home card, profile) | ✅ | widget |
| Mastery rule (review + ≥21 days) | ✅ | unit |
| History list + mastered-over-time chart render | ⚠️ | widget with **canned** providers — the DAO queries and row→session mapping behind them are untested (pairs with the `_recordSession` gap) |
| Per-list stats | 🚧 | `getListStats` stub |

## 5. Notifications

| Behavior | Status | Verified by |
|---|---|---|
| Daily-reminder & streak-warning scheduling rules | ✅ | unit `notification_schedule` |
| Settings screen (toggles persist, cancel/reschedule service calls, time picker) | ✅ | widget with real notifier + recording fake service |
| Streak warning armed from Home when streak > 0 | ✅ | widget |
| Actual notification delivery | 📵 | native plugin |

## 6. Import / export / share

| Behavior | Status | Verified by |
|---|---|---|
| JSON export/import roundtrip (incl. malformed input) | ✅ | integration |
| Share token: generate / import / dedup / not-found | ✅ | integration |
| **Deep-link import UI** (`vocabkr://import` → import_from_link_screen) | ❌ | screen has zero tests; E2E intent-launch impossible (no Patrol API) — but the **screen itself is widget-testable** |
| Share sheet / file picker | 📵 | share_plus / file_picker plugins |

## 7. Offline

| Behavior | Status | Verified by |
|---|---|---|
| Offline detection rule (multi-transport) | ✅ | unit |
| Local-first writes survive dead backend | ✅ | integration `offline_resilience` |
| Pull sync (lists/concepts/variants land, idempotent, no clobber) | ✅ | integration `sync_from_remote` |
| **Offline banner UI** (app_shell) | ❌ | the rule is tested; the shell that shows the banner is not (app_shell has zero tests) |
| Push-sync retry queue | 🚧 | sync_queue stub |

## 8. Settings

| Behavior | Status | Verified by |
|---|---|---|
| Theme switching (persist + restore) | ✅ | unit + widget |
| Audio prefs (rate/pitch) | ✅ | unit + widget |
| Language picker | ⚠️ | dialog opens; actual locale switch is EasyLocalization-coupled (can't re-init in tests — documented) |
| Subscription row (free vs premium, upgrade → paywall) | ✅ | widget |

## 9. Social

| Behavior | Status | Verified by |
|---|---|---|
| Friends list renders | ✅ | widget with fake repo |
| Accept friend request | ✅ | widget → repo call asserted |
| **Send / decline / remove friend, user search** | ❌ | screens+providers exist, untested |
| Leaderboard (ranking, mapping, display) | ✅ | unit `social_mappers` + widget |
| Streak update arithmetic | ✅ | unit |
| Challenges | 🚧 | stub |
| Live Supabase queries (friendship both-directions join etc.) | 📵 | backend-coupled; would need a Supabase test instance |

## 10. Monetization

| Behavior | Status | Verified by |
|---|---|---|
| Tier parsing + hasAccess | ✅ | unit |
| Quota gates (never reach repo when blocked; premium unlimited) | ✅ | integration + widget |
| Paywall screen (features, loading/error/null offerings) | ✅ | widget |
| **Purchase / restore flow (RevenueCat)** | 📵 | requires store sandbox — verify manually before each release |
| isPremium fallback (RevenueCat OR Supabase-granted) | ⚠️ | tier logic unit-tested; the combining provider itself is not |

## 11. Navigation & shell

| Behavior | Status | Verified by |
|---|---|---|
| Bottom tabs, list→detail, bell, profile tiles, study button | ✅ | E2E `navigation` (5) + per-screen widget nav stubs |
| App shell (nav bar rendering, offline banner) | ❌ | see §7 |
| Legacy patrol files (`auth_test`, `sign_up_test`, `vocab_list_test`) | ⚠️ | exist but NOT in the E2E gate — superseded by auth_flows/user_flows; delete or fold in |

---

## The honest per-feature summary

- **Fully protected:** the core loop (lists → words → all 4 study modes →
  FSRS → score), auth, quotas/paywall UI, notifications scheduling, offline
  data safety, import/export logic, theme/audio settings, leaderboard.
- **Real gaps (host-testable, ranked by user impact):**
  1. **Session history recording** — a finished quiz writing its
    `quiz_sessions` row is the bridge between studying and stats, and nothing
    tests it end-to-end.
  2. **Deep-link import screen** — the one user-visible piece of sharing with
    zero tests.
  3. **Offline banner / app_shell** — offline UX is only rule-tested.
  4. **Social send/decline/remove/search** — half the friends feature.
  5. UI paths for rename/delete list and the words-per-list quota.
- **Untestable in CI by nature (accept + verify manually at release):** real
  microphone STT, TTS audio output, notification delivery, RevenueCat
  purchases, share sheet/file picker, password-reset email delivery.
- **Stubs awaiting implementation (test with the feature):** challenges,
  per-list stats, reset progress, sync queue.
