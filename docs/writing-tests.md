# Writing tests in VocabKR

> **Audience:** a developer *or an LLM agent* that turns a feature spec (Notion
> ticket, design doc) + the codebase into runnable tests. This is the *how-to*.
> For the current inventory of what already exists, see [`TESTS.md`](../TESTS.md).
>
> **Golden rule for the generating agent:** produce tests that read like the spec.
> Express behaviour in **given / when / then** steps and **stable widget keys** —
> never localized text, never raw coordinates. If a needed step or key doesn't
> exist yet, *add it to the shared library* (and the app) rather than inlining
> ad-hoc taps in a scenario. A scenario file should contain almost no Patrol API
> calls — only `Steps` calls.

---

## 1. Pick the right layer

Decide the **cheapest layer that can prove the behaviour**. Most behaviour is
provable below E2E; reserve E2E for true cross-screen user journeys.

| Layer | Proves | Runs on | Folder | Speed |
|------|--------|---------|--------|-------|
| **Unit** | one class/usecase in isolation (logic, math, validation, serialization) | host (Dart VM) | `test/unit/` | ms |
| **Integration** | a repository/DAO against a real **in-memory SQLite**, with a fake remote | host | `test/integration/` | 10s–100s of ms |
| **Widget** | one widget renders/behaves correctly (colors, icons, callbacks) | host | `test/widget/` | ms |
| **E2E (Patrol)** | a full user journey across screens on a real device/emulator | device/emulator | `patrol_test/` | minutes |

Heuristics:
- Scoring/validation/FSRS/serialization rules → **unit**.
- "Saving X then reading it back returns Y", streams, soft-delete, cascade → **integration**.
- "This widget shows the right color/label/button" → **widget**.
- "User signs in, starts a voice quiz, answers, sees their score" → **E2E**.

A spec usually decomposes into **several** tests across layers. Prefer many small
unit/integration tests + **one** representative E2E happy-path per journey.

---

## 2. E2E (Patrol) — the main event

### 2.1 Anatomy of a scenario

Every scenario is one `patrolTest(...)` with three readable phases. Example
([`patrol_test/quiz_test.dart`](../patrol_test/quiz_test.dart)):

```dart
// One-line description of the behaviour being proven.
patrolTest('Voice — all answers correct → 100%',
    timeout: const Timeout(Duration(minutes: 7)), ($) async {
  final app = Steps($);
  addTearDown(() => deleteListsByName($, _list)); // always clean up seeded data

  await app.given.signedIn();
  await app.given.aListWithOneWord(name: _list, french: _fr, korean: _ko);
  await app.given.theLearnerWillAnswerCorrectly();

  await app.when.opensStartASession();
  await app.when.choosesList(_list);
  await app.when.choosesQuizType(Quiz.voice);
  await app.when.startsTheSession();
  await app.when.answersEachCardByVoice();

  await app.then.sessionScoreIs(percent: 100);
});
```

Rules:
- **`final app = Steps($);`** then read top-to-bottom: `given.*` (preconditions),
  `when.*` (actions), `then.*` (assertions). Don't interleave them.
- **Always start and end clean** — call `given.aCleanSlate()` right after
  `given.signedIn()`, and register `addTearDown(() => deleteAllLists($))` at the
  top of the body. Tests share one signed-in account and run in sequence in the
  same process, so each must both *start from* and *leave* a clean slate (§2.9).
- One comment line above the `patrolTest` saying *what user behaviour* it proves.
- Keep the body to `Steps` calls. No `$(...).tap()` in a scenario file.
- **Never put `/` in a `patrolTest` name.** The Android Test Orchestrator names
  a per-test output file after the description, so a path separator crashes the
  whole run (`Total: 0`, `IllegalArgumentException` in `makeFilename`). Use `-`,
  `,`, or "and" instead (e.g. `email-password`, not `email/password`).

### 2.2 The step library — your vocabulary

All steps live in [`patrol_test/helpers/steps.dart`](../patrol_test/helpers/steps.dart),
grouped `given` / `when` / `then`. Each does **one** thing and is named for it.

