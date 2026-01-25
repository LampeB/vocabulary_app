import { When, Then } from '@cucumber/cucumber';
import { expect } from 'chai';
import { HomePage } from '../page-objects/HomePage';

/**
 * Step definitions for delete list functionality
 */

// When steps
When('I long press on the list {string}', async function(this: any, listName: string) {
    this.homePage = new HomePage(this.driver);
    await this.homePage.longPressOnList(listName);
});

When('I confirm the list deletion', async function(this: any) {
    this.homePage = new HomePage(this.driver);
    await this.homePage.confirmDeleteList();
});

When('I cancel the list deletion', async function(this: any) {
    this.homePage = new HomePage(this.driver);
    await this.homePage.cancelDeleteList();
});

// Then steps
Then('I should see the delete list confirmation dialog', async function(this: any) {
    this.homePage = new HomePage(this.driver);
    const isDisplayed = await this.homePage.isDeleteListDialogDisplayed();
    expect(isDisplayed).to.be.true;
});
