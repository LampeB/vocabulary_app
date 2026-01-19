# BDD + Page Object Model (POM) Guide

Complete guide for Appium testing with Cucumber/Gherkin and Page Object Model pattern.

---

## 📚 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Project Structure](#project-structure)
- [Quick Start](#quick-start)
- [Writing Tests](#writing-tests)
- [Page Objects](#page-objects)
- [Gherkin Features](#gherkin-features)
- [Step Definitions](#step-definitions)
- [Best Practices](#best-practices)

---

## Overview

### What is BDD?

**Behavior-Driven Development (BDD)** uses natural language to describe application behavior:
- Tests are written in plain English (Gherkin syntax)
- Readable by non-technical stakeholders
- Focuses on user behavior and business value

### What is Page Object Model?

**Page Object Model (POM)** is a design pattern that:
- Creates an object repository for web/app elements
- Separates test logic from page structure
- Reduces code duplication
- Makes tests easier to maintain

### Why Use Both?

```
Gherkin (WHAT to test) + POM (HOW to test) = Maintainable, Readable Tests
```

---

## Architecture

```
┌─────────────────────────────────────────────────────┐
│             Gherkin Feature Files                   │
│          (Business-readable scenarios)              │
└──────────────────┬──────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────┐
│           Step Definitions                          │
│        (Glue code - connects features to code)      │
└──────────────────┬──────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────┐
│            Page Objects                             │
│      (Encapsulate page elements & actions)          │
└──────────────────┬──────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────┐
│         Appium/WebDriverIO                          │
│         (Interact with app)                         │
└─────────────────────────────────────────────────────┘
```

---

## Project Structure

```
appium-tests/
├── features/                      # Gherkin feature files
│   ├── vocabulary-lists.feature   # List management scenarios
│   └── navigation.feature         # Navigation scenarios
│
├── step-definitions/              # Step implementation
│   ├── hooks.js                   # Before/After hooks
│   ├── common-steps.js            # Shared steps
│   ├── vocabulary-list-steps.js   # List-specific steps
│   └── navigation-steps.js        # Navigation steps
│
├── page-objects/                  # Page Object classes
│   ├── BasePage.js                # Base class with common methods
│   ├── HomePage.js                # Home screen POM
│   ├── CreateListDialog.js        # Dialog POM
│   └── ListDetailPage.js          # Detail screen POM
│
├── reports/                       # Test reports
│   ├── cucumber-report.html
│   ├── cucumber-report.json
│   └── cucumber-report.xml
│
├── screenshots/                   # Screenshots (failures, manual)
│
├── cucumber.js                    # Cucumber configuration
├── package.json                   # Dependencies & scripts
└── BDD_POM_GUIDE.md              # This file
```

---

## Quick Start

### 1. Install Dependencies

```bash
cd appium-tests
npm install
```

###  2. Build App

```bash
cd ../vocabulary_app
flutter build apk --debug --target=lib/main_appium.dart
```

### 3. Start Appium

**Terminal 1:**
```bash
cd appium-tests
.\start-appium.ps1
```

### 4. Run Tests

**Terminal 2:**
```bash
cd appium-tests

# Run all tests
npm test

# Run Android tests
npm run test:android

# Generate HTML report
npm run test:report
```

---

## Writing Tests

### 1. Write Feature File (Gherkin)

**File:** `features/my-feature.feature`

```gherkin
Feature: My Feature
  As a user
  I want to do something
  So that I achieve a goal

  Scenario: Do something useful
    Given I am on the home screen
    When I click the button
    Then I should see the result
```

### 2. Create Page Object

**File:** `page-objects/MyPage.js`

```javascript
const BasePage = require('./BasePage');

class MyPage extends BasePage {
    constructor(driver) {
        super(driver);
        this.selectors = {
            myButton: 'my_button_id',
            resultText: 'Result Text'
        };
    }

    async clickMyButton() {
        await this.clickByAccessibilityId(this.selectors.myButton);
    }

    async getResultText() {
        return await this.findByText(this.selectors.resultText);
    }
}

module.exports = MyPage;
```

### 3. Write Step Definitions

**File:** `step-definitions/my-steps.js`

```javascript
const { Given, When, Then } = require('@cucumber/cucumber');
const { expect } = require('chai');
const MyPage = require('../page-objects/MyPage');

When('I click the button', async function() {
    this.myPage = new MyPage(this.driver);
    await this.myPage.clickMyButton();
});

Then('I should see the result', async function() {
    const result = await this.myPage.getResultText();
    expect(result).to.exist;
});
```

---

## Page Objects

### Base Page

All page objects extend `BasePage`:

```javascript
const BasePage = require('./BasePage');

class MyPage extends BasePage {
    constructor(driver) {
        super(driver);
    }
}
```

### Available Methods

| Method | Description | Example |
|--------|-------------|---------|
| `findByText(text)` | Find element by text | `await this.findByText('Hello')` |
| `findByAccessibilityId(id)` | Find by ID | `await this.findByAccessibilityId('btn_id')` |
| `clickByText(text)` | Click element | `await this.clickByText('Submit')` |
| `enterText(element, text)` | Type text | `await this.enterText(field, 'Hello')` |
| `pause(ms)` | Wait | `await this.pause(2000)` |
| `goBack()` | Navigate back | `await this.goBack()` |
| `takeScreenshot(name)` | Screenshot | `await this.takeScreenshot('test.png')` |

### Example: HomePage

```javascript
class HomePage extends BasePage {
    constructor(driver) {
        super(driver);
        this.selectors = {
            title: 'Listes de vocabulaire',
            addButton: 'add_list_button'
        };
    }

    async clickAddButton() {
        await this.clickByAccessibilityId(this.selectors.addButton);
    }

    async isDisplayed() {
        return await this.elementExistsByText(this.selectors.title);
    }
}
```

---

## Gherkin Features

### Feature Structure

```gherkin
Feature: Feature Name
  Description of the feature
  Can span multiple lines

  Background:
    Given common setup step
    And another common step

  Scenario: Scenario name
    Given precondition
    When action
    Then expected result

  Scenario Outline: Parameterized scenario
    Given I have "<value>"
    When I do "<action>"
    Then I see "<result>"

    Examples:
      | value | action | result |
      | A     | X      | 1      |
      | B     | Y      | 2      |
```

### Gherkin Keywords

- **Feature**: Describes the feature being tested
- **Scenario**: Individual test case
- **Background**: Steps run before each scenario
- **Given**: Preconditions/setup
- **When**: Actions/events
- **Then**: Expected outcomes
- **And/But**: Additional steps
- **Scenario Outline**: Template for multiple scenarios
- **Examples**: Data for scenario outlines

### Example Feature

```gherkin
Feature: User Login
  As a user
  I want to log in
  So that I can access my account

  Scenario: Successful login
    Given I am on the login screen
    When I enter username "user@example.com"
    And I enter password "password123"
    And I click the login button
    Then I should be logged in
    And I should see my dashboard

  Scenario: Failed login
    Given I am on the login screen
    When I enter invalid credentials
    And I click the login button
    Then I should see an error message
    And I should remain on the login screen
```

---

## Step Definitions

### Basic Pattern

```javascript
const { Given, When, Then } = require('@cucumber/cucumber');
const { expect } = require('chai');

Given('I am on the login screen', async function() {
    // Setup code
    this.loginPage = new LoginPage(this.driver);
    await this.loginPage.waitForPage();
});

When('I enter username {string}', async function(username) {
    // Action code
    await this.loginPage.enterUsername(username);
});

Then('I should see my dashboard', async function() {
    // Assertion code
    const isVisible = await this.dashboardPage.isDisplayed();
    expect(isVisible).to.be.true;
});
```

### Context/World

Access driver and share data between steps:

```javascript
When('I create a list', async function() {
    // Access driver
    this.driver.pause(1000);

    // Store data for later steps
    this.createdListName = 'My List';
});

Then('the list should exist', async function() {
    // Use stored data
    const exists = await this.homePage.listExists(this.createdListName);
    expect(exists).to.be.true;
});
```

### Hooks

Setup and teardown:

```javascript
const { Before, After } = require('@cucumber/cucumber');

Before(async function() {
    // Runs before each scenario
    this.driver = await createDriver();
});

After(async function({ result }) {
    // Runs after each scenario
    if (result.status === 'FAILED') {
        await takeScreenshot();
    }
    await this.driver.deleteSession();
});
```

---

## Best Practices

### Feature Files

✅ **DO:**
- Write from user perspective
- Use business language, not technical terms
- Keep scenarios focused (one behavior per scenario)
- Use descriptive scenario names
- Group related scenarios in one feature

❌ **DON'T:**
- Write implementation details
- Make scenarios too long
- Duplicate scenarios
- Use technical jargon

### Example

**Good:**
```gherkin
Scenario: User creates a vocabulary list
  When I create a new list called "French Verbs"
  Then the list should appear on my homepage
```

**Bad:**
```gherkin
Scenario: Click button and check database
  When I click element with ID "btn_123"
  Then the database table "lists" should have 1 row
```

### Page Objects

✅ **DO:**
- One page object per screen/dialog
- Use meaningful method names
- Return values for verification
- Add comments for complex logic
- Keep selectors centralized

❌ **DON'T:**
- Put assertions in page objects
- Make page objects too large
- Hard-code waits everywhere
- Duplicate methods across pages

### Step Definitions

✅ **DO:**
- Reuse steps across features
- Use parameters for flexibility
- Keep steps simple
- One action per step (mostly)
- Use meaningful variable names

❌ **DON'T:**
- Put too much logic in steps
- Make steps too generic
- Ignore failures
- Skip assertions

---

## Running Tests

### All Tests
```bash
npm test
```

### Specific Feature
```bash
npx cucumber-js features/vocabulary-lists.feature
```

### Specific Scenario
```bash
npx cucumber-js features/vocabulary-lists.feature:10
```
(Line 10 is where scenario starts)

### With Tags
```bash
npx cucumber-js --tags "@smoke"
```

### Generate Reports
```bash
npm run test:report
```

Reports are saved in `reports/` directory.

---

## Troubleshooting

### Step Not Found

**Error:** `Undefined step: "I click the button"`

**Solution:** Implement the step in a step definition file:
```javascript
When('I click the button', async function() {
    // implementation
});
```

### Page Object Not Working

**Error:** `Cannot read property 'clickButton' of undefined`

**Solution:** Initialize page object in step:
```javascript
this.myPage = new MyPage(this.driver);
await this.myPage.clickButton();
```

### Timeout Issues

**Error:** `Step timeout exceeded`

**Solution:**
- Increase timeout in `cucumber.js`
- Add explicit waits in page objects
- Check if element exists before interacting

---

## Example: Complete Flow

### 1. Feature File

```gherkin
Feature: Create List
  Scenario: Create a new list
    Given I am on the home screen
    When I create a list called "Spanish"
    Then I should see "Spanish" in my lists
```

### 2. Page Object

```javascript
class HomePage extends BasePage {
    async createList(name) {
        await this.clickByAccessibilityId('add_button');
        await this.enterText(await this.findByAccessibilityId('name_field'), name);
        await this.clickByText('Create');
    }

    async listExists(name) {
        return await this.elementExistsByText(name);
    }
}
```

### 3. Step Definition

```javascript
When('I create a list called {string}', async function(name) {
    this.homePage = new HomePage(this.driver);
    await this.homePage.createList(name);
});

Then('I should see {string} in my lists', async function(name) {
    const exists = await this.homePage.listExists(name);
    expect(exists).to.be.true;
});
```

---

## Resources

- **Cucumber Docs**: https://cucumber.io/docs/cucumber/
- **Gherkin Reference**: https://cucumber.io/docs/gherkin/reference/
- **Page Object Pattern**: https://martinfowler.com/bliki/PageObject.html
- **Chai Assertions**: https://www.chaijs.com/api/bdd/

---

## Summary

✅ **You now have:**
- BDD tests with Gherkin syntax
- Page Object Model architecture
- Reusable step definitions
- Organized, maintainable tests
- HTML/JSON/XML test reports

**Happy Testing! 🥒🧪**
