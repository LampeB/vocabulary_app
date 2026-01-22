# VocabApp - Features & Use Cases (Gherkin)

## Feature 1: Vocabulary List Management

```gherkin
Feature: Vocabulary List Management
  As a language learner
  I want to manage my vocabulary lists
  So that I can organize words I'm learning

  Background:
    Given the app is launched
    And I am on the home screen

  # ─────────────────────────────────────────────────────────────
  # VIEW LISTS
  # ─────────────────────────────────────────────────────────────

  Scenario: View empty home screen
    Given I have no vocabulary lists
    Then I should see the empty state message "Aucune liste de vocabulaire"
    And I should see the add list button

  Scenario: View vocabulary lists with progress
    Given the following vocabulary lists exist:
      | name           | lang1 | lang2 | totalWords | knownWords |
      | Salutations    | fr    | ko    | 20         | 15         |
      | Nourriture     | fr    | ko    | 30         | 10         |
    When I am on the home screen
    Then I should see the list "Salutations" with progress "75%"
    And I should see the list "Nourriture" with progress "33%"
    And I should see language pair "FR ↔ KO" for each list

  Scenario: Pull to refresh lists
    Given I am on the home screen
    When I pull down to refresh
    Then the list should be reloaded
    And I should see updated progress statistics

  # ─────────────────────────────────────────────────────────────
  # CREATE LIST
  # ─────────────────────────────────────────────────────────────

  Scenario: Create a new vocabulary list
    When I click the add list button
    Then I should see the create list dialog
    When I enter list name "Expressions courantes"
    And I click the create button
    Then I should see the list "Expressions courantes" on the home screen
    And I should see a success message "Liste créée !"

  Scenario: Cancel creating a list
    When I click the add list button
    And I enter list name "Temporary"
    And I click the cancel button
    Then I should not see the list "Temporary" on the home screen

  Scenario: Cannot create list with empty name
    When I click the add list button
    And I leave the list name empty
    And I click the create button
    Then the list should not be created
    And the dialog should remain open

  # ─────────────────────────────────────────────────────────────
  # DELETE LIST
  # ─────────────────────────────────────────────────────────────

  Scenario: Delete a vocabulary list
    Given a vocabulary list "Liste à supprimer" exists
    When I long press on the list "Liste à supprimer"
    And I click the delete button
    Then I should see a confirmation dialog
    When I confirm the deletion
    Then I should not see the list "Liste à supprimer" on the home screen

  Scenario: Cancel deleting a list
    Given a vocabulary list "Liste importante" exists
    When I long press on the list "Liste importante"
    And I click the delete button
    And I cancel the deletion
    Then I should still see the list "Liste importante" on the home screen
```

## Feature 2: Word/Concept Management

```gherkin
Feature: Word Management
  As a language learner
  I want to add and manage words in my vocabulary lists
  So that I can build my vocabulary

  Background:
    Given the app is launched
    And a vocabulary list "Ma liste" exists
    And I am on the list detail page for "Ma liste"

  # ─────────────────────────────────────────────────────────────
  # VIEW WORDS
  # ─────────────────────────────────────────────────────────────

  Scenario: View empty list
    Given the list has no words
    Then I should see the empty state message
    And I should see the add word button

  Scenario: View words in list
    Given the list contains the following words:
      | french  | korean | category   |
      | Bonjour | 안녕하세요 | greetings  |
      | Merci   | 감사합니다 | greetings  |
    Then I should see "Bonjour" with "안녕하세요"
    And I should see "Merci" with "감사합니다"
    And I should see category badge "greetings"

  Scenario: View list information
    When I click the info button
    Then I should see a dialog with:
      | field        | value      |
      | Liste        | Ma liste   |
      | Langues      | FR ↔ KO    |
      | Nombre mots  | 2          |

  # ─────────────────────────────────────────────────────────────
  # ADD WORD
  # ─────────────────────────────────────────────────────────────

  Scenario: Add a new word with audio generation
    When I click the add word button
    Then I should see the add word dialog
    When I enter French word "Au revoir"
    And I enter Korean word "안녕히 가세요"
    And I click the add button
    Then I should see "Au revoir" in the list
    And audio should be generated for both languages
    And I should see a success message "Mot ajouté avec audio !"

  Scenario: Add word with category
    When I click the add word button
    And I enter French word "Pomme"
    And I enter Korean word "사과"
    And I select category "food"
    And I click the add button
    Then I should see "Pomme" with category badge "food"

  Scenario: Cannot add word with empty fields
    When I click the add word button
    And I leave the French word empty
    And I click the add button
    Then the word should not be added
    And I should see a validation error

  # ─────────────────────────────────────────────────────────────
  # DELETE WORD
  # ─────────────────────────────────────────────────────────────

  Scenario: Delete a word
    Given the list contains the word "Bonjour"
    When I swipe left on "Bonjour"
    And I click the delete button
    Then I should see a confirmation dialog
    When I confirm the deletion
    Then "Bonjour" should be removed from the list
    And its audio files should be deleted
    And I should see "Mot et audio supprimés"

  # ─────────────────────────────────────────────────────────────
  # AUDIO PLAYBACK
  # ─────────────────────────────────────────────────────────────

  Scenario: Play audio for a word
    Given the word "Bonjour" has audio generated
    When I click the speaker icon for "Bonjour"
    Then I should hear the French pronunciation

  Scenario: Audio not available
    Given the word "Test" has no audio
    Then the speaker icon should not be visible for "Test"

  # ─────────────────────────────────────────────────────────────
  # REGENERATE AUDIO
  # ─────────────────────────────────────────────────────────────

  Scenario: Regenerate audio for a word
    Given the word "Bonjour" exists with audio
    When I long press on "Bonjour"
    And I click "Régénérer audio"
    Then I should see a confirmation dialog
    When I confirm
    Then I should see a progress indicator
    And new audio should be generated with current settings
    And the old audio should be deleted
    And I should see "audio(s) régénéré(s) !"
```

