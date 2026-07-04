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
| Rename list | ✅ | integration + widget (tile menu → dialog → tile updates) |
| Delete list (soft-delete, no cascade) | ✅ | integration + widget (menu → confirm → tile gone) |
| Add / edit / delete word | ✅ | widget `list_detail` (edit = the variantsProvider-staleness regression pin) + integration + E2E |
| Word-count bookkeeping | ✅ | integration `concept_variant_test` |
| Free quota: 3 lists → paywall | ✅ | integration `paywall_gate` + widget (UI path → /paywall, nothing created) |
| Free quota: 50 words/list | ✅ | integration gate + widget (add-word dialog → /paywall, word not added) |

## 3. Study (the core loop)

| Behavior | Status | Verified by |
|---|---|---|
| Session setup (list/mode/direction/count accordion) | ✅ | widget `start_session` (args captured exactly) + E2E |
| Smart lists ("À réviser maintenant" / "En cours") + cross-list queries | ✅ | integration `smart_lists_test` (due vs future vs new vs deleted semantics, use-case routing) + widget (tile → allDue/inProgress args, CTA without a list) |
| Home "À réviser" one-tap → all-due session | ✅ | widget (card CTA → /quiz with allDue args, no accordion) |
| Session assembly (both-directions interleave, cap, padding, drop rule, failure policy) | ✅ | unit `session_assembly` + provider `quiz_load_cards` |
| Flashcard: flip, self-grade, FSRS persisted | ✅ | widget `quiz_screen` + E2E `Cartes ×2` |
| Typing: verdicts, KO→FR direction, card-count 10 | ✅ | widget + unit `answer_validator` + E2E `Écrire ×6` |
| Voice mode | ⚠️ | E2E via the STT **simulator** (deterministic). 📵 real microphone recognition |
| Hands-free mode (auto-advance, earcon/haptic, STT retry/failsafe timers) | ⚠️ | E2E via simulator. The Samsung-STT retry/failsafe logic in quiz_screen is 📵 (device timing) |
| Answer validation (accents, typos, Korean particles, multi-word STT) | ✅ | unit, 100% file coverage |
| FSRS scheduling (state machine, intervals, lapses) | ✅ | unit |
| Session summary (score) | ✅ | E2E asserts 100%/0% scores; widget renders it |
| Session history recording (`_recordSession` → quiz_sessions table) | ✅ | integration `quiz_session_history_test`: full 1-card session → row (name/mode/score/mastered) → quizHistoryProvider maps it back |
| In-app review prompt (5th session) | 📵 | native plugin, try/caught |

## 4. Stats & progression

| Behavior | Status | Verified by |
|---|---|---|
| Streak day-boundary rules (same-day, +1, reset) | ✅ | unit `streak_test` |
| Streak display (home card, profile) | ✅ | widget |
| Mastery rule (review + ≥21 days) | ✅ | unit |
| History list + mastered-over-time chart render | ✅ | widget (render) + integration (DAO write→read + mapping via the session-history test) |
| Per-list stats (total/mastered/due) + reset progress | ✅ | integration `list_stats_test` (mastery/due semantics, cross-list isolation, reset) — implemented 2026-07-04, no longer stubs. Includes the pure `isListKnown` grammar-prerequisite gate |

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
| Deep-link import UI (`vocabkr://import` → import_from_link_screen) | ✅ | widget: valid token imports + opens the list; unknown token → not-found + /lists fallback. Only the OS-intent → route wiring remains untestable (📵, no Patrol intent API) |
| Share sheet / file picker | 📵 | share_plus / file_picker plugins |

## 7. Offline

| Behavior | Status | Verified by |
|---|---|---|
| Offline detection rule (multi-transport) | ✅ | unit |
| Local-first writes survive dead backend | ✅ | integration `offline_resilience` |
| Pull sync (lists/concepts/variants land, idempotent, no clobber) | ✅ | integration `sync_from_remote` |
| Offline banner UI (app_shell) | ✅ | widget: banner appears offline / absent online, content stays usable. Found+fixed: the banner text overflowed EVERY phone by 468px |
| Push-sync retry queue | 🚧 | sync_queue stub |

## 8. Settings

| Behavior | Status | Verified by |
|---|---|---|
| Theme switching (persist + restore) | ✅ | unit + widget |
| Every screen renders correctly in BOTH themes | ✅ | `theme_sweep_test`: 14 screens × light/dark under the real AppTheme — fails on per-theme layout errors or a scaffold background that ignores the theme. Found+fixed: app_shell forced light paper in dark mode |
| Audio prefs (rate/pitch) | ✅ | unit + widget |
| Language picker | ⚠️ | dialog opens; actual locale switch is EasyLocalization-coupled (can't re-init in tests — documented) |
| Subscription row (free vs premium, upgrade → paywall) | ✅ | widget |

## 9. Social

| Behavior | Status | Verified by |
|---|---|---|
| Friends list renders | ✅ | widget with fake repo |
| Accept friend request | ✅ | widget → repo call asserted |
| Send / decline / remove friend, user search | ✅ | widget: decline & remove (with confirm) hit the repo; search dialog → results → add sends the request |
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
| isPremium fallback (RevenueCat OR Supabase-granted) | ✅ | unit: entitlement wins, student tier wins, neither → false (real CustomerInfo.fromJson) |

## 11. Navigation & shell

| Behavior | Status | Verified by |
|---|---|---|
| Bottom tabs, list→detail, bell, profile tiles, study button | ✅ | E2E `navigation` (5) + per-screen widget nav stubs |
| App shell (nav bar rendering, offline banner) | ✅ | widget: tabs + study button route; banner per §7. Found+fixed: nav labels overflowed the bar at large text scales |
| Legacy patrol files (`auth_test`, `sign_up_test`, `vocab_list_test`) | ⚠️ | exist but NOT in the E2E gate — superseded by auth_flows/user_flows; delete or fold in |

---

## The honest per-feature summary (updated after the gap-closing pass)

**~92% of CI-testable behaviors are now verified** (49 of ~53; was ~74%
when this document was first written). All five ranked gaps were closed the
same day — see the ✅ rows above.

- **Remaining ⚠️ (each an accepted trade-off, not an oversight):** sign-up has
  no E2E (real account creation pollutes Supabase), voice/hands-free run E2E
  only through the STT simulator, language switching is EasyLocalization-
  coupled (can't re-init in a test process).
- **Untestable in CI by nature (verify manually at release):** real microphone
  STT, TTS audio output, notification delivery, RevenueCat purchases, share
  sheet/file picker, password-reset email delivery, OS deep-link intent
  routing.
- **Stubs awaiting implementation (test with the feature):** challenges, sync queue.
- Housekeeping: legacy patrol files (`auth_test`, `sign_up_test`,
  `vocab_list_test`) are not in the gate — fold in or delete (owner call).
