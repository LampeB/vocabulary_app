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
            finishButton: 'finish_quiz_button'
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
     */
    async isCorrectFeedbackDisplayed(): Promise<boolean> {
        return await this.elementExistsByKey(this.keys.correctFeedback);
    }

    /**
     * Check if incorrect feedback is displayed
     */
    async isIncorrectFeedbackDisplayed(): Promise<boolean> {
        return await this.elementExistsByKey(this.keys.incorrectFeedback);
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
}
