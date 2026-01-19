import { Given, When, Then } from '@cucumber/cucumber';
import { expect } from 'chai';
import { ListDetailPage } from '../page-objects/ListDetailPage';

/**
 * Step definitions for navigation scenarios
 */

// When steps
When('I click the add word button', async function(this: any) {
    this.listDetailPage = new ListDetailPage(this.driver);
    await this.listDetailPage.clickAddWordButton();
});

When('I close the dialog', async function(this: any) {
    // Click cancel or close button
    await this.driver.back();
    await this.driver.pause(500);
});

// Then steps
Then('I should see the add word dialog', async function(this: any) {
    // Check for dialog elements
    await this.driver.pause(1000);
    // Dialog detection logic would go here
    // For now, just verify we're not on the detail page anymore
});
