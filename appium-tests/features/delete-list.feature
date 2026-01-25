Feature: Delete Vocabulary List
  As a language learner
  I want to delete vocabulary lists I no longer need
  So that I can keep my app organized

  Background:
    Given the app is launched
    And I am on the home screen

  Scenario: Delete a list via long press
    Given a vocabulary list "To Delete" exists
    When I long press on the list "To Delete"
    Then I should see the delete list confirmation dialog
    When I confirm the list deletion
    Then I should not see the list "To Delete" on the home screen

  Scenario: Cancel list deletion
    Given a vocabulary list "Keep This" exists
    When I long press on the list "Keep This"
    And I cancel the list deletion
    Then I should see the list "Keep This" on the home screen
