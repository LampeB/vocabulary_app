Feature: Quiz Mode
  As a language learner
  I want to practice vocabulary with quizzes
  So that I can memorize words effectively

  Background:
    Given the app is launched
    And I am on the home screen

  Scenario: Start a quiz
    Given a vocabulary list "Quiz List" exists
    And I click on the list "Quiz List"
    And I add a word "test" with translation "테스트"
    And I navigate back
    When I start the quiz for list "Quiz List"
    Then I should be on the quiz screen
    And I should see a word to translate

  Scenario: Answer a question correctly
    Given a vocabulary list "Correct Answer" exists
    And I click on the list "Correct Answer"
    And I add a word "bonjour" with translation "안녕하세요"
    And I navigate back
    When I start the quiz for list "Correct Answer"
    And I enter the answer "안녕하세요"
    And I submit my answer
    Then I should see correct feedback

  Scenario: Answer a question incorrectly
    Given a vocabulary list "Wrong Answer" exists
    And I click on the list "Wrong Answer"
    And I add a word "merci" with translation "감사합니다"
    And I navigate back
    When I start the quiz for list "Wrong Answer"
    And I enter the answer "wrong answer"
    And I submit my answer
    Then I should see incorrect feedback

  Scenario: Complete a quiz and see results
    Given a vocabulary list "Complete Quiz" exists
    And I click on the list "Complete Quiz"
    And I add a word "oui" with translation "네"
    And I navigate back
    When I start the quiz for list "Complete Quiz"
    And I complete the quiz
    Then I should see the quiz results dialog