**given (preconditions)**
| Step | Effect |
|------|--------|
| `given.signedIn()` | Launch the app and land on the Today/home screen, signed in as the test account. Idempotent — instant if already signed in. |
| `given.aListWithOneWord({name, french, korean})` | Create a fresh list with exactly one FR/KO word (deletes any stale list of the same name first). Seeded via the provider layer (fast; skips the add-word dialog). |
| `given.theLearnerWillAnswerCorrectly()` | Script the STT simulator so every spoken answer matches the card. |
| `given.theLearnerWillAnswerIncorrectly()` | Script the STT simulator so every spoken answer is wrong. |
| `given.aCleanSlate()` | Delete **all** the account's lists via the data layer (fast; no UI). Call right after `signedIn()` so the test starts clean and the free-plan quota is empty. |
| `given.noListNamed(name)` | Delete only the lists named `name` (narrower than `aCleanSlate`). |

**when (actions)**
| Step | Effect |
|------|--------|
| `when.opensStartASession()` | Tap the raised centre **Study** nav button → Start-a-session screen. |
| `when.choosesList(name)` | Pick the list to study by name. |
| `when.choosesQuizType(Quiz mode)` | Pick `Quiz.voice` / `.flashcard` / `.typing` / `.handsFree`. |
| `when.startsTheSession()` | Tap **Commencer** (grants the mic on real-STT runs). |
| `when.answersEachCardByVoice()` | Tap the mic once per card until the summary (each simulated answer auto-advances). |
| `when.answersEachCardAsKnown()` | Flashcards: flip + grade every card "Je savais". |
| `when.answersEachCardAsForgotten()` | Flashcards: flip + grade every card "À revoir". |
| `when.typesCorrectAnswerForEachCard(word)` | Typing: enter `word` + validate on every card. |
| `when.typesWrongAnswerForEachCard()` | Typing: enter a deliberately wrong answer on every card. |

**then (assertions)**
| Step | Effect |
|------|--------|
| `then.verdictIsCorrect()` | The feedback flood shows the *correct* (teal) state. |
| `then.verdictIsWrong()` | The feedback flood shows the *wrong* (orange) state. |
| `then.sessionScoreIs(percent: n)` | The session ended and the summary shows `n %`. |

**Enums** (in `steps.dart`; names mirror the app enums so they map to keys):
- `Quiz { voice, flashcard, typing, handsFree }` ↔ `QuizMode` in `lib/presentation/providers/quiz/quiz_provider.dart`
- `Dir { frToKo, koToFr, both }` ↔ `QuizDirectionChoice` (no `choosesDirection` step yet — see §2.6)

### 2.3 Widget keys — your selectors

Defined once in [`lib/core/widget_keys.dart`](../lib/core/widget_keys.dart) and
referenced by both the app and the steps. **Select by these, never by text**
(text is localized and changes). In the app a widget gets one via
`key: const ValueKey(WidgetKeys.xxx)`; in a step via
`find.byKey(const ValueKey(WidgetKeys.xxx))`.

| Key | Where |
|-----|-------|
| `navStudy` (`nav.study`) | raised centre Study nav button |
| `startSessionStart` (`ss.start`) | "Commencer" button |
| `startQuizType(modeName)` (`ss.quiz.<mode>`) | quiz-type tile |
| `startDirection(dirName)` (`ss.dir.<dir>`) | direction tile |
| `startCount(n)` (`ss.count.<n>`) | card-count chip |
| `micButton` (`mic_button`) | voice mic |
| `voiceReveal`, `voiceKeyboard` | voice study controls |
| `cartesCard` | flashcard (tap to flip) |
| `gradeAgain`, `gradeKnew` | flashcard grade buttons |
| `ecrireInput`, `ecrireValidate` | typing field + validate |
| `feedbackCorrect`, `feedbackWrong`, `feedbackContinue` | full-screen verdict flood |
| `hfRepeat`, `hfSkip` | hands-free controls |
| `summary` | end-of-session summary scaffold |

### 2.4 STT simulation — deterministic voice

Real microphones don't exist in CI. [`SttSimulator`](../lib/core/stt_simulator.dart)
makes voice/hands-free deterministic. Because Patrol runs the test and the app in
the **same isolate**, a step sets the outcome at runtime:
`given.theLearnerWillAnswerCorrectly()` sets `SttSimulator.mode = 'correct'`.

- Seeded from the `SIMULATE_SPEECH` build define; overridden per-scenario by the
  `given` step.
- `''` (production) = real on-device STT.
- **Real-STT** behaviour (timeout/retry/"pas entendu") is exercised **manually**
  on a device — don't write CI scenarios for it (leave the simulator off, i.e.
  call no `given.theLearnerWillAnswer…`).

### 2.5 Build defines (set by env files / CI)

