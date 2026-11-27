# Feature coverage — what the tests actually verify

> **Current status (2026-09-29).** The tables below began as a 2026-07-03
> inventory and retain useful feature-level detail, but their test counts and
> E2E wording are historical. `TESTS.md` records 746 host tests at the latest
> full local snapshot. The maintained Patrol configuration is the nine-suite
> manual workflow in `.github/workflows/e2e.yml`, not a PR gate.
>
> The V3 slice has widget coverage for home/parcours, daily trail, list detail,
> session setup and quiz behavior. It has no golden/screenshot suite and no
> E2E assertion of visual fidelity across V3 themes/locales. Physical STT,
> audio latency, background behavior and deployed-service behavior remain
> device/external validation.
>
> Line coverage says how much code ran; this document says which
> **user-facing behaviors** are protected against regressions, and by which
> layer.
>
> Legend: ✅ verified · ⚠️ partly verified (what's missing is stated) ·
> ❌ gap (testable, not tested) · 📵 device-only by nature (cannot be verified
> in CI; listed so it's a decision, not an oversight) · 🚧 feature is a stub
> (test it when it's built).

## 1. Authentication

| Behavior | Status | Verified by |
|---|---|---|
| Sign in (success → Home) | ✅ | widget `auth_screen_test` + **live E2E** `auth_login_test` (maintained manual Patrol suite) |
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
| Full session setup for lessons and existing detailed entries | ✅ | widget `start_session` captures arguments and rule/pair; this is not the plateau free-practice entry |
| Plateau free practice: Quoi/Sens/Mode sheet | ✅ | widget `free_practice_sheet`: selected pair/direction/source, empty pools, long preview and keyboard; `localized_free_practice` uses the production locale configuration |
| Smart lists ("À réviser maintenant" / "En cours") + cross-list queries | ✅ | integration `smart_lists_test` (due vs future vs new vs deleted semantics, use-case routing) + widget (tile → allDue/inProgress args, CTA without a list) |
| Active plateau → daily path → due-review mode → quiz | ✅ | widgets `daily_path_screen` / `quiz_screen`, plus provider tests for bidirectional availability and the session cap; the former Home one-tap path is historical |
| Session assembly (both-directions interleave, cap, padding, drop rule, failure policy) | ✅ | unit `session_assembly` + provider `quiz_load_cards` |
| Vocabulary flashcards: flip, self-grade and FSRS good/again (decision 2026-08-08 in `design/map/quiz-canvas.md`) | ✅ | widget `quiz_screen`: both grading controls persist the schedule once. Grammar cards remain practice without grammar mastery writes. E2E `Cartes ×2` checks score/summary. |
| Typing: verdicts, KO→FR direction, card-count 10, controls reachable with a landscape keyboard and enlarged text | ✅ | widget + unit `answer_validator` + E2E `Écrire ×6` |
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
| Daily-reminder & streak-warning scheduling rules | ✅ | unit `notification_schedule`; device time zone and calendar-day rollover across daylight-saving changes |
| Settings screen (toggles persist, cancel/reschedule service calls, time picker) | ✅ | widget with real notifier + recording fake service |
| Daily reminder and streak warning restored on the authenticated route with saved preferences | ✅ | widget with the real app router |
| Actual notification delivery | 📵 | native plugin |

Une annulation invalide une programmation de même identifiant encore en
attente du fuseau. Les commandes envoyées au système sont ordonnées par
identifiant, y compris lorsqu'une annulation globale doit attendre une
programmation déjà transmise.
Le parcours authentifié charge les préférences avant de programmer les
rappels. Le rappel de série est annulé pour une série vide ou une journée
déjà étudiée.

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
| Push-sync drain (offline writes reach the server on reconnect/login) | ✅ | integration `push_sync_test`: offline writes drained + marked synced, idempotent re-drain, per-table failure retries only the failed rows, soft-deletes propagate. The isSynced flags ARE the queue; the dead sync_queue table was dropped (schema v5) |

## 8. Settings

| Behavior | Status | Verified by |
|---|---|---|
| Theme switching (persist + restore) | ✅ | unit + widget |
| Sampled legacy screens mount in both themes | ✅ | `theme_sweep_test` mounts 14 screen fixtures, including the old `HomeScreen`, and checks layout exceptions and the first Scaffold brightness. It does not prove the active V3 plateau's appearance or every element's contrast. V3 has focused contrast/navigation tests; its full visual validation remains open in [the V3 scope](design/v3-sentier-de-cartes.md). |
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
| Five V0 tabs and contextual list/lesson/quiz navigation | ✅ | widgets `app_shell`, `start_session`, import and list detail; Patrol source exists, hosted execution remains pending per PROJECT_STATUS |
| App shell: five equal tabs, keyboard/selection, contrast, offline banner | ✅ | widget `app_shell`: 320px/double text, keyboard route change and both-theme text contrast; no central study button in the active shell |
| Legacy patrol files (`auth_test`, `sign_up_test`, `vocab_list_test`) | ⚠️ | exist but are not in the maintained nine-suite workflow — superseded by auth_flows/user_flows; delete or fold in |

---

## The honest per-feature summary (updated after the gap-closing pass)

**Historical 2026-07-03 estimate: ~92% of CI-testable behaviors were verified** (49 of ~53; was ~74%
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
- **Stubs awaiting implementation (test with the feature):** challenges.
- Housekeeping: legacy patrol files (`auth_test`, `sign_up_test`,
  `vocab_list_test`) are not in the maintained workflow — fold in or delete
  (owner call).
