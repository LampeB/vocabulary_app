Feature: Audio Playback
  As a language learner
  I want to hear the pronunciation of words
  So that I can learn correct pronunciation

  Background:
    Given the app is launched
    And I am on the home screen

  # === LIST DETAIL AUDIO ===

  Scenario: Audio buttons are visible on word cards
    Given a vocabulary list "Audio Test" exists
    When I click on the list "Audio Test"
    And I add a word "bonjour" with translation "안녕하세요"
    Then I should see the audio button for word "bonjour" in language 1
    And I should see the audio button for word "bonjour" in language 2

  Scenario: Play audio for language 1 word
    Given a vocabulary list "Audio Lang1" exists
    And I click on the list "Audio Lang1"
    And I add a word "merci" with translation "감사합니다"
    When I click the audio button for word "merci" in language 1
    Then the audio should play without error

  Scenario: Play audio for language 2 word
    Given a vocabulary list "Audio Lang2" exists
    And I click on the list "Audio Lang2"
    And I add a word "salut" with translation "안녕"
    When I click the audio button for word "salut" in language 2
    Then the audio should play without error

  # === QUIZ AUDIO ===

  Scenario: Audio button is visible in quiz
    Given a vocabulary list "Quiz Audio" exists
    And I click on the list "Quiz Audio"
    And I add a word "oui" with translation "네"
    And I navigate back
    When I start the quiz for list "Quiz Audio"
    Then I should see the quiz audio button

  Scenario: Play audio in quiz
    Given a vocabulary list "Quiz Audio Play" exists
    And I click on the list "Quiz Audio Play"
    And I add a word "non" with translation "아니요"
    And I navigate back
    When I start the quiz for list "Quiz Audio Play"
    And I click the quiz audio button
    Then the audio should play without error
