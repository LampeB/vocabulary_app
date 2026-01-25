import { Given, When, Then } from '@cucumber/cucumber';
import { expect } from 'chai';
import { HomePage } from '../page-objects/HomePage';
import { CreateListDialog } from '../page-objects/CreateListDialog';
import { ListDetailPage } from '../page-objects/ListDetailPage';

/**
 * Step definitions for vocabulary list management
 */

// Given steps
Given('a vocabulary list {string} exists', async function(this: any, listName: string) {
    this.homePage = new HomePage(this.driver);
    this.createListDialog = new CreateListDialog(this.driver);

    // Quick check if list already exists
    const exists = await this.homePage.listExists(listName);

    if (!exists) {
        // Create the list - no need to verify after, dialog closes on success
        await this.homePage.clickAddListButton();
        await this.createListDialog.createSimpleList(listName);
    }
    // Skip redundant verification - if creation failed, next step will catch it
});

// When steps
When('I click the add list button', async function(this: any) {
    this.homePage = new HomePage(this.driver);
    await this.homePage.clickAddListButton();
});

When('I enter list name {string}', async function(this: any, name: string) {
    this.createListDialog = new CreateListDialog(this.driver);
    await this.createListDialog.enterListName(name);
});

When('I click the create button', async function(this: any) {
    this.createListDialog = new CreateListDialog(this.driver);
    await this.createListDialog.clickCreate();
});

When('I click the cancel button', async function(this: any) {
    this.createListDialog = new CreateListDialog(this.driver);
    await this.createListDialog.clickCancel();
});

When('I click on the list {string}', async function(this: any, listName: string) {
    this.homePage = new HomePage(this.driver);
    await this.homePage.clickListByName(listName);
});

When('I create a vocabulary list with name {string}', async function(this: any, name: string) {
    this.homePage = new HomePage(this.driver);
    this.createListDialog = new CreateListDialog(this.driver);

    await this.homePage.clickAddListButton();
    await this.createListDialog.createSimpleList(name);
});

// Then steps
Then('I should see the create list dialog', async function(this: any) {
    this.createListDialog = new CreateListDialog(this.driver);
    await this.createListDialog.waitForDialog();
    const isDisplayed = await this.createListDialog.isDisplayed();
    expect(isDisplayed).to.be.true;
});

Then('I should see the list {string} on the home screen', async function(this: any, listName: string) {
    this.homePage = new HomePage(this.driver);
    const exists = await this.homePage.listExists(listName);
    expect(exists).to.be.true;
});

Then('I should not see the list {string} on the home screen', async function(this: any, listName: string) {
    this.homePage = new HomePage(this.driver);
    const exists = await this.homePage.listExists(listName);
    expect(exists).to.be.false;
});

Then('I should see the add word button', async function(this: any) {
    this.listDetailPage = new ListDetailPage(this.driver);
    const exists = await this.listDetailPage.elementExistsByKey('add_word_button');
    expect(exists).to.be.true;
});

Then('the list name {string} should be displayed', async function(this: any, listName: string) {
    const exists = await this.listDetailPage.elementExistsByText(listName);
    expect(exists).to.be.true;
});
