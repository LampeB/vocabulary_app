# Test suite

## E2E tests — Patrol (real device)

Scenarios are written as readable **given / when / then** steps from a shared
step library (`patrol_test/helpers/steps.dart`), selecting widgets by stable keys
(`lib/core/widget_keys.dart`) rather than localized text. STT is mocked via
`SttSimulator` (`lib/core/stt_simulator.dart`), which is runtime-controllable, so
a step can state intent — `given.theLearnerWillAnswerCorrectly()` — and one run
covers both correct and wrong cases.

Run a suite on a connected Android emulator:
```
patrol test --target patrol_test/quiz_test.dart \
            --dart-define-from-file=test.env.json -d <device-id>
```

| File | Scenarios |
|------|-----------|
| `navigation_test.dart` | Bottom navigation · session setup route · Profile destinations · list detail navigation |
| `user_flows_test.dart` | Create/edit/delete a list through the UI · study the resulting list in typing and flashcard modes |
| `daily_path_test.dart` | Daily-path vocabulary entry · Daily-path lessons entry |
| `lesson_prerequisites_test.dart` | An unrelated list cannot unlock a lesson · real graduated prerequisite vocabulary unlocks and opens it |
| `quiz_test.dart` | Voice all-correct→100% · Voice all-wrong→0% · Hands-free auto→100% · Cartes known→100% · Cartes forgotten→0% |
| `quiz_ecrire_test.dart` | Écrire correct/wrong · KO→FR · per-card verdicts · selected 10-card count |
| `auth_flows_test.dart` | Sign-out · password-reset request response |
| `auth_login_test.dart` | Real email/password login smoke test |

The emulator workflow runs these eight suites separately, with retries per file.
`auth_test.dart`, `vocab_list_test.dart`, and `sign_up_test.dart` remain legacy
standalone targets; the maintained coverage lives in the suites above.

