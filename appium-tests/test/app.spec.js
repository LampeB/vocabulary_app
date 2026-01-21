const { expect } = require('chai');

describe('VocabApp - Main Flow', () => {
    it('should launch the app successfully', async () => {
        await driver.pause(3000); // Wait for app to fully load

        // Find element by text (Flutter widget)
        const titleElement = await driver.elementByText('Listes de vocabulaire');
        expect(titleElement).to.exist;

        console.log('✓ App launched successfully');
    });

    it('should display the home screen with add button', async () => {
        // Find the floating action button (FAB) for adding new lists
        const addButton = await driver.elementByAccessibilityId('add_list_button');
        expect(addButton).to.exist;

        console.log('✓ Add button found on home screen');
    });

    it('should be able to tap on add button', async () => {
        const addButton = await driver.elementByAccessibilityId('add_list_button');
        await addButton.click();
        await driver.pause(1000);

        // Verify dialog appears
        const dialogTitle = await driver.elementByText('Nouvelle liste');
        expect(dialogTitle).to.exist;

        console.log('✓ Add list dialog opened');

        // Close dialog
        const cancelButton = await driver.elementByText('Annuler');
        await cancelButton.click();
        await driver.pause(500);
    });

    it('should create a new vocabulary list', async () => {
        // Open add dialog
        const addButton = await driver.elementByAccessibilityId('add_list_button');
        await addButton.click();
        await driver.pause(1000);

        // Enter list name
        const nameField = await driver.elementByAccessibilityId('list_name_field');
        await nameField.sendKeys('Appium Test List');

        // Enter description
        const descField = await driver.elementByAccessibilityId('list_description_field');
        await descField.sendKeys('Created by Appium automated test');

        // Submit
        const createButton = await driver.elementByText('Créer');
        await createButton.click();
        await driver.pause(2000);

        // Verify list appears
        const listItem = await driver.elementByText('Appium Test List');
        expect(listItem).to.exist;

        console.log('✓ New vocabulary list created');
    });

    it('should navigate to list detail screen', async () => {
        // Tap on the list we just created
        const listItem = await driver.elementByText('Appium Test List');
        await listItem.click();
        await driver.pause(2000);

        // Verify we're on detail screen (check for FAB to add words)
        const addWordButton = await driver.elementByAccessibilityId('add_word_button');
        expect(addWordButton).to.exist;

        console.log('✓ Navigated to list detail screen');

        // Go back to home
        await driver.back();
        await driver.pause(1000);
    });
});

describe('VocabApp - Navigation', () => {
    it('should navigate through the app correctly', async () => {
        // Start from home
        const homeTitle = await driver.elementByText('Listes de vocabulaire');
        expect(homeTitle).to.exist;

        // Find a list (assuming "Appium Test List" exists from previous test)
        const listItem = await driver.elementByText('Appium Test List');
        await listItem.click();
        await driver.pause(1500);

        // Verify detail screen
        const addWordButton = await driver.elementByAccessibilityId('add_word_button');
        expect(addWordButton).to.exist;

        // Navigate back
        await driver.back();
        await driver.pause(1000);

        // Verify we're back on home
        const homeTitleAgain = await driver.elementByText('Listes de vocabulaire');
        expect(homeTitleAgain).to.exist;

        console.log('✓ Navigation flow working correctly');
    });
});

describe('VocabApp - UI Elements', () => {
    it('should find and interact with UI elements', async () => {
        await driver.pause(2000);

        // Scroll to see if there are multiple lists
        try {
            await driver.execute('flutter:scrollUntilVisible', {
                scrollView: 'ListView',
                item: 'Appium Test List',
                scrollDirection: 'down',
                delta: 100
            });
            console.log('✓ Scroll functionality works');
        } catch (error) {
            console.log('Note: Scroll not needed or list visible');
        }

        // Take a screenshot
        await driver.saveScreenshot('./screenshots/home-screen.png');
        console.log('✓ Screenshot saved');
    });
});
