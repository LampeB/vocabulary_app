# Automatable tests (Gherkin)

> Every test we **can** automate (no hard device/payment/network limit) across the
> currently-uncovered areas. Derived from [`test-feasibility.md`](./test-feasibility.md).
> Excludes device/manual-only outputs (real purchase, real audio out, OS
> notification firing, OAuth, reset-email delivery, real mic) and unbuilt features
> (sync service, challenges, account deletion).
>
> **Tags** mark the cheapest sufficient layer and any seam to build first:
> `@e2e` `@integration` `@widget` `@unit` ·
> `@seam:premium` (override `isPremiumProvider` / seed Supabase `subscription_type`) ·
> `@seam:seed-sessions` (a `seedQuizSession` helper) ·
> `@seam:second-user` (a seeded 2nd account + friend rows) ·
> `@seam:fake-offerings` `@seam:mock-audio` `@seam:sfx-provider`
> `@seam:overridable-connectivity` `@seam:mock-share` `@seam:record-session`
> `@seam:seed-leaderboard` `@seam:seed-token`.
>
> Each scenario reads in the project's `given/when/then` step vocabulary so it
> maps directly onto `patrol_test/helpers/steps.dart` (extend the library, don't
> inline). New steps/keys named here are the ones to add.

---

## Monetization / Paywall

```gherkin
Feature: Freemium limits send the user to the paywall

  Background:
    Given I am signed in
    And I start from a clean slate

  @e2e
  Scenario: Free user hits the list limit
    Given I am a free user with 3 lists
    When I create a 4th list
    Then the paywall screen is shown

  @e2e
  Scenario: Free user hits the per-list word limit
    Given I am a free user with a list of 50 words
    When I add another word to that list
    Then the paywall screen is shown

  @e2e @seam:premium
  Scenario: Premium user is not limited on lists
    Given I am a premium user with 3 lists
    When I create a 4th list
    Then the 4th list is created
    And the paywall screen is not shown

  @e2e @seam:premium
  Scenario: Premium user is not limited on words
    Given I am a premium user with a list of 50 words
    When I add another word to that list
    Then the word is added
    And the paywall screen is not shown

  @widget @e2e @seam:fake-offerings
  Scenario: Paywall shows both subscription options with prices
    When I open the paywall
    Then I see the annual option highlighted
    And I see the monthly option
    And each option shows its price

  @e2e @seam:fake-offerings
  Scenario: Restore purchases succeeds (success path, mocked store)
    Given the store reports an active premium entitlement
    When I tap restore purchases on the paywall
    Then a restore-success message is shown
    And my account is premium
```

## Settings

```gherkin
Feature: Theme settings

  Background:
    Given I am signed in
    And I open Settings

  @e2e @widget
  Scenario: Switch to dark theme
    When I choose the Dark theme
    Then the app renders in dark theme

  @e2e
  Scenario: Theme persists across restart
    When I choose the Dark theme
    And I restart the app
    Then the app is still in dark theme

  @unit
  Scenario Outline: Theme choice is persisted
    When I set the theme to <mode>
    Then the stored theme mode is <mode>
    Examples:
      | mode   |
      | light  |
      | dark   |
      | system |
```

```gherkin
Feature: Language settings

  Background:
    Given I am signed in
    And I open Settings

  @e2e
  Scenario: Switch UI language to Korean
    When I choose the Korean language
    Then the visible labels are in Korean

  @e2e
  Scenario: Language persists across restart
    When I choose the Korean language
    And I restart the app
    Then the visible labels are still in Korean
```

```gherkin
Feature: Audio settings (premium)

  Background:
    Given I am signed in
    And I open Settings

  @e2e @widget @seam:premium
  Scenario: Premium user changes the speech rate
    Given I am a premium user
    When I set the speech rate to Fast
    Then the speech rate setting is Fast
    And it persists across restart

  @widget @seam:premium
  Scenario Outline: Speech rate options persist
    Given I am a premium user
    When I set the speech rate to <rate>
    Then the stored speech rate is <rate>
    Examples:
      | rate   |
      | slow   |
      | normal |
      | fast   |

  @e2e
  Scenario: Audio settings are locked for a free user
    Given I am a free user
    Then the audio speed and pitch controls are disabled
```

