import { When, Then } from '@cucumber/cucumber';
import { expect } from 'chai';
import { HomePage } from '../page-objects/HomePage';
import { QuizPage } from '../page-objects/QuizPage';

/**
 * Step definitions for quiz functionality
 */

// When steps
When('I start the quiz for list {string}', async function(this: any, listName: string) {
    this.homePage = new HomePage(this.driver);
    await this.homePage.clickQuizButton(listName);
    this.quizPage = new QuizPage(this.driver);
});

When('I enter the answer {string}', async function(this: any, answer: string) {
    this.quizPage = new QuizPage(this.driver);
    await this.quizPage.enterAnswer(answer);
});

When('I submit my answer', async function(this: any) {
    this.quizPage = new QuizPage(this.driver);
    await this.quizPage.submitAnswer();
});

When('I complete the quiz', async function(this: any) {
    this.quizPage = new QuizPage(this.driver);
    await this.quizPage.completeQuiz('test');
});

// Then steps
Then('I should be on the quiz screen', async function(this: any) {
    this.quizPage = new QuizPage(this.driver);
    await this.quizPage.waitForPage();
    const isDisplayed = await this.quizPage.isDisplayed();
    expect(isDisplayed).to.be.true;
});

Then('I should see a word to translate', async function(this: any) {
    this.quizPage = new QuizPage(this.driver);
    const isDisplayed = await this.quizPage.isQuestionDisplayed();
    expect(isDisplayed).to.be.true;
});

Then('I should see correct feedback', async function(this: any) {
    this.quizPage = new QuizPage(this.driver);
    const isDisplayed = await this.quizPage.isCorrectFeedbackDisplayed();
    expect(isDisplayed).to.be.true;
});

Then('I should see incorrect feedback', async function(this: any) {
    this.quizPage = new QuizPage(this.driver);
    const isDisplayed = await this.quizPage.isIncorrectFeedbackDisplayed();
    expect(isDisplayed).to.be.true;
});

Then('I should see the quiz results dialog', async function(this: any) {
    this.quizPage = new QuizPage(this.driver);
    const isDisplayed = await this.quizPage.isResultsDialogDisplayed();
    expect(isDisplayed).to.be.true;
});