Real-STT ("nosim") timeout/retry checks are exercised manually on-device (leave
the simulator off — don't call a `given.theLearnerWillAnswer…` step).

### Env files

| File | Use |
|------|-----|
| `test.env.json` | Default — copy `test.env.json.example`, fill the test-account credentials, and keep `TEST_MODE=true` / `TEST_LOCALE=fr` |
| `test.free.env.json` | Alias for the free plan |
| `test.nosim.env.json` | Real STT on device (simulator off) |

---

## Unit & integration tests — Flutter test (host)

Run with:
```
flutter test
```

### `test/unit/fsrs_algorithm_test.dart` (21 tests)
Spaced-repetition scheduling (FSRS algorithm).

- new card: Again / Hard / Good / Easy ratings
- new card: nextReview relative to now
- new card: stability is positive after first rating
- new card: difficulty stays in [1, 10] for all ratings
- learning card: Again keeps in learning
- learning card: Good graduates to review
- learning card: Easy graduates to review
- learning card: rep count increments
- review card: Again → relearning, lapses increment
- review card: Good → stays in review
- review card: Easy → longer interval than Good
- review card: stability increases on successful recall
- relearning card: Again stays in relearning
- relearning card: Good graduates back to review
- retrievability: new card has 0 retrievability
- retrievability: recently reviewed card has high retrievability
- difficulty clamped: repeated Easy does not push below 1
- difficulty clamped: repeated Again does not push above 10

### `test/unit/answer_validator_test.dart` (13 tests)
Fuzzy answer matching (Dice-coefficient bigrams).

- blank string is always incorrect
- identical string is exact
- case-insensitive match is exact
- Korean exact match
- accented string matches itself exactly
- accepts any word in a multi-answer list
- matchedWord reflects the best match
- extra trailing char is correctable (threshold 0.85)
- completely wrong answer is incorrect
- closer match scores higher than distant match
- driving mode accepts same valid answers as typing mode
- exact match has score close to 1.0
- wrong answer has lower score than correct answer

### `test/unit/core/hangul_decomposer_test.dart` (14 tests)
`HangulDecomposer` in `lib/core/utils/hangul_decomposer.dart`.

- decompose: single syllable no-jong (`가`→`ㄱㅏ`), with-jong (`한`→`ㅎㅏㄴ`)
- decompose: multi-syllable (`안녕`→`ㅇㅏㄴㄴㅕㅇ`), non-Hangul passthrough, mixed
- decompose: empty string, first/last in Unicode block (boundary values), space/punctuation passthrough
- containsHangul: pure Hangul, mixed, Latin-only, empty, digits/punctuation

### `test/unit/core/string_ext_test.dart` (15 tests)
`StringExt` in `lib/core/extensions/string_ext.dart`.

- normalized: trim, lowercase, trim+lowercase together, empty string
- removeAccents: all 27 accented→ASCII pairs, unaccented unchanged, mixed, Korean unchanged
- isKorean / isFrench: pure Hangul, mixed, Latin-only, empty

### `test/unit/core/result_test.dart` (10 tests)
`Result<T>` sealed class in `lib/core/errors/failure.dart`.

- isSuccess/isFailure: complementarity for both variants
- valueOrNull: Success→value, Failure→null, nullable type parameter
- exceptionOrNull: Success→null, Failure→exception instance
- fold: correct branch called, wrong branch not called, return value threaded

### `test/unit/domain/subscription_type_test.dart` (8 tests)
`SubscriptionType` in `lib/domain/entities/subscription_type.dart`.

- hasAccess: free→false, student/premium→true
- displayLabel: all three values
- fromString: known values, null, unknown string→free

### `test/unit/auth/sign_up_usecase_test.dart` (9 tests)
`SignUpUseCase` in `lib/domain/usecases/auth/sign_up_usecase.dart`.

- validation failures: empty, 2-char, whitespace-only, hyphen, at-sign, space, accent
- validation successes: exactly 3 chars, alphanumeric+underscore
- normalisation: uppercase→lowercase, mixed-case→lowercase

### `test/unit/quiz/submit_answer_usecase_test.dart` (11 tests)
`SubmitAnswerUseCase` in `lib/domain/usecases/quiz/submit_answer_usecase.dart`.

- timesShown: always increments by 1 regardless of rating
- timesCorrect: Again→no increment, Hard/Good/Easy→increments
- masteryLevel: 0 when reps=0, calculated correctly when reps>0
- FSRS delegation: new+Good→learning, learning+Good→review, FSRS reps/state set
- isSynced: always false after update

### `test/unit/data/variant_progress_dto_test.dart` (9 tests)
`VariantProgressDto.toRemoteMap()` in `lib/data/models/variant_progress_dto.dart`.

- field names: all snake_case keys present, no camelCase
- enum serialization: frToKo/koToFr/newCard/review
- nullable dates: null→null in map, non-null→ISO 8601 string

### `test/integration/vocabulary_repository_test.dart` (19 tests)
Import/export, Drift DB operations, and word count correctness.

- importFromJson: returns Success, inserts concepts and variants, streams data, handles errors
- exportToJson: Failure for unknown id, correct data, round-trip preserves everything
- createConcept / deleteConcept: appears/disappears in watchConcepts
- wordCount: add 3→3, delete 1→2, delete all→0

### `test/integration/vocabulary_list_test.dart` (15 tests)
List CRUD, soft-delete, and stream ordering.

- createList: appears in watchMyLists, wordCount=0, distinct IDs, timestamps set
- updateList: name visible, updatedAt changes (>1s wait, second precision), isSynced=false, createdAt preserved
- deleteList: disappears from watchMyLists, raw row has isDeleted=true, concepts NOT cascade-deleted
- watchMyLists ordering: most recently updated appears first (updatedAt DESC)

### `test/integration/concept_variant_test.dart` (24 tests)
Concept CRUD, variant CRUD, cascade behaviour.

- addConceptWithVariants: atomic insert of 2 variants, wordCount++, langCodes correct
- updateConcept: notes/category visible, updatedAt changes (>1s wait, second precision)
- deleteConcept: disappears from watchConcepts, wordCount--, variants NOT cascade-deleted
- variant CRUD: createVariant, updateVariant (word, isSynced=false), deleteVariant (isDeleted=true)

### `test/integration/progress_repository_test.dart` (26 tests)
Progress/FSRS layer over in-memory DB.

- getProgress: new-card defaults, existing record unchanged
- updateProgress: all FSRS fields persisted, isSynced=false, readback matches
- getDueCards: new cards returned, excludes future, includes past-due, respects limit, direction isolation
- watchDueCount: 0 when empty, 1 after null nextReview, 0 after future nextReview
- FSRS state transitions: new+Again→learning, new+Good→learning, learning+Good→review, review+Again→relearning
- bidirectional progress isolation: separate rows per direction, no cross-contamination

### `test/widget_test.dart` (1 test)
- placeholder

---

**Total: 745 host tests** (`flutter test`, snapshot at 2026-09-19), plus the Patrol
E2E suite above (run on a device).

---

## App bugs found and fixed by these tests

| Bug | File | Fix |
|-----|------|-----|
| `updateConcept` silently failed: missing `createdAt` in companion caused Drift NOT NULL violation | `lib/data/repositories/vocabulary_repository_impl.dart` | Added `createdAt: Value(updated.createdAt)` to the companion |
| `getDueCards` returned future-scheduled cards as new cards: `existingVariantIds` only included due rows, so future-scheduled variants fell into `newVariantIds` | `lib/data/repositories/progress_repository_impl.dart` + `lib/data/datasources/local/daos/progress_dao.dart` | Added `getExistingVariantIds` DAO method; `getDueCards` now uses it to distinguish truly-new from scheduled-future |
| `updateProgress` passed through caller's `isSynced` value instead of always forcing `false` | `lib/data/repositories/progress_repository_impl.dart` | Added `copyWith(isSynced: false, updatedAt: DateTime.now())` before upsert |
