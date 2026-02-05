Feature: Voice Input (Speech-to-Text) for Quiz
  As a language learner
  I want to answer quiz questions using my voice
  So that I can practice pronunciation and answer hands-free

  Background:
    Given the app is launched
    And I am on the home screen
    And a vocabulary list "Voice Quiz" exists
    And I click on the list "Voice Quiz"
    And I add a word "bonjour" with translation "안녕하세요"
    And I navigate back

  # --- Microphone Button Visibility ---

  Scenario: Microphone button is visible on quiz screen
    When I start the quiz for list "Voice Quiz"
    Then I should be on the quiz screen
    And I should see the microphone button

  Scenario: Microphone button shows unavailable state on emulator
    When I start the quiz for list "Voice Quiz"
    Then I should be on the quiz screen
    And the microphone button should be in unavailable state
    And I should see a message indicating microphone is not available on emulator

  # --- Voice Input Flow (requires physical device with microphone) ---

  @physical-device
  Scenario: Start voice recognition by tapping microphone button
    When I start the quiz for list "Voice Quiz"
    And I tap the microphone button
    Then the microphone button should be in listening state
    And I should see a listening indicator

  @physical-device
  Scenario: Stop voice recognition manually
    When I start the quiz for list "Voice Quiz"
    And I tap the microphone button
    And the microphone button should be in listening state
    And I tap the microphone button to stop listening
    Then the microphone button should not be in listening state

  @physical-device
  Scenario: Voice input populates the answer field
    When I start the quiz for list "Voice Quiz"
    And I tap the microphone button
    And I speak the answer
    Then the answer field should contain the recognized text

  @physical-device
  Scenario: Answer is auto-validated when speech confidence is high
    When I start the quiz for list "Voice Quiz"
    And I tap the microphone button
    And I speak the correct answer with high confidence
    Then I should see correct feedback

  # --- Microphone Button Disabled States ---

  Scenario: Microphone button is disabled after answering
    When I start the quiz for list "Voice Quiz"
    And I enter the answer "test"
    And I submit my answer
    Then the microphone button should be disabled

  # --- Text Input Still Works ---

  Scenario: User can still answer via text input when microphone is unavailable
    When I start the quiz for list "Voice Quiz"
    And I enter the correct answer for "bonjour" and "안녕하세요"
    And I submit my answer
    Then I should see correct feedback

  # --- Answer Field Disabled During Listening ---

  @physical-device
  Scenario: Text input is disabled while listening
    When I start the quiz for list "Voice Quiz"
    And I tap the microphone button
    Then the answer text field should be disabled