| Define | Purpose |
|--------|---------|
| `TEST_EMAIL`, `TEST_PASSWORD` | account `given.signedIn()` uses |
| `SIMULATE_SPEECH` | seeds `SttSimulator` (`correct` in CI) |
| `TEST_LOCALE` | forces app locale (CI emulators default to **English**; set `fr` so French finders/text work) |
| `TEST_MODE` | disables animations & live connectivity for stable, fast tests |
| `TEST_CARD_LIMIT` | shrinks a session to N cards in CI (prod default 20) so a one-word list pads to just a few cards |

Locally these come from a gitignored `test.env.json`; in CI from
[`.github/workflows/e2e.yml`](../.github/workflows/e2e.yml) (built from repo secrets).

### 2.6 Extending the library (do this, don't inline)

When a spec needs something the steps don't cover:

1. **New step** → add a single-purpose method to the right group in `steps.dart`.
   Name it as a sentence fragment (`when.opensTheListEditor()`), select by key,
   `await` any settle, keep it to **one** user-visible action or assertion.
2. **New selector** → add a constant to `WidgetKeys`, wire it in the widget
   (`key: const ValueKey(WidgetKeys.newThing)`), then use it from the step. Adding
   the key to both sides means a rename breaks the build, not a test at runtime.
3. **New precondition data** → prefer seeding through the **provider layer** (like
   `aListWithOneWord`) over driving dialogs; it's faster and less brittle. Always
   pair it with a `delete…`/teardown.
4. Missing axes today, add as needed the same way: `when.choosesDirection(Dir d)`
   (keys exist: `startDirection`) and `when.choosesCardCount(int n)` (keys:
   `startCount`). Direction currently defaults to `frToKo`; count comes from
   `TEST_CARD_LIMIT`.

### 2.7 CI gotchas the generated tests must respect

- **Locale**: the emulator boots in English. Anything matching French text needs
  `TEST_LOCALE=fr`. Prefer keys to dodge this entirely.
- **Shared session**: tests run in sequence in one process and the sign-in
  persists. `given.signedIn()` is therefore a fast no-op after the first test —
  rely on it. Isolation comes from every test **starting and ending clean**
  (§2.9), not from a fresh app per test.
- **Padding**: a session pads a short list up to the card limit by repeating, so a
  one-word list still yields N cards. Keep N small in CI (`TEST_CARD_LIMIT`).
- **Per-card cost**: each card is real wall-clock on the emulator (~seconds).
  Don't write 50-card CI sessions — a handful proves the lifecycle.
- **Timeouts**: the loop steps poll a bounded number of iterations and `then`
  waits with a ceiling. Don't add unbounded `while` loops.

### 2.8 Running E2E

```bash
# Local, on a connected device/emulator:
patrol test --target patrol_test/quiz_all_test.dart \
            --dart-define-from-file=test.env.json -d <device-id>

# Cloud (no device): GitHub Actions → "E2E (emulator)" workflow_dispatch.
```
New scenario files must be imported by the umbrella
[`patrol_test/quiz_all_test.dart`](../patrol_test/quiz_all_test.dart) (or another
target) to run in CI.

### 2.9 Test data isolation & cleanup

Tests share one signed-in account, so list data must not leak between them.
**Three layers** keep every run isolated — and a `create`-via-UI step can never
hit the free-plan list quota (max 3 lists):

1. **Server-side reset before the run (CI).** The `e2e.yml` *"Reset test account
   data"* step signs in as the test user over the Supabase REST API and deletes
   their `vocabulary_lists` (cascading to concepts → word_variants →
   variant_progress). This stops rows from a *previous* run syncing down into the
   fresh emulator and pre-filling the quota. Uses only the existing secrets — it
   relies on RLS (`owner_id = auth.uid()`), no service-role key.
2. **Clean before every test.** Each scenario calls `given.aCleanSlate()` right
   after `signedIn()` — it deletes every list through the **provider/data layer**
   (`deleteAllLists`), not raw HTTP. That matters because the app is offline-first
   and renders from the local SQLite DB; a remote-only delete wouldn't clear what
   the UI shows. (The seeding helpers use the same layer.)
3. **Clean after every test.** Each scenario registers
   `addTearDown(() => deleteAllLists($))` at the top, so the account is wiped even
   if the test fails partway through.

Net effect: every test starts from and leaves a clean slate.

---

## 3. Unit tests

Pattern (see [`test/unit/quiz/submit_answer_usecase_test.dart`](../test/unit/quiz/submit_answer_usecase_test.dart)):

