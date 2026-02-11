import { Given, Then } from '@cucumber/cucumber';
import { expect } from 'chai';
import { HomePage } from '../page-objects/HomePage';
import { CreateListDialog } from '../page-objects/CreateListDialog';
import { ListDetailPage } from '../page-objects/ListDetailPage';
import { QuizPage } from '../page-objects/QuizPage';

/**
 * Step definitions for Voice Input (STT) feature testing.
 * Tests verify the STT quiz screen works correctly for basic quiz operations.
 */

/**
 * Creates a vocabulary list with a sample word for quiz testing.
 */
Given('a vocabulary list {string} exists with words', async function(this: any, listName: string) {
    this.homePage = new HomePage(this.driver);
    this.createListDialog = new CreateListDialog(this.driver);
    this.listDetailPage = new ListDetailPage(this.driver);

    const exists = await this.homePage.listExists(listName);

    if (!exists) {
        await this.homePage.clickAddListButton();
        await this.createListDialog.createSimpleList(listName);
        await this.homePage.clickListByName(listName);
        await this.listDetailPage.addWord('bonjour', '안녕하세요');
        await this.driver.back();
        await this.homePage.waitForPage();
    }
});

Then('I should see the microphone button', async function(this: any) {
    this.quizPage = new QuizPage(this.driver);
    const isVisible = await this.quizPage.isMicButtonVisible();
    expect(isVisible).to.be.true;
});

Then('I should see the audio playback button', async function(this: any) {
    this.quizPage = new QuizPage(this.driver);
    const isVisible = await this.quizPage.isAudioButtonVisible();
    expect(isVisible).to.be.true;
});

Then('I should see feedback for my answer', async function(this: any) {
    this.quizPage = new QuizPage(this.driver);
    const hasFeedback = await this.quizPage.isFeedbackDisplayed();
    expect(hasFeedback).to.be.true;
});
