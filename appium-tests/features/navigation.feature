Feature: App Navigation
  As a user
  I want to navigate through the app
  So that I can access different features

  Background:
    Given the app is launched
    And I am on the home screen

  Scenario: Navigate to list detail and back
    Given a vocabulary list "Navigation Test" exists
    When I click on the list "Navigation Test"
    Then I should be on the list detail page
    When I navigate back
    Then I should be on the home screen

  Scenario: Navigate to multiple lists
    Given a vocabulary list "List One" exists
    And a vocabulary list "List Two" exists
    When I click on the list "List One"
    Then I should be on the list detail page
    When I navigate back
    And I click on the list "List Two"
    Then I should be on the list detail page
    When I navigate back
    Then I should be on the home screen
