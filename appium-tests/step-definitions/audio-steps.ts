import { When, Then } from '@cucumber/cucumber';
import { expect } from 'chai';
import { ListDetailPage } from '../page-objects/ListDetailPage';
import { QuizPage } from '../page-objects/QuizPage';

/**
 * Step definitions for audio functionality
 */

// Track if audio played successfully (no error thrown)
let audioPlayedSuccessfully = false;

// === LIST DETAIL AUDIO STEPS ===

Then('I should see the audio button for word {string} in language 1', async function(this: any, word: string) {
    this.listDetailPage = new ListDetailPage(this.driver);
    const isVisible = await this.listDetailPage.isAudioButtonLang1Visible(word);
    expect(isVisible).to.be.true;
});

Then('I should see the audio button for word {string} in language 2', async function(this: any, word: string) {
    this.listDetailPage = new ListDetailPage(this.driver);
    const isVisible = await this.listDetailPage.isAudioButtonLang2Visible(word);
    expect(isVisible).to.be.true;
});

When('I click the audio button for word {string} in language 1', async function(this: any, word: string) {
    this.listDetailPage = new ListDetailPage(this.driver);
    try {
        await this.listDetailPage.clickAudioButtonLang1(word);
        audioPlayedSuccessfully = true;
    } catch (error) {
        audioPlayedSuccessfully = false;
        throw error;
    }
});

When('I click the audio button for word {string} in language 2', async function(this: any, word: string) {
    this.listDetailPage = new ListDetailPage(this.driver);
    try {
        await this.listDetailPage.clickAudioButtonLang2(word);
        audioPlayedSuccessfully = true;
    } catch (error) {
        audioPlayedSuccessfully = false;
        throw error;
    }
});

// === QUIZ AUDIO STEPS ===

Then('I should see the quiz audio button', async function(this: any) {
    this.quizPage = new QuizPage(this.driver);
    const isVisible = await this.quizPage.isAudioButtonVisible();
    expect(isVisible).to.be.true;
});

When('I click the quiz audio button', async function(this: any) {
    this.quizPage = new QuizPage(this.driver);
    try {
        await this.quizPage.clickAudioButton();
        audioPlayedSuccessfully = true;
    } catch (error) {
        audioPlayedSuccessfully = false;
        throw error;
    }
});

// === COMMON AUDIO STEPS ===

Then('the audio should play without error', async function(this: any) {
    // If we got here without an exception, audio button was clickable
    // TTS will play in the background - we can't easily verify audio output
    // but we can verify the button was interactive
    expect(audioPlayedSuccessfully).to.be.true;
});