```gherkin
Feature: Subscription status display

  Background:
    Given I am signed in
    And I open Settings

  @e2e @widget
  Scenario: Free user sees an upgrade prompt
    Given I am a free user
    Then the subscription tile shows "Free"
    And an upgrade action is offered

  @widget @seam:premium
  Scenario: Premium user sees premium and no upgrade
    Given I am a premium user
    Then the subscription tile shows "Premium"
    And no upgrade action is offered
```

## Notifications

```gherkin
Feature: Notification settings

  Background:
    Given I am signed in
    And I open Notification settings

  @e2e @widget
  Scenario: Enabling the daily reminder reveals the time picker
    When I enable the daily reminder
    Then the reminder time picker is shown

  @e2e
  Scenario: Reminder time persists
    When I enable the daily reminder
    And I set the reminder time to 14:30
    And I restart the app
    Then the daily reminder is on at 14:30

  @e2e @widget
  Scenario: Toggling the streak-protection warning persists
    When I turn off the streak-protection warning
    And I restart the app
    Then the streak-protection warning is off

  @unit
  Scenario: Daily reminder is scheduled for the next occurrence
    Given the current time is 10:00
    When a daily reminder is scheduled for 09:00
    Then it is scheduled for 09:00 tomorrow

  @unit
  Scenario: Streak warning is skipped when there is no streak
    Given my current streak is 0
    When a streak warning is requested
    Then no streak warning is scheduled

  @e2e @seam:premium
  Scenario: Granting permission shows confirmation
    When I request notification permission
    And I grant the system permission
    Then a permissions-granted confirmation is shown
```

## Stats

```gherkin
Feature: Study statistics

  Background:
    Given I am signed in
    And I start from a clean slate

  @e2e @seam:record-session
  Scenario: Completing a quiz records a session
    Given a list with one word
    When I complete a typing quiz at 100%
    And I open Stats
    Then the session count increased by one
    And the latest session shows the typing mode and 100%

  @e2e @widget @seam:seed-sessions
  Scenario: Stats summary chips reflect seeded sessions
    Given 3 completed quiz sessions
    When I open Stats
    Then the sessions chip shows 3

  @widget @seam:seed-sessions
  Scenario: Mastered-over-time chart renders points
    Given quiz sessions with mastered words over several days
    When I open Stats
    Then the mastered-over-time chart plots a point per day

  @e2e
  Scenario: Empty stats state for a new account
    Given I have completed no quizzes
    When I open Stats
    Then an empty-stats state is shown
```

## Social

```gherkin
Feature: Leaderboard

  Background:
    Given I am signed in

  @e2e @seam:seed-leaderboard
  Scenario: Leaderboard ranks users by mastered words
    Given several users with different mastered-word counts
    When I open the leaderboard
    Then users are listed in descending mastered-word order

  @e2e @seam:seed-leaderboard
  Scenario: The current user is highlighted
    When I open the leaderboard
    Then my own row is highlighted

  @e2e
  Scenario Outline: Switch the leaderboard period
    When I open the leaderboard
    And I select the <period> period
    Then the <period> period is active
    Examples:
      | period   |
      | weekly   |
      | monthly  |
      | all-time |
```

```gherkin
Feature: Friends

  Background:
    Given I am signed in

  @e2e @seam:second-user
  Scenario: Search for a user by username
    Given another user "studybuddy" exists
    When I search friends for "studybuddy"
    Then "studybuddy" appears in the results

  @e2e @seam:second-user
  Scenario: Send a friend request
    Given another user "studybuddy" exists
    When I send a friend request to "studybuddy"
    Then the request to "studybuddy" is pending

  @e2e @seam:second-user
  Scenario: Accept an incoming friend request
    Given "studybuddy" has sent me a friend request
    When I accept the request from "studybuddy"
    Then "studybuddy" appears in my friends list

  @e2e @seam:second-user
  Scenario: Decline an incoming friend request
    Given "studybuddy" has sent me a friend request
    When I decline the request from "studybuddy"
    Then "studybuddy" is not in my friends list
    And the request is no longer pending

  @e2e @seam:second-user
  Scenario: Remove a friend
    Given "studybuddy" is my friend
    When I remove "studybuddy"
    Then "studybuddy" is not in my friends list

  @e2e @seam:second-user
  Scenario: View pending requests
    Given "studybuddy" has sent me a friend request
    When I open the Friends tab
    Then a pending request from "studybuddy" is shown
```

## Auth (additional)