## Feature 3: Quiz - Text Mode

```gherkin
Feature: Quiz Text Mode
  As a language learner
  I want to take quizzes by typing answers
  So that I can practice my vocabulary

  Background:
    Given the app is launched
    And a vocabulary list "Quiz Test" exists with 10 words
    And I start a quiz for "Quiz Test"

  # ─────────────────────────────────────────────────────────────
  # QUIZ FLOW
  # ─────────────────────────────────────────────────────────────

  Scenario: Start a quiz
    Given I am on the home screen
    When I click the quiz button for "Quiz Test"
    Then I should see the quiz screen
    And I should see question counter "1/10"
    And I should see a word to translate
    And I should hear the audio automatically

  Scenario: Answer correctly - exact match
    Given the question is "Bonjour" (translate to Korean)
    When I type "안녕하세요"
    And I click verify
    Then I should see "Parfait !"
    And the answer should be marked as correct
    And I should see the "Next question" button

  Scenario: Answer correctly - close match (85%+ similarity)
    Given the question is "Au revoir" (translate to Korean)
    When I type "안녕히가세요" (missing space)
    And I click verify
    Then I should see "Presque !"
    And the answer should be accepted

  Scenario: Answer incorrectly
    Given the question is "Merci" (translate to Korean)
    When I type "안녕하세요"
    And I click verify
    Then I should see "Incorrect"
    And I should see the expected answer "감사합니다"

  Scenario: Navigate to next question
    Given I have answered the current question
    When I click "Question suivante"
    Then the question counter should increment
    And I should see a new word to translate
    And the answer field should be cleared
    And audio should play automatically

  Scenario: Replay audio
    When I click the audio icon
    Then the word pronunciation should play again

  # ─────────────────────────────────────────────────────────────
  # QUIZ COMPLETION
  # ─────────────────────────────────────────────────────────────

  Scenario: Complete a quiz
    Given I have answered all 10 questions
    When I complete the last question
    Then I should see the results screen
    And I should see my score "X / 10"
    And I should see my percentage
    And progress should be saved to the database

  Scenario: Quiz updates SRS progress
    Given I answer "Bonjour" correctly
    Then the mastery level for "Bonjour" should increase
    And the next review date should be updated
    And the word should be marked as "known" if mastery >= 70%
```

## Feature 4: Quiz - Speech Mode

```gherkin
Feature: Quiz Speech Mode
  As a language learner
  I want to take quizzes by speaking answers
  So that I can practice pronunciation

  Background:
    Given the app is launched
    And a vocabulary list "Speech Test" exists with words
    And I start a speech quiz for "Speech Test"

  # ─────────────────────────────────────────────────────────────
  # SPEECH INPUT
  # ─────────────────────────────────────────────────────────────

  Scenario: Answer by speaking
    Given the question is "Bonjour" (translate to Korean)
    When I click the microphone button
    Then I should see "Parlez maintenant..."
    And speech recognition should start in Korean
    When I say "안녕하세요"
    Then I should see the recognized text
    And I should see a confidence percentage

  Scenario: Auto-validation with high confidence
    Given speech recognition is active
    When I speak with confidence > 70%
    Then the answer should be automatically submitted
    And validation should occur

  Scenario: Manual validation with low confidence
    Given speech recognition returns confidence < 70%
    Then I should see the recognized text
    And I should be able to manually click verify

  Scenario: Fallback to text input
    Given speech recognition is not working
    When I type my answer manually
    And I click verify
    Then the answer should be validated normally

  Scenario: Stop listening
    Given speech recognition is active
    When I click the microphone button again
    Then listening should stop
    And I should see the final recognized text
```

