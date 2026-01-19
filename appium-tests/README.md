# Appium UI Tests with BDD + Page Object Model (TypeScript)

Automated UI testing for VocabApp using **Cucumber/Gherkin (BDD)** with **Page Object Model (POM)** pattern, written in **TypeScript**.

---

## 🎯 What's This?

Professional-grade UI tests combining:
- **TypeScript** - Type-safe, maintainable test code
- **Cucumber/Gherkin** - Readable, business-focused scenarios
- **Page Object Model** - Maintainable, reusable code architecture
- **Appium** - Cross-platform test automation
- **Flutter Driver** - Native Flutter widget interaction

---

## ⚡ Quick Start

### 1. Setup (One-Time)

```powershell
cd appium-tests
npm install
```

### 2. Build App

```powershell
cd ../vocabulary_app
flutter build apk --debug --target=lib/main_appium.dart
```

### 3. Run Tests

**Terminal 1 - Start Appium:**
```powershell
cd appium-tests
.\start-appium.ps1
```

**Terminal 2 - Run Tests:**
```powershell
npm test                    # All tests
npm run test:android        # Android only
npm run test:report         # With HTML report
```

---

## 📁 Project Structure

```
appium-tests/
├── features/                   # 🥒 Gherkin scenarios (WHAT to test)
│   ├── vocabulary-lists.feature
│   └── navigation.feature
│
├── step-definitions/           # 🔗 Step implementations (glue code - TypeScript)
│   ├── hooks.ts
│   ├── common-steps.ts
│   ├── vocabulary-list-steps.ts
│   └── navigation-steps.ts
│
├── page-objects/               # 📄 Page Objects (HOW to test - TypeScript)
│   ├── BasePage.ts
│   ├── HomePage.ts
│   ├── CreateListDialog.ts
│   └── ListDetailPage.ts
│
├── reports/                    # 📊 Test reports (HTML/JSON/XML)
├── screenshots/                # 📸 Screenshots
├── tsconfig.json              # ⚙️ TypeScript configuration
└── BDD_POM_GUIDE.md           # 📚 Complete guide
```

---

## 📝 Example Test

### Gherkin Feature (Human-Readable)
```gherkin
Feature: Vocabulary List Management
  Scenario: Create a new list
    Given I am on the home screen
    When I click the add list button
    And I enter list name "French Basics"
    And I click the create button
    Then I should see the list "French Basics" on the home screen
```

### Page Object (Reusable Code - TypeScript)
```typescript
export class HomePage extends BasePage {
    async clickAddListButton(): Promise<void> {
        await this.clickByAccessibilityId('add_list_button');
    }

    async listExists(name: string): Promise<boolean> {
        return await this.elementExistsByText(name);
    }
}
```

### Step Definition (Glue Code - TypeScript)
```typescript
When('I click the add list button', async function(this: any) {
    this.homePage = new HomePage(this.driver);
    await this.homePage.clickAddListButton();
});
```

---

## 🎨 Key Features

### ✅ Included Test Scenarios

**Vocabulary Lists:**
- View home screen
- Create new list
- Create multiple lists
- Cancel list creation
- Navigate to list detail
- Navigate back

**Navigation:**
- Navigate through screens
- Deep navigation
- Multiple list navigation
- State preservation

### ✅ Page Objects

- **BasePage** - Common methods for all pages
- **HomePage** - Main screen interactions
- **CreateListDialog** - List creation dialog
- **ListDetailPage** - Detail screen

---

## 📚 Documentation

| Document | Purpose |
|----------|---------|
| **[BDD_POM_GUIDE.md](BDD_POM_GUIDE.md)** | Complete BDD & POM guide |
| **[BDD_POM_COMPLETE.md](../BDD_POM_COMPLETE.md)** | Setup summary |
| **[APPIUM_SETUP_COMPLETE.md](../APPIUM_SETUP_COMPLETE.md)** | Original Appium setup |

---

## 🚀 Running Tests

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

### Generate Reports
```bash
npm run test:report
# View: reports/cucumber-report.html
```

---

## 🔧 Adding New Tests

### 1. Write Gherkin Scenario

**File:** `features/my-feature.feature`
```gherkin
Scenario: Do something
  Given I am on the home screen
  When I perform an action
  Then I see the result
```

### 2. Create/Update Page Object

**File:** `page-objects/MyPage.ts`
```typescript
import { BasePage } from './BasePage';
import { Browser } from 'webdriverio';

export class MyPage extends BasePage {
    constructor(driver: Browser) {
        super(driver);
    }

    async performAction(): Promise<void> {
        await this.clickByText('Action Button');
    }
}
```

### 3. Implement Steps

**File:** `step-definitions/my-steps.ts`
```typescript
import { When } from '@cucumber/cucumber';
import { MyPage } from '../page-objects/MyPage';

When('I perform an action', async function(this: any) {
    this.myPage = new MyPage(this.driver);
    await this.myPage.performAction();
});
```

---

## 🆚 Why BDD + POM?

### Before
```javascript
// Hard to read, mixed concerns
it('should create list', async () => {
    const btn = await driver.elementByAccessibilityId('add_btn');
    await btn.click();
    const field = await driver.elementByAccessibilityId('name');
    await field.sendKeys('List');
    // ...
});
```

### After
```gherkin
Scenario: Create a list
  When I create a list called "List"
  Then I should see "List" in my lists
```

Benefits:
- ✅ Readable by non-technical people
- ✅ Reusable code (page objects)
- ✅ Easy to maintain
- ✅ Separated concerns

---

## 🐛 Troubleshooting

| Issue | Solution |
|-------|----------|
| "Undefined step" | Implement step in step definition file |
| "Page object undefined" | Initialize: `this.homePage = new HomePage(this.driver)` |
| "Element not found" | Add accessibility IDs to Flutter widgets |
| "Timeout" | Increase timeout or add `await this.pause()` |

---

## 📊 Test Reports

After running tests:
- **HTML**: `reports/cucumber-report.html` (human-readable)
- **JSON**: `reports/cucumber-report.json` (for CI/CD)
- **XML**: `reports/cucumber-report.xml` (for Jenkins)

---

## 🎓 Resources

- **TypeScript**: https://www.typescriptlang.org/docs/
- **Cucumber**: https://cucumber.io/docs/cucumber/
- **Gherkin**: https://cucumber.io/docs/gherkin/
- **Page Objects**: https://martinfowler.com/bliki/PageObject.html
- **Appium**: https://appium.io/docs/
- **WebdriverIO**: https://webdriver.io/

---

## ✅ Summary

You have:
- ✅ **TypeScript** - Type-safe, maintainable test code
- ✅ **Cucumber/Gherkin** BDD framework
- ✅ **Page Object Model** architecture
- ✅ 8+ ready-to-run scenarios
- ✅ 4 page object classes (all TypeScript)
- ✅ HTML/JSON/XML reporting
- ✅ Complete documentation

**Happy BDD Testing with TypeScript! 🥒🧪**
