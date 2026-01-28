import { BasePage } from './BasePage';
import { Browser } from 'webdriverio';

interface ListDetailPageKeys {
    screen: string;
    title: string;
    addWordButton: string;
    addWordDialog: string;
    frenchWordField: string;
    koreanWordField: string;
    confirmAddWordButton: string;
    cancelAddWordButton: string;
    deleteWordDialog: string;
    confirmDeleteWordButton: string;
    cancelDeleteWordButton: string;
    emptyListState: string;
    emptyListMessage: string;
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
            addWordButton: 'add_word_button',
            addWordDialog: 'add_word_dialog',
            frenchWordField: 'french_word_field',
            koreanWordField: 'korean_word_field',
            confirmAddWordButton: 'confirm_add_word_button',
            cancelAddWordButton: 'cancel_add_word_button',
            deleteWordDialog: 'delete_word_dialog',
            confirmDeleteWordButton: 'confirm_delete_word_button',
            cancelDeleteWordButton: 'cancel_delete_word_button',
            emptyListState: 'empty_list_state',
            emptyListMessage: 'empty_list_message'
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
    }

    /**
     * Click add word button and wait for dialog
     */
    async clickAddWordButton(): Promise<void> {
        await this.clickByKey(this.keys.addWordButton);
        await this.waitForKey(this.keys.addWordDialog);
    }

    /**
     * Go back to home and wait for home screen
     */
    async goBackToHome(): Promise<void> {
        await this.goBack();
        await this.waitForKey('home_screen');
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
    }

    /**
     * Scroll to find a word
     */
    async scrollToWord(word: string): Promise<void> {
        await this.scrollUntilVisible('ListView', word, 'down', 100);
    }

    // === ADD WORD DIALOG ===

    /**
     * Check if add word dialog is displayed
     */
    async isAddWordDialogDisplayed(): Promise<boolean> {
        return await this.elementExistsByKey(this.keys.addWordDialog);
    }

    /**
     * Enter French word
     */
    async enterFrenchWord(word: string): Promise<void> {
        await this.enterTextByKey(this.keys.frenchWordField, word);
    }

    /**
     * Enter Korean word
     */
    async enterKoreanWord(word: string): Promise<void> {
        await this.enterTextByKey(this.keys.koreanWordField, word);
    }

    /**
     * Confirm add word and wait for dialog to close
     */
    async confirmAddWord(): Promise<void> {
        await this.clickByKey(this.keys.confirmAddWordButton);
        // Wait for dialog to close - list detail screen becomes visible
        await this.waitForKey(this.keys.screen);
    }

    /**
     * Cancel add word and wait for dialog to close
     */
    async cancelAddWord(): Promise<void> {
        await this.clickByKey(this.keys.cancelAddWordButton);
        await this.waitForKey(this.keys.screen);
    }

    /**
     * Add a word with translation (helper method)
     */
    async addWord(frenchWord: string, koreanWord: string): Promise<void> {
        await this.clickAddWordButton();
        await this.enterFrenchWord(frenchWord);
        await this.enterKoreanWord(koreanWord);
        await this.confirmAddWord();
    }

    // === DELETE WORD ===

    /**
     * Click delete button for a specific word and wait for dialog
     */
    async clickDeleteWordButton(word: string): Promise<void> {
        const deleteButtonKey = `delete_word_button_${word}`;
        await this.clickByKey(deleteButtonKey);
        await this.waitForKey(this.keys.deleteWordDialog);
    }

    /**
     * Check if delete word dialog is displayed
     */
    async isDeleteWordDialogDisplayed(): Promise<boolean> {
        return await this.elementExistsByKey(this.keys.deleteWordDialog);
    }

    /**
     * Confirm word deletion and wait for dialog to close
     */
    async confirmDeleteWord(): Promise<void> {
        await this.clickByKey(this.keys.confirmDeleteWordButton);
        await this.waitForKey(this.keys.screen);
    }

    /**
     * Cancel word deletion and wait for dialog to close
     */
    async cancelDeleteWord(): Promise<void> {
        await this.clickByKey(this.keys.cancelDeleteWordButton);
        await this.waitForKey(this.keys.screen);
    }

    // === EMPTY STATE ===

    /**
     * Check if empty state is displayed
     */
    async isEmptyStateDisplayed(): Promise<boolean> {
        return await this.elementExistsByKey(this.keys.emptyListState);
    }

    /**
     * Check if empty message is displayed
     */
    async isEmptyMessageDisplayed(): Promise<boolean> {
        return await this.elementExistsByKey(this.keys.emptyListMessage);
    }

    // === AUDIO ===

    /**
     * Check if audio button for language 1 is visible for a word
     * First waits for the word card to be present
     */
    async isAudioButtonLang1Visible(word: string): Promise<boolean> {
        const wordCardKey = `word_card_${word}`;
        try {
            await this.waitForKey(wordCardKey, 3000);
        } catch (e) {
            return false;
        }
        const buttonKey = `audio_button_lang1_${word}`;
        try {
            await this.waitForKey(buttonKey, 5000);
            return true;
        } catch (e) {
            return false;
        }
    }

    /**
     * Check if audio button for language 2 is visible for a word
     * First waits for the word card to be present
     */
    async isAudioButtonLang2Visible(word: string): Promise<boolean> {
        const wordCardKey = `word_card_${word}`;
        try {
            await this.waitForKey(wordCardKey, 3000);
        } catch (e) {
            return false;
        }
        const buttonKey = `audio_button_lang2_${word}`;
        try {
            await this.waitForKey(buttonKey, 5000);
            return true;
        } catch (e) {
            return false;
        }
    }

    /**
     * Click audio button for language 1 of a word
     */
    async clickAudioButtonLang1(word: string): Promise<void> {
        const wordCardKey = `word_card_${word}`;
        await this.waitForKey(wordCardKey, 3000);
        await this.clickByKey(`audio_button_lang1_${word}`);
        await this.pause(500);
    }

    /**
     * Click audio button for language 2 of a word
     */
    async clickAudioButtonLang2(word: string): Promise<void> {
        const wordCardKey = `word_card_${word}`;
        await this.waitForKey(wordCardKey, 3000);
        await this.clickByKey(`audio_button_lang2_${word}`);
        await this.pause(500);
    }
}