- **Hand-write a minimal fake** implementing the dependency interface; capture the
  value passed in (`captured`), stub the rest with `UnimplementedError()`. No mock
  framework.
- A small **`_make…()` builder** to construct entities at a known state with named
  defaults.
- `setUp()` builds the fake + subject. Group related cases with `group(...)`;
  loop over enum values to cover all variants.
- Results use the `Result<T>` sealed type (`Success`/`Failure`,
  `valueOrNull`, `fold`).

```dart
class _FakeRepo implements SomeRepository {
  Captured? captured;
  @override Future<Result<X>> save(X x) async { captured = x; return Success(x); }
  // ── unused stubs ──
  @override Future<Result<Y>> other() async => throw UnimplementedError();
}
```

## 4. Integration tests

Pattern (see [`test/integration/vocabulary_repository_test.dart`](../test/integration/vocabulary_repository_test.dart)):

- Real DB, **in-memory**: `AppDatabase(NativeDatabase.memory())` in `setUp`,
  `db.close()` in `tearDown`.
- A **`_FakeRemote`** implementing the remote datasource, every call returning
  `Success([])`/`Success(data)` — no network.
- Assert via the repository's **streams** (`watchMyLists`, `watchConcepts`) and
  read-backs; assert soft-delete by inspecting raw rows (`isDeleted == true`), and
  that deletes **don't cascade** where the app relies on that.
- Timestamp tests that depend on `updatedAt` changing use a **>1s wait** (the
  column is second-precision).

> On Linux the host suite needs the sqlite native lib on the path:
> `LD_LIBRARY_PATH="$HOME/.local/lib:$LD_LIBRARY_PATH" flutter test`.

## 5. Widget tests

Pattern (see [`test/widget/study_feedback_flood_test.dart`](../test/widget/study_feedback_flood_test.dart)):

- `tester.pumpWidget(MaterialApp(home: widget))`.
- Find by **type/icon/key/text**; read rendered properties via
  `tester.widget<Material>(...).color`, `tester.getSize(...)`, etc.
- Assert callbacks fire (`var tapped = false; … expect(tapped, isTrue)`).
- For animated widgets, drive them with `isAnimating: false` to test rest states
  deterministically.

Run host tests:
```bash
LD_LIBRARY_PATH="$HOME/.local/lib:$LD_LIBRARY_PATH" flutter test
```

---

## 6. From spec → tests (worked translation)

Spec: *"A learner can take a typing quiz; typing the right answer scores 100%."*

1. **Layer?** Cross-screen journey → **E2E**. (Also: the *matching* rule itself is
   already unit-tested in `answer_validator_test.dart` — don't re-prove it in E2E.)
2. **Vocabulary check:** `signedIn`, `aListWithOneWord`, `choosesQuizType(Quiz.typing)`,
   `typesCorrectAnswerForEachCard`, `sessionScoreIs` all exist. Nothing to add.
3. **Write it:**

```dart
// Typing the correct Korean word on every card → 100%.
patrolTest('Écrire — correct typed answer → 100%',
    timeout: const Timeout(Duration(minutes: 7)), ($) async {
  final app = Steps($);
  addTearDown(() => deleteListsByName($, _list));

  await app.given.signedIn();
  await app.given.aListWithOneWord(name: _list, french: _fr, korean: _ko);

  await app.when.opensStartASession();
  await app.when.choosesList(_list);
  await app.when.choosesQuizType(Quiz.typing);
  await app.when.startsTheSession();
  await app.when.typesCorrectAnswerForEachCard(_ko); // FR→KR default → Korean

  await app.then.sessionScoreIs(percent: 100);
});
```

If step 2 had found a gap (say the spec wanted KO→FR), you'd first add
`when.choosesDirection(Dir.koToFr)` to `steps.dart` (keyed via
`WidgetKeys.startDirection`), *then* write the scenario.

---

## 7. Checklist for a generated test

- [ ] Lowest sufficient layer chosen; logic not re-proved in a slow E2E.
- [ ] E2E body is **only** `given/when/then` `Steps` calls; selectors are keys.
- [ ] Any new step is single-purpose, sentence-named, and in `steps.dart`.
- [ ] Any new selector is a `WidgetKeys` constant wired into the widget.
- [ ] Seeded data is torn down (`addTearDown`).
- [ ] One-line comment states the behaviour proven.
- [ ] New E2E file is imported by an umbrella target.
- [ ] `flutter analyze` clean; host tests pass with `LD_LIBRARY_PATH`.