## Feature 5: Settings

```gherkin
Feature: Audio Settings
  As a user
  I want to configure voice settings
  So that audio sounds the way I prefer

  Background:
    Given the app is launched
    And I navigate to the settings screen

  # ─────────────────────────────────────────────────────────────
  # VOICE SELECTION
  # ─────────────────────────────────────────────────────────────

  Scenario: Change French voice
    When I click on the French voice dropdown
    Then I should see available voices:
      | voice     | recommended |
      | Adam      | yes         |
      | Charlotte | yes         |
      | Thomas    | yes         |
      | Bella     | yes         |
    When I select "Charlotte"
    And I click save
    Then French voice should be set to "Charlotte"

  Scenario: Change Korean voice
    When I click on the Korean voice dropdown
    Then I should see available voices with "Rachel" recommended
    When I select "Lily"
    And I click save
    Then Korean voice should be set to "Lily"

  # ─────────────────────────────────────────────────────────────
  # AUDIO PARAMETERS
  # ─────────────────────────────────────────────────────────────

  Scenario: Adjust stability
    When I move the stability slider to 0.8
    Then I should see stability value "0.80"
    And I should see description "Plus stable et prévisible"

  Scenario: Adjust similarity
    When I move the similarity slider to 0.3
    Then I should see similarity value "0.30"
    And I should see description "Plus de liberté créative"

  # ─────────────────────────────────────────────────────────────
  # SAVE & RESET
  # ─────────────────────────────────────────────────────────────

  Scenario: Save settings
    When I change voice settings
    And I click save
    Then I should see "Paramètres sauvegardés"
    And new words should use the new settings

  Scenario: Reset to defaults
    Given I have custom settings
    When I click "Réinitialiser"
    And I confirm the reset
    Then all settings should return to defaults:
      | setting    | default |
      | French     | Adam    |
      | Korean     | Rachel  |
      | Stability  | 0.50    |
      | Similarity | 0.75    |

  Scenario: Settings apply to new words only
    Given I have existing words with old voice
    When I change voice settings
    And I add a new word
    Then the new word should have the new voice
    And existing words should keep the old voice
```

## Feature 6: Navigation

```gherkin
Feature: App Navigation
  As a user
  I want to navigate through the app
  So that I can access different features

  Background:
    Given the app is launched

  # ─────────────────────────────────────────────────────────────
  # BASIC NAVIGATION
  # ─────────────────────────────────────────────────────────────

  Scenario: Navigate to list detail
    Given a vocabulary list "Navigation Test" exists
    When I click on the list "Navigation Test"
    Then I should be on the list detail page
    And I should see the list name in the title

  Scenario: Navigate back from list detail
    Given I am on the list detail page
    When I click the back button
    Then I should be on the home screen

  Scenario: Navigate to settings
    When I click the settings icon
    Then I should be on the settings screen

  Scenario: Navigate back from settings
    Given I am on the settings screen
    When I click the back button
    Then I should be on the home screen

  # ─────────────────────────────────────────────────────────────
  # QUIZ NAVIGATION
  # ─────────────────────────────────────────────────────────────

  Scenario: Start quiz from home screen
    Given a vocabulary list "Quiz List" exists with words
    When I click the quiz button for "Quiz List"
    Then I should be on the quiz screen

  Scenario: Cannot start quiz without words
    Given a vocabulary list "Empty List" exists with no words
    Then the quiz button should be disabled for "Empty List"

  Scenario: Exit quiz
    Given I am in a quiz
    When I click the back button
    Then I should see a confirmation dialog "Quitter le quiz ?"
    When I confirm
    Then I should be on the home screen
```

## Feature 7: Spaced Repetition System (SRS)