```gherkin
Feature: Sign out

  @e2e
  Scenario: Sign out returns to Welcome
    Given I am signed in
    When I sign out from Profile
    Then the Welcome screen is shown

Feature: Password reset (form only — email delivery is manual)

  @e2e
  Scenario: Submitting a reset request succeeds
    Given I am on the sign-in screen
    When I request a password reset for a valid email
    Then a reset-sent confirmation is shown

  @e2e
  Scenario: Reset request with an invalid email shows an error
    Given I am on the sign-in screen
    When I request a password reset for "not-an-email"
    Then an invalid-email error is shown

Feature: Sign-up validation

  @unit @e2e
  Scenario Outline: Invalid usernames are rejected
    When I sign up with username "<username>"
    Then sign-up is rejected with a validation error
    Examples:
      | username                            |
      | ab                                  |
      | bad name                            |
      | accentué                            |
      | way_too_long_username_over_32_chars |
```

## Import / Export / Share

```gherkin
Feature: Import and export lists

  @integration
  Scenario: Export a list to JSON
    Given a list with two words
    When I export the list to JSON
    Then the JSON contains both word pairs

  @integration
  Scenario: Import a list from JSON
    Given an export JSON for a two-word list
    When I import it
    Then a list with both words exists

  @integration
  Scenario: Export then import preserves the list
    Given a list with three words
    When I export it and import the result into a new list
    Then the new list has the same three words

  @integration @seam:seed-token
  Scenario: Import from a share token
    Given a shared list exists for token "abc123"
    When I import from token "abc123"
    Then the shared list is added to my lists

  @e2e @unit @seam:seed-token
  Scenario: Opening an import deep link adds the list
    Given a shared list exists for token "abc123"
    When the app opens "vocabkr://import?token=abc123"
    Then the imported list appears in my lists

  @unit @seam:mock-share
  Scenario: Exporting a list invokes the share sheet
    Given a list with one word
    When I export the list
    Then the share sheet is invoked with the list's JSON file
```

## Offline

```gherkin
Feature: Offline-first behaviour

  @integration
  Scenario: List and word edits work with no network
    Given the remote is unreachable
    When I create a list and add a word
    Then both are saved locally
    And they are marked not-yet-synced

  @e2e @seam:overridable-connectivity
  Scenario: The offline banner appears when connectivity drops
    Given I am signed in
    When connectivity goes offline
    Then the offline banner is shown

  @e2e @seam:overridable-connectivity
  Scenario: The offline banner hides when connectivity returns
    Given the offline banner is shown
    When connectivity is restored
    Then the offline banner is hidden
```

## Audio cues (intent — real output is verified on device)

```gherkin
Feature: The app requests the right audio

  Background:
    Given I am signed in
    And a list with one word

  @e2e @seam:mock-audio
  Scenario: Typing mode plays the answer audio
    When I run a typing quiz
    Then the answer audio is requested for each card

  @e2e @seam:mock-audio
  Scenario: Hands-free plays answer audio only when wrong
    Given the learner will answer incorrectly
    When I run a hands-free quiz
    Then the answer audio is requested for the wrong card

  @e2e @seam:mock-audio
  Scenario: Flashcards request no answer audio
    When I run a flashcard quiz
    Then no answer audio is requested

  @e2e @seam:sfx-provider
  Scenario: Correct and wrong answers fire their sound cues
    When I answer one card correctly
    Then the correct sound cue is fired
    When I answer one card incorrectly
    Then the wrong sound cue is fired

  @integration
  Scenario: Premium answer audio is cached after first fetch
    Given a premium user and a fetched answer clip
    When the same answer audio is requested again
    Then it is served from cache without a new fetch
```

---

## Notes

- **Already green** (here for completeness, not to re-add): the 4 quiz modes, KO→FR
  direction, per-card verdicts, navigation to every screen, and the full
  create→edit→delete→quiz journey — see [`test-scenarios.md`](./test-scenarios.md).
- **Build the seam once, reuse everywhere.** The tags above point at ~9 small
  enablers; building `seam:seed-sessions`, `seam:premium`, and `seam:second-user`
  alone unlocks Stats, the Paywall premium paths, and most of Social.
- **Layer discipline** (per [`writing-tests.md`](./writing-tests.md)): prove logic
  at unit/integration; reserve `@e2e` for true cross-screen journeys. Several
  scenarios above are tagged with multiple layers — pick the cheapest that proves
  the behaviour.
```
