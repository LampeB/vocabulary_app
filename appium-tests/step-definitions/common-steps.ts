import { Given, When, Then } from '@cucumber/cucumber';
import { expect } from 'chai';
import { HomePage } from '../page-objects/HomePage';
import { CreateListDialog } from '../page-objects/CreateListDialog';
import { ListDetailPage } from '../page-objects/ListDetailPage';

/**
 * Common step definitions shared across features
 */

// Background steps
Given('the app is launched', async function(this: any) {
    // App is already launched in Before hook - no wait needed
});

Given('I am on the home screen', async function(this: any) {
    this.homePage = new HomePage(this.driver);
    await this.homePage.waitForPage();
});

// Navigation steps
When('I navigate back', async function(this: any) {
    await this.driver.back();
    // Wait for home screen to appear
    this.homePage = new HomePage(this.driver);
    await this.homePage.waitForPage();
});

// Verification steps
Then('I should see the page title {string}', async function(this: any, title: string) {
    const exists = await this.homePage.elementExistsByText(title);
    expect(exists).to.be.true;
});

Then('the home screen should be displayed', async function(this: any) {
    const isDisplayed = await this.homePage.isDisplayed();
    expect(isDisplayed).to.be.true;
});

Then('I should be on the home screen', async function(this: any) {
    this.homePage = new HomePage(this.driver);
    const isDisplayed = await this.homePage.isDisplayed();
    expect(isDisplayed).to.be.true;
});

Then('I should be on the list detail page', async function(this: any) {
    this.listDetailPage = new ListDetailPage(this.driver);
    // waitForPage already verifies the screen is displayed
    await this.listDetailPage.waitForPage();
});

// Screenshot steps
When('I take a screenshot', async function(this: any) {
    const timestamp = Date.now();
    await this.driver.saveScreenshot(`./screenshots/manual-${timestamp}.png`);
});
