import { Given, Then } from '@cucumber/cucumber';
import { expect } from 'chai';
import { HomePage } from '../page-objects/HomePage';
import { ListDetailPage } from '../page-objects/ListDetailPage';
import { exec } from 'child_process';

const APP_PACKAGE = 'com.example.vocabulary_app';

/**
 * Execute a shell command and return a promise
 */
function execCommand(command: string): Promise<string> {
    return new Promise((resolve, reject) => {
        exec(command, (error, stdout, stderr) => {
            if (error) {
                reject(error);
            } else {
                resolve(stdout || stderr);
            }
        });
    });
}

// Given steps
Given('there are no vocabulary lists', async function(this: any) {
    // Clear app data to ensure empty state
    try {
        await execCommand(`adb shell pm clear ${APP_PACKAGE}`);
        // Wait for app to restart after clearing data
        await this.driver.pause(1000);
        // Relaunch the app
        await this.driver.activateApp(APP_PACKAGE);
        await this.driver.pause(500);
    } catch (error: any) {
        console.log(`Warning: Could not clear app data: ${error.message}`);
    }
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
