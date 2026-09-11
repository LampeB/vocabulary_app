# V0 — daily learning loop

**Status:** agreed scope, ready for implementation planning  
**Last updated:** 2026-09-12

## Outcome

A new learner can open the app, understand their next action, meet a small
amount of useful language, practise only material they have already met, and
see that their progress was saved. This must work with device language and
teaching copy in French, English, and Korean.

The V0 does **not** include friendships or subscriptions. They must not appear
as incomplete primary actions in the daily loop.

## V0 language matrix

| Base (explanations/UI) | Target (learned language) | Role |
|---|---|---|
| French | Korean | Primary learner path |
| English | Korean | Multi-language proof path |
| Korean | French | First beta-validation path |

The existing N-language seed model remains general. This matrix limits what we
present and support in V0; it does not restrict future pairs.

## Evidence from the current repository

| Area | Current state | V0 implication |
|---|---|---|
| App locales | FR, EN and KO are registered; each has 381 translation keys | Localised UI foundation exists; every new key must be added to all three. |
| Pair model and seeding | Ordered base/target pairs; seed layers compose by language | The three V0 paths do not require a pair-specific data model. |
| Starter vocab | 111 aligned concepts in each of FR/EN/KO | Enough material for a focused first loop. |
| `starter-greetings` | 18 concepts; only 3 currently have Korean examples | Not ready to be the first lesson without an example backfill. |
| Notes | KO: 111 entries with FR/EN notes; FR/EN: none | Helpful for learning Korean; Korean-base French needs Korean teaching copy. |
| Grammar | FR: 4 rules; EN: 4; KO: 5; rule cards are FR/EN only | Korean cards are a content prerequisite for Korean → French lessons. |
| Lesson viewer texts | None | First unit needs an authored compact lesson, not a placeholder. |

## Learner flow and acceptance conditions

```text
Home / Chemin du jour
  → Discover a small new batch
  → Lesson and tappable examples
  → light, ungraded echo practice
  → due flashcard review
  → calm result and persisted progress
```

For the first unit, each condition below must hold in the three V0 pairs:

1. The header shows the complete ordered pair, not merely the target language.
2. Home offers one obvious primary action. It names the next step and its
   amount (for example, a small discovery batch or the number of due reviews).
3. Lesson navigation uses the **dive-in** transition. An example can open a
   contextual popup; it does not navigate to a generic card screen.
4. A newly encountered item is introduced before it can be scheduled for an
   FSRS review. First-contact practice is encouraging and ungraded.
5. Flashcard stacks are reserved for the review session. Feedback makes the
   next action clear.
6. Scroll is avoided where possible; when necessary, an explicit visual cue
   reveals that more content is below.
7. Completion updates local progress and remains correct after an app restart
   and an offline-to-online sync.
8. Every displayed instruction, empty/error state and teaching explanation is
   available in the learner's base language; no English fallback for KO → FR.

## Implementation sequence

### 1. Make the loop selectable

- Establish the V0 language matrix in the language-pair picker and hide or
  label out-of-scope paths appropriately.
- Build the daily-path shell from existing due-review and list data, with
  deep-links into the current session flow.
- Verify the active pair is passed through every step and persisted.

### 2. Make discovery safe

- Add the introduced-state gate described in `two-flow-daily-plan.md` so a
  quiz cannot draw a raw, unseen variant.
- Implement the discovery batch and its light echo practice.
- Use the `starter-greetings` unit as the first real data set only after its
  content work is complete.

### 3. Make the lesson legible

- Add the smallest reusable lesson data shape and viewer path.
- Implement tappable examples with contextual popups.
- Apply the documented interaction language: dive-in for normal navigation,
  stacked cards exclusively for review.

### 4. Close and test the loop

- Add the completion/bilan state and progress refresh.
- Test each V0 pair on-device: fresh profile, interrupted session, offline
  session, restart, then sync.
- Add focused widget/integration coverage for the gate, pair propagation and
  progress persistence.

## Content work for the first vertical slice

The first learning unit is a reviewable content deliverable, not an ad-hoc
translation during UI development:

1. Complete practical examples for all 18 `starter-greetings` concepts in
   the FR/EN/KO layers.
2. Author a short "greeting and introducing yourself" lesson in FR, EN and
   KO, including the Korean-base French version of its explanation.
3. Add a small, ungraded echo exercise set and a compact graded review set.
4. Get the teacher's review of accuracy, register, instructions and sequence.
5. Run the seed validity and grammar-module tests before it lands.

## Human validation needed later

No technical preparation is needed from the project owner now. Before a unit
is exposed to pupils, the teacher should review one concise diff/checklist:

- Is the French appropriate for the intended learner level and classroom
  context?
- Are the Korean instructions natural, respectful and unambiguous?
- Are examples useful in real life rather than mechanically illustrative?
- Does the order make sense for a beginner who has not seen the next concept?

That review is a release gate for teaching content, not a request for her to
test unfinished screens.

## Definition of done for the V0 slice

The slice is done when a Korean-speaking learner can complete the introductory
French unit on a physical device with a Korean interface, resume it after a
restart, and see the introduced words appear only in a later review session;
the same loop must be demonstrably usable for FR → KO and EN → KO.
