Feature: Voice Input (STT) Quiz Interface
  As a language learner
  I want to see audio and input options on the quiz screen
  So that I can practice vocabulary effectively

  Background:
    Given the app is launched
    And I am on the home screen
    And a vocabulary list "STT Test" exists with words

  Scenario: Microphone button is visible on quiz screen
    When I start the quiz for list "STT Test"
    Then I should be on the quiz screen
    And I should see the microphone button

  Scenario: Audio playback button is visible on STT quiz screen
    When I start the quiz for list "STT Test"
    Then I should be on the quiz screen
    And I should see the audio playback button

  Scenario: User can answer via text input on STT quiz screen
    When I start the quiz for list "STT Test"
    And I enter the answer "test answer"
    And I submit my answer
    Then I should see feedback for my answer

  Scenario: Quiz completes successfully with STT screen
    When I start the quiz for list "STT Test"
    And I complete the quiz
    Then I should see the quiz results dialog
