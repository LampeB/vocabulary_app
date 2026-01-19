Feature: Smoke Test
  Basic smoke test to verify Appium Flutter Driver connection

  Scenario: Launch app and verify home screen
    Given the app is launched
    And I am on the home screen
    Then the home screen should be displayed
