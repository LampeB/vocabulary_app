import { Given, Then } from '@cucumber/cucumber';
import { expect } from 'chai';
import { HomePage } from '../page-objects/HomePage';
import { ListDetailPage } from '../page-objects/ListDetailPage';
import { resetSession } from './hooks';

// Given steps
Given('there are no vocabulary lists', async function(this: any) {
    // Clear all app data and relaunch for a guaranteed empty state
    // The HomeScreen now has a WidgetsBindingObserver that reloads data on app resume
    this.driver = await resetSession();
    this.homePage = new HomePage(this.driver);
    await this.homePage.waitForPage();
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
