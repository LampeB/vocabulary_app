import { BasePage } from './BasePage';
import { Browser } from 'webdriverio';

interface ListDetailPageKeys {
    screen: string;
    title: string;
    addWordButton: string;
}

/**
 * List Detail Page Object
 * Represents the detail screen of a vocabulary list
 */
export class ListDetailPage extends BasePage {
    private keys: ListDetailPageKeys;

    constructor(driver: Browser) {
        super(driver);

        // Flutter Keys
        this.keys = {
            screen: 'list_detail_screen',
            title: 'list_detail_title',
            addWordButton: 'add_word_button'
        };
    }

    /**
     * Verify page is displayed
     */
    async isDisplayed(): Promise<boolean> {
        return await this.elementExistsByKey(this.keys.screen);
    }

    /**
     * Wait for page to load
     */
    async waitForPage(): Promise<void> {
        await this.waitForKey(this.keys.screen);
        await this.pause(1000);
    }

    /**
     * Click add word button
     */
    async clickAddWordButton(): Promise<void> {
        await this.clickByKey(this.keys.addWordButton);
        await this.pause(1000);
    }

    /**
     * Go back to home
     */
    async goBackToHome(): Promise<void> {
        await this.goBack();
        await this.pause(1000);
    }

    /**
     * Check if word exists in list
     */
    async wordExists(word: string): Promise<boolean> {
        return await this.elementExistsByText(word);
    }

    /**
     * Click on a word in the list
     */
    async clickWord(word: string): Promise<void> {
        await this.clickByText(word);
        await this.pause(1000);
    }

    /**
     * Scroll to find a word
     */
    async scrollToWord(word: string): Promise<void> {
        await this.scrollUntilVisible('ListView', word, 'down', 100);
    }
}
