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
    // App is already launched in Before hook
    await this.driver.pause(2000);
});

Given('I am on the home screen', async function(this: any) {
    this.homePage = new HomePage(this.driver);

    try {
        console.log('Waiting for home screen...');
        await this.homePage.waitForPage();
        console.log('Home screen loaded!');
        const isDisplayed = await this.homePage.isDisplayed();
        expect(isDisplayed).to.be.true;
    } catch (error: any) {
        console.log('Error waiting for home screen:', error.message);
        // Note: getPageSource() and saveScreenshot() are not implemented in Flutter Driver
        throw error;
    }
});

// Navigation steps
When('I navigate back', async function(this: any) {
    await this.driver.back();
    await this.driver.pause(1000);
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
    await this.listDetailPage.waitForPage();
    const isDisplayed = await this.listDetailPage.isDisplayed();
    expect(isDisplayed).to.be.true;
});

// Screenshot steps
When('I take a screenshot', async function(this: any) {
    const timestamp = Date.now();
    await this.driver.saveScreenshot(`./screenshots/manual-${timestamp}.png`);
});
