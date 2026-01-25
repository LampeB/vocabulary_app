import { Given, When, Then } from '@cucumber/cucumber';
import { expect } from 'chai';
import { ListDetailPage } from '../page-objects/ListDetailPage';

/**
 * Step definitions for word management
 */

// When steps
When('I click the add word button', async function(this: any) {
    this.listDetailPage = new ListDetailPage(this.driver);
    await this.listDetailPage.clickAddWordButton();
});

When('I enter the French word {string}', async function(this: any, word: string) {
    this.listDetailPage = new ListDetailPage(this.driver);
    await this.listDetailPage.enterFrenchWord(word);
});

When('I enter the Korean word {string}', async function(this: any, word: string) {
    this.listDetailPage = new ListDetailPage(this.driver);
    await this.listDetailPage.enterKoreanWord(word);
});

When('I click the add word confirm button', async function(this: any) {
    this.listDetailPage = new ListDetailPage(this.driver);
    await this.listDetailPage.confirmAddWord();
});

When('I add a word {string} with translation {string}', async function(this: any, word: string, translation: string) {
    this.listDetailPage = new ListDetailPage(this.driver);
    await this.listDetailPage.addWord(word, translation);
});

When('I click the delete button for word {string}', async function(this: any, word: string) {
    this.listDetailPage = new ListDetailPage(this.driver);
    await this.listDetailPage.clickDeleteWordButton(word);
});

When('I confirm the word deletion', async function(this: any) {
    this.listDetailPage = new ListDetailPage(this.driver);
    await this.listDetailPage.confirmDeleteWord();
});

When('I cancel the word deletion', async function(this: any) {
    this.listDetailPage = new ListDetailPage(this.driver);
    await this.listDetailPage.cancelDeleteWord();
});

When('I cancel adding the word', async function(this: any) {
    this.listDetailPage = new ListDetailPage(this.driver);
    await this.listDetailPage.cancelAddWord();
});

// Then steps
Then('I should see the add word dialog', async function(this: any) {
    this.listDetailPage = new ListDetailPage(this.driver);
    const isDisplayed = await this.listDetailPage.isAddWordDialogDisplayed();
    expect(isDisplayed).to.be.true;
});

Then('I should see the word {string} in the word list', async function(this: any, word: string) {
    this.listDetailPage = new ListDetailPage(this.driver);
    const exists = await this.listDetailPage.wordExists(word);
    expect(exists).to.be.true;
});

Then('I should not see the word {string} in the word list', async function(this: any, word: string) {
    this.listDetailPage = new ListDetailPage(this.driver);
    const exists = await this.listDetailPage.wordExists(word);
    expect(exists).to.be.false;
});

Then('I should see the delete word confirmation dialog', async function(this: any) {
    this.listDetailPage = new ListDetailPage(this.driver);
    const isDisplayed = await this.listDetailPage.isDeleteWordDialogDisplayed();
    expect(isDisplayed).to.be.true;
});
