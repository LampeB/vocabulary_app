Feature: Empty States
  As a user
  I want to see helpful messages when there's no content
  So that I know what to do next

  Background:
    Given the app is launched

  Scenario: Empty home screen shows helpful message
    Given there are no vocabulary lists
    And I am on the home screen
    Then I should see the empty home screen message
    And I should see the create list call to action

  Scenario: Empty list detail shows helpful message
    Given I am on the home screen
    And a vocabulary list "Empty List" exists
    When I click on the list "Empty List"
    Then I should see the empty list message
    And I should see the add word call to action
