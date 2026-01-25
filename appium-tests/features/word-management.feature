Feature: Word Management
  As a language learner
  I want to add and manage words in my vocabulary lists
  So that I can build my vocabulary

  Background:
    Given the app is launched
    And I am on the home screen

  # === AJOUT DE MOTS ===

  Scenario: Add a word to a list
    Given a vocabulary list "Word Test" exists
    When I click on the list "Word Test"
    Then I should be on the list detail page
    When I click the add word button
    Then I should see the add word dialog
    When I enter the French word "bonjour"
    And I enter the Korean word "안녕하세요"
    And I click the add word confirm button
    Then I should see the word "bonjour" in the word list

  Scenario: Cancel adding a word
    Given a vocabulary list "Cancel Test" exists
    When I click on the list "Cancel Test"
    And I click the add word button
    And I enter the French word "temporaire"
    And I cancel adding the word
    Then I should not see the word "temporaire" in the word list

  # === SUPPRESSION DE MOTS ===

  Scenario: Delete a word from a list
    Given a vocabulary list "Delete Word Test" exists
    And I click on the list "Delete Word Test"
    And I add a word "supprimer" with translation "삭제"
    Then I should see the word "supprimer" in the word list
    When I click the delete button for word "supprimer"
    Then I should see the delete word confirmation dialog
    When I confirm the word deletion
    Then I should not see the word "supprimer" in the word list

  Scenario: Cancel word deletion
    Given a vocabulary list "Keep Word Test" exists
    And I click on the list "Keep Word Test"
    And I add a word "garder" with translation "유지"
    When I click the delete button for word "garder"
    And I cancel the word deletion
    Then I should see the word "garder" in the word list
