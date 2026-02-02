import { Given, Then } from '@cucumber/cucumber';
import { expect } from 'chai';
import { HomePage } from '../page-objects/HomePage';
import { ListDetailPage } from '../page-objects/ListDetailPage';

// Given steps
Given('there are no vocabulary lists', async function(this: any) {
    // Delete all existing lists through the UI to reach empty state.
    // We can't use pm clear / session reset because killing the app breaks
    // the Flutter Driver connection and it can't reconnect.
    const homePage = new HomePage(this.driver);
    await homePage.waitForPage();

    // Keep deleting lists until the empty state appears
    const MAX_LISTS = 20; // Safety limit
    for (let i = 0; i < MAX_LISTS; i++) {
        const hasLists = await homePage.elementExistsByKey('vocabulary_list_view');
        if (!hasLists) {
            break; // Empty state reached
        }

        // Find and delete the first list's delete button by looking for any delete_list_button_*
        // We use the delete icon button which triggers the confirmation dialog
        try {
            // Get the first list card and extract its name to build the delete button key
            // Since we can't easily enumerate, we'll use a different approach:
            // Click the first delete icon button found via type
            await homePage.clickFirstDeleteButton();
            await homePage.confirmDeleteList();
            await this.driver.pause(500); // Wait for list refresh
        } catch (e) {
            break; // No more lists to delete
        }
    }

    this.homePage = homePage;
});

// Then steps
Then('I should see the empty home screen message', async function(this: any) {
    this.homePage = new HomePage(this.driver);
    const isDisplayed = await this.homePage.isEmptyStateDisplayed();
    expect(isDisplayed).to.be.true;
});

Then('I should see the create list call to action', async function(this: any) {
    this.homePage = new HomePage(this.driver);
    const isDisplayed = await this.homePage.isEmptyStateMessageDisplayed();
    expect(isDisplayed).to.be.true;
});

Then('I should see the empty list message', async function(this: any) {
    this.listDetailPage = new ListDetailPage(this.driver);
    const isDisplayed = await this.listDetailPage.isEmptyStateDisplayed();
    expect(isDisplayed).to.be.true;
});

Then('I should see the add word call to action', async function(this: any) {
    this.listDetailPage = new ListDetailPage(this.driver);
    const isDisplayed = await this.listDetailPage.isEmptyMessageDisplayed();
    expect(isDisplayed).to.be.true;
});
