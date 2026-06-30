# Test-feasibility study — the untested areas

> **Question:** for the app areas the E2E net doesn't yet cover, what *can* we
> test in CI, what *can't* we, and why? Is the gap a real limitation or just
> not-done-yet?
>
> **Short answer:** most gaps are **not** real limitations — they're testable in
> CI today or behind a small, well-understood *seam* (a provider override, a seed
> helper, lifting a service to a provider, or relaxing a `TEST_MODE` guard). Only
> a narrow set is genuinely **device/manual-only** (real payments, real audio
> out, OS notification firing, OAuth, reset-email delivery, real mic). And a few
> areas "can't be tested" simply because **the feature isn't built yet**.

Legend: 🟢 testable in CI now · 🟡 testable with a small seam · 🔴 device/manual
only (hard limit) · ⚪ feature not implemented yet.

---

## 1. Monetization / Paywall

| Capability | | How / why |
|---|---|---|
| Quota gating (4th list / 51st word → `QuotaExceededException`) | 🟢 | Pure Dart in `vocabulary_provider.dart`; unit + E2E. |
| Paywall screen appears on quota hit | 🟢 | E2E via `WidgetKeys.screenPaywall`. |
| Premium-path behaviour (limits lifted, badge) | 🟡 | Seed Supabase `subscription_type='premium'` **or** override `isPremiumProvider`. |
| Offerings / price display | 🟡 | Override `offeringsProvider` with a fake `Offerings`. |
| **Actual purchase (IAP payment sheet)** | 🔴 | Native StoreKit/Play Billing sheet — not automatable. Test the *success path* by mocking `purchaseServiceProvider`; verify the real charge on a device with a sandbox account. |
| **Restore purchases** | 🔴 | Native receipt validation. Same mock approach for the logic. |

## 2. Settings

| Capability | | How / why |
|---|---|---|
| Theme (light/dark/system) — UI + persistence | 🟢 | `SharedPreferences` + `themeModeProvider`; unit/widget/E2E. |
| Language (7 locales) — switch + persistence | 🟢 | `easy_localization`, pure Dart; `TEST_LOCALE` already wired. |
| Audio speed/pitch — UI + persistence | 🟢 | `audioSettingsProvider` + prefs. |
| Subscription badge (Free/Student/Premium) | 🟢 | Override `currentUserProvider`. |
| **Audio actually plays at the chosen speed** | 🔴 | Real speaker output. |

## 3. Notifications

| Capability | | How / why |
|---|---|---|
| Settings persistence (toggles, time picker) | 🟢 | Prefs + `notificationSettingsProvider`. |
| Scheduling *logic* (next-occurrence calc, skip-when-disabled) | 🟢 | Unit-test against a fake `NotificationService`. |
| Permission request flow | 🟡 | Patrol *can* grant the OS dialog natively (as it does for the mic); assert the result path via a fake service. |
| **OS actually fires the notification at the set time** | 🔴 | No CI API to inspect/trigger scheduled OS notifications; device-only. |

## 4. Social

| Capability | | How / why |
|---|---|---|
| Leaderboard display + "me" highlight | 🟡 | Read-only; seed `profiles.total_words_mastered` for a couple of users. (Note: period pills are UI-only — backend ignores week/month/all-time.) |
| User search, send friend request | 🟡 | Need **one** seeded second user. |
| Accept/decline/remove, view friends/pending | 🟡 | Need a **second account** or SQL-seeded `friend_requests`/`friendships` rows (these only exist if someone else acted). |
| **Challenges** | ⚪ | Stubbed ("coming soon") — nothing to test yet. |

## 5. Stats

| Capability | | How / why |
|---|---|---|
| History list, chips, mastered chart, session tiles | 🟡 | All local (drift, no network). Need seeded `quiz_sessions`. |
| "Complete a quiz → it shows in Stats" | 🟡 | **`_recordSession()` is skipped under `TEST_MODE`** (`quiz_provider.dart`). Relax that guard (keep skipping only streaks/notifs), or add a `seedQuizSession` helper. |

