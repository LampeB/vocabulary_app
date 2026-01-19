Feature: Vocabulary List Management
  As a language learner
  I want to manage my vocabulary lists
  So that I can organize words I'm learning

  Background:
    Given the app is launched
    And I am on the home screen

  Scenario: View home screen
    Then I should see the page title "Mes Listes"

  Scenario: Create a new vocabulary list
    When I click the add list button
    Then I should see the create list dialog
    When I enter list name "French Basics"
    And I click the create button
    Then I should see the list "French Basics" on the home screen

  Scenario: Cancel creating a list
    When I click the add list button
    And I enter list name "Temporary List"
    And I click the cancel button
    Then I should not see the list "Temporary List" on the home screen
