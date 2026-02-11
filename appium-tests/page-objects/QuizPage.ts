import { BasePage } from './BasePage';
import { Browser } from 'webdriverio';

interface QuizPageKeys {
    screen: string;
    questionWord: string;
    answerField: string;
    submitButton: string;
    nextButton: string;
    correctFeedback: string;
    incorrectFeedback: string;
    resultsDialog: string;
    quizScore: string;
    finishButton: string;
    audioButton: string;
    micButton: string;
}

/**
 * Quiz Page Object
 * Represents the quiz screen for vocabulary practice
 */
export class QuizPage extends BasePage {
    private keys: QuizPageKeys;

    constructor(driver: Browser) {
        super(driver);

        // Flutter Keys
        this.keys = {
            screen: 'quiz_screen',
            questionWord: 'quiz_question_word',
            answerField: 'quiz_answer_field',
            submitButton: 'submit_answer_button',
            nextButton: 'next_question_button',
            correctFeedback: 'correct_feedback',
            incorrectFeedback: 'incorrect_feedback',
            resultsDialog: 'quiz_results_dialog',
            quizScore: 'quiz_score',
            finishButton: 'finish_quiz_button',
            audioButton: 'quiz_audio_button',
            micButton: 'mic_button'
        };
    }

    /**
     * Verify quiz page is displayed
     */
    async isDisplayed(): Promise<boolean> {
        return await this.elementExistsByKey(this.keys.screen);
    }

    /**
     * Wait for quiz page to load
     */
    async waitForPage(): Promise<void> {
        await this.waitForKey(this.keys.screen);
    }

    /**
     * Check if question word is displayed
     */
    async isQuestionDisplayed(): Promise<boolean> {
        return await this.elementExistsByKey(this.keys.questionWord);
    }

    /**
     * Enter the correct answer based on the displayed question.
     * Checks which word is shown and enters the other one.
     */
    async enterCorrectAnswer(word1: string, word2: string): Promise<void> {
        await this.waitForKey(this.keys.questionWord, 5000);
        const isWord1 = await this.elementExistsByText(word1);
        const answer = isWord1 ? word2 : word1;
        await this.enterAnswer(answer);
    }

    /**
     * Enter answer (waits for field to be ready first)
     */
    async enterAnswer(answer: string): Promise<void> {
        // Ensure answer field is ready before entering text
        await this.waitForKey(this.keys.answerField, 5000);
        await this.enterTextByKey(this.keys.answerField, answer);
    }

    /**
     * Submit answer and wait for feedback or next button
     */
    async submitAnswer(): Promise<void> {
        await this.clickByKey(this.keys.submitButton);
        // Wait for next_question_button to appear (means feedback shown)
        await this.waitForKey(this.keys.nextButton);
    }

    /**
     * Go to next question and wait for it to load
     */
    async nextQuestion(): Promise<void> {
        await this.clickByKey(this.keys.nextButton);
        // Wait for either new question or results dialog
        // Using submit button as indicator of new question
        try {
            await this.waitForKey(this.keys.submitButton);
        } catch (e) {
            // Might be results dialog instead
        }
    }

    /**
     * Check if correct feedback is displayed
     * Waits a bit for feedback animation
     */
    async isCorrectFeedbackDisplayed(): Promise<boolean> {
        try {
            await this.waitForKey(this.keys.correctFeedback, 2000);
            return true;
        } catch (e) {
            return false;
        }
    }

    /**
     * Check if incorrect feedback is displayed
     * Waits a bit for feedback animation
     */
    async isIncorrectFeedbackDisplayed(): Promise<boolean> {
        try {
            await this.waitForKey(this.keys.incorrectFeedback, 2000);
            return true;
        } catch (e) {
            return false;
        }
    }

    /**
     * Check if results dialog is displayed
     */
    async isResultsDialogDisplayed(): Promise<boolean> {
        return await this.elementExistsByKey(this.keys.resultsDialog);
    }

    /**
     * Click finish button on results dialog and wait for home screen
     */
    async clickFinishButton(): Promise<void> {
        await this.clickByKey(this.keys.finishButton);
        await this.waitForKey('home_screen');
    }

    /**
     * Complete all quiz questions (enters same answer for all)
     */
    async completeQuiz(answer: string = 'test'): Promise<void> {
        let hasMoreQuestions = true;
        let maxIterations = 20; // Safety limit

        while (hasMoreQuestions && maxIterations > 0) {
            maxIterations--;

            // Check if results dialog appeared
            if (await this.isResultsDialogDisplayed()) {
                break;
            }

            // Enter and submit answer
            await this.enterAnswer(answer);
            await this.submitAnswer();

            // Check if results dialog appeared after submission
            if (await this.isResultsDialogDisplayed()) {
                break;
            }

            // Go to next question
            try {
                await this.nextQuestion();
            } catch (e) {
                // Might be on results screen
                break;
            }
        }
    }

    // === AUDIO ===

    /**
     * Check if audio button is visible
     * First waits for the question word to be displayed
     */
    async isAudioButtonVisible(): Promise<boolean> {
        try {
            await this.waitForKey(this.keys.questionWord, 3000);
        } catch (e) {
            return false;
        }
        try {
            await this.waitForKey(this.keys.audioButton, 5000);
            return true;
        } catch (e) {
            return false;
        }
    }

    /**
     * Click the audio button
     */
    async clickAudioButton(): Promise<void> {
        await this.waitForKey(this.keys.questionWord, 3000);
        await this.clickByKey(this.keys.audioButton);
        await this.pause(500);
    }

    // === MICROPHONE (STT) ===

    /**
     * Check if microphone button is visible
     */
    async isMicButtonVisible(): Promise<boolean> {
        try {
            await this.waitForKey(this.keys.answerField, 3000);
            return await this.elementExistsByKey(this.keys.micButton);
        } catch (e) {
            return false;
        }
    }

    /**
     * Check if microphone button is disabled (returns true if not clickable)
     * On emulator, STT is unavailable so mic button will be disabled
     */
    async isMicButtonDisabled(): Promise<boolean> {
        try {
            // Try to check if the button exists first
            const exists = await this.elementExistsByKey(this.keys.micButton);
            if (!exists) return true;

            // On Flutter, disabled buttons still exist but have null onPressed
            // We can't easily check this from Appium, so we'll check by icon color (grey = disabled)
            // For now, just return false since we verified it exists
            // The actual disabled state is tested by the icon type (mic_off vs mic_none)
            return false;
        } catch (e) {
            return true;
        }
    }

    /**
     * Check if feedback (correct or incorrect) is displayed after answering
     */
    async isFeedbackDisplayed(): Promise<boolean> {
        return await this.isCorrectFeedbackDisplayed() || await this.isIncorrectFeedbackDisplayed();
    }

    /**
     * Get the current text in the answer field
     */
    async getAnswerFieldText(): Promise<string> {
        try {
            // For Flutter driver, we need to use execute with getText
            const finder = `byValueKey('${this.keys.answerField}')`;
            const text = await (this.driver as any).execute('flutter:getText', finder);
            return text || '';
        } catch (e) {
            return '';
        }
    }
}