## 6. Auth (beyond current sign-in / sign-up)

| Capability | | How / why |
|---|---|---|
| Sign-out → Welcome | 🟢 | `signOut()` clears state; assert Welcome. |
| Sign-up validation / duplicates | 🟢 | Already covered (unit + E2E). |
| Password reset — form submit & error handling | 🟡 | Flow is testable; **email delivery is not** (🔴). |
| **OAuth (Google/Apple)** | 🔴/⚪ | Native provider flow *and* currently returns "not configured". |
| **Delete account** | ⚪ | Returns "not implemented". |

## 7. Import / Export / Share

| Capability | | How / why |
|---|---|---|
| JSON import/export roundtrip | 🟢 | **Already tested** at the integration layer (`vocabulary_repository_test.dart`). |
| `importFromShareToken` | 🟢 | Integration with a seeded token + `FakeRemote`. |
| Deep-link import (`vocabkr://import?token=`) | 🟡 | Either Patrol's deep-link open, or unit-test `_handleLink()` routing directly. |
| Export's **native share sheet** | 🟡/🔴 | Can't assert the sheet opened; mock `Share.shareXFiles` to verify it was *called* with the right file. |

## 8. Offline / Sync

| Capability | | How / why |
|---|---|---|
| Local-only DB ops (works offline) | 🟢 | **Already covered** — every repo test runs against `FakeRemote` (i.e. offline). |
| Offline banner shows/hides | 🟡 | `_connectivityProvider` is private to `app_shell.dart`; lift it to an overridable provider, then drive it. |
| **`sync_queue` enqueue / push / retry** | ⚪ | The table exists but **there's no sync service** that enqueues/pushes/retries. Nothing to test until it's built. |

## 9. Audio / STT / TTS

| Capability | | How / why |
|---|---|---|
| STT (voice / hands-free) | 🟢 | `SttSimulator` — **already driving the green voice tests**. |
| "Answer audio was requested" (TTS) | 🟡 | Mock `audioPlayerServiceProvider` (provider already exists); assert `speak(word, lang)` was called. |
| Sound-effect cues fired | 🟡 | `SoundEffectsService` is `new`'d directly in `quiz_screen.dart` — lift it to a provider, then spy. |
| ElevenLabs cache hit/miss logic | 🟡 | Integration with `FakeRemote` (no network). |
| **Real audio output / real mic / Whisper-ElevenLabs network** | 🔴 | Hardware + network; device-only. |

---

## The pattern: "test the intent, verify the device on a device"

For everything 🔴, the reliable split is: **assert the app made the right call** (mock the service, verify args) in CI, and **verify the real output** (sound, payment, notification, OAuth) manually on a device. You lose almost nothing in regression protection — the logic is what breaks; the platform plumbing rarely does.

## High-leverage seams to build (unlock most of the 🟡s)

1. **`seedQuizSession()` helper** (like `aListWithOneWord`) → unlocks all of **Stats**.
2. **Premium override** (seed Supabase `subscription_type` or override `isPremiumProvider`) → unlocks paywall premium-path + subscription display.
3. **Fake `Offerings`** via `offeringsProvider` override → paywall price display.
4. **A second seeded test account** (+ a couple SQL-seeded friend rows) → most of **Social**.
5. **Lift `SoundEffectsService` and `_connectivityProvider` to overridable providers** → sound-effect assertions + the offline banner.
6. **Mock `audioPlayerServiceProvider`** (already a provider) → "answer audio requested".
7. **Relax the `TEST_MODE` guard on `_recordSession`** → "quiz completion records a session".
8. **Mock `Share.shareXFiles`** → export flow.

## The genuinely-can't (hard limits — keep manual)

Real IAP purchase & restore · real audio output · OS notification firing · OAuth provider flow · password-reset email delivery · real microphone/on-device STT · exact-alarm firing.

## Not testable because not built yet (build + test together)

Offline **sync service** (`sync_queue` has a schema but no logic) · **Challenges** · **Account deletion** · **OAuth** (returns "not configured").