```gherkin
Feature: Spaced Repetition Learning
  As a language learner
  I want the app to schedule reviews intelligently
  So that I can learn efficiently

  # ─────────────────────────────────────────────────────────────
  # MASTERY TRACKING
  # ─────────────────────────────────────────────────────────────

  Scenario: Track word mastery
    Given a word "Bonjour" exists
    When I answer it correctly 3 times out of 4
    Then mastery level should be 75%
    And the word should be marked as "known"

  Scenario: Word becomes unknown
    Given "Bonjour" has mastery 72%
    When I answer it incorrectly
    Then mastery should drop below 70%
    And the word should be marked as "not known"

  # ─────────────────────────────────────────────────────────────
  # REVIEW SCHEDULING
  # ─────────────────────────────────────────────────────────────

  Scenario: Schedule next review after correct answer
    Given "Bonjour" has mastery 80%
    When I answer it correctly
    Then next review date should be calculated using SRS intervals
    And interval should be adjusted by mastery level

  Scenario: Schedule next review after incorrect answer
    Given "Bonjour" was due for review
    When I answer it incorrectly
    Then next review date should be tomorrow

  Scenario Outline: SRS review intervals
    Given a word with <correct_answers> correct out of <total>
    When I calculate the next review
    Then the base interval should be <days> days

    Examples:
      | correct_answers | total | days |
      | 1               | 1     | 1    |
      | 2               | 2     | 3    |
      | 3               | 3     | 7    |
      | 5               | 5     | 14   |
      | 8               | 8     | 30   |
      | 12              | 12    | 90   |

  # ─────────────────────────────────────────────────────────────
  # QUIZ SELECTION
  # ─────────────────────────────────────────────────────────────

  Scenario: Prioritize words due for review
    Given the following words exist:
      | word    | nextReview  | mastery |
      | Bonjour | yesterday   | 60%     |
      | Merci   | next week   | 80%     |
      | Salut   | today       | 50%     |
    When I start a quiz
    Then "Salut" should appear first (lowest mastery, due today)
    And "Bonjour" should appear second (overdue)
    And "Merci" should appear last

  Scenario: Include new words in quiz
    Given I have 20 words due for review
    And I have 10 new words never seen
    When I start a quiz of 20 questions
    Then up to 5 new words should be included
    And 15 review words should be included
```

## Feature 8: Progress Statistics

```gherkin
Feature: Learning Progress
  As a language learner
  I want to see my progress
  So that I can track my learning

  # ─────────────────────────────────────────────────────────────
  # LIST PROGRESS
  # ─────────────────────────────────────────────────────────────

  Scenario: View list progress on home screen
    Given a list "Test" with 20 words
    And 15 words have mastery >= 70%
    Then I should see "15 / 20" known words
    And I should see "75%" progress

  Scenario: Progress bar reflects mastery
    Given a list with 50% words known
    Then the progress bar should be filled to 50%

  # ─────────────────────────────────────────────────────────────
  # QUIZ RESULTS
  # ─────────────────────────────────────────────────────────────

  Scenario: View quiz score
    Given I completed a quiz with 8 correct out of 10
    Then I should see score "8 / 10"
    And I should see percentage "80%"
    And progress bar should show 80%

  Scenario Outline: Quality feedback based on score
    Given I completed a quiz with <percentage>% correct
    Then I should see feedback "<feedback>"

    Examples:
      | percentage | feedback     |
      | 95         | Excellent !  |
      | 90         | Très bien !  |
      | 85         | Bien !       |
      | 70         | Pas mal      |
      | 50         | À réviser    |
      | 30         | Incorrect    |
```

## Feature 9: Error Handling

```gherkin
Feature: Error Handling
  As a user
  I want clear error messages
  So that I can understand what went wrong

  Scenario: Audio generation fails
    Given the API is unavailable
    When I add a new word
    Then the word should be saved
    But I should see "Erreur de génération audio"
    And I should be able to retry later

  Scenario: Network error during quiz
    Given I am in a quiz
    When network connection is lost
    Then the quiz should continue with cached audio
    And progress should be saved locally

  Scenario: Database error
    Given there is a database error
    When I try to save data
    Then I should see an error message
    And the app should not crash

  Scenario: Speech recognition unavailable
    Given speech recognition is not available
    When I try to use speech mode
    Then I should see a message explaining the issue
    And I should be able to use text mode instead
```

---

## Summary

| Feature | Scenarios |
|---------|-----------|
| Vocabulary List Management | 8 |
| Word Management | 11 |
| Quiz Text Mode | 9 |
| Quiz Speech Mode | 5 |
| Settings | 7 |
| Navigation | 7 |
| SRS | 7 |
| Progress | 4 |
| Error Handling | 4 |
| **Total** | **62** |
