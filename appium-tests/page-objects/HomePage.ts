import { BasePage } from './BasePage';
import { Browser } from 'webdriverio';

interface HomePageKeys {
    homeScreen: string;
    homeTitle: string;
    addListButton: string;
    emptyState: string;
    emptyStateTitle: string;
    listView: string;
    deleteListDialog: string;
    confirmDeleteListButton: string;
    cancelDeleteListButton: string;
}

/**
 * Home Page Object
 * Represents the home screen with vocabulary lists
 * Uses Flutter Keys for stable element identification
 */
export class HomePage extends BasePage {
    private keys: HomePageKeys;

    constructor(driver: Browser) {
        super(driver);

        // Flutter Keys - stable identifiers for testing
        this.keys = {
            homeScreen: 'home_screen',
            homeTitle: 'home_title',
            addListButton: 'add_list_button',
            emptyState: 'empty_state',
            emptyStateTitle: 'empty_state_title',
            listView: 'vocabulary_list_view',
            deleteListDialog: 'delete_list_dialog',
            confirmDeleteListButton: 'confirm_delete_list_button',
            cancelDeleteListButton: 'cancel_delete_list_button'
        };
    }

    /**
     * Verify home page is displayed by checking for the home screen key
     */
    async isDisplayed(): Promise<boolean> {
        return await this.elementExistsByKey(this.keys.homeScreen);
    }

    /**
     * Wait for home page to load
     */
    async waitForPage(): Promise<void> {
        await this.waitForKey(this.keys.homeScreen);
    }

    /**
     * Click add list button and wait for dialog
     */
    async clickAddListButton(): Promise<void> {
        await this.clickByKey(this.keys.addListButton);
        await this.waitForKey('list_name_field'); // Dialog opened
    }

    /**
     * Click on a vocabulary list by name and wait for detail page
     */
    async clickListByName(listName: string): Promise<void> {
        const listCardKey = `list_card_${listName}`;
        await this.clickByKey(listCardKey);
        // Wait for list detail screen to appear instead of fixed pause
        await this.waitForKey('list_detail_screen');
    }

    /**
     * Check if list exists by name (FAST - uses Key)
     */
    async listExists(listName: string): Promise<boolean> {
        // Use list card key for faster lookup
        const listCardKey = `list_card_${listName}`;
        return await this.elementExistsByKey(listCardKey);
    }

    /**
     * Get all visible list names
     */
    async getVisibleLists(): Promise<string[]> {
        // This would require more complex logic to extract all list items
        // For now, return empty array (can be implemented if needed)
        return [];
    }

    /**
     * Take screenshot of home page
     */
    async takeScreenshot(filename: string = 'home-page.png'): Promise<void> {
        await super.takeScreenshot(filename);
    }

    // === DELETE LIST ===

    /**
     * Click delete button for a specific list and wait for dialog
     */
    async clickDeleteListButton(listName: string): Promise<void> {
        const deleteButtonKey = `delete_list_button_${listName}`;
        await this.clickByKey(deleteButtonKey);
        await this.waitForKey(this.keys.deleteListDialog);
    }

    /**
     * Long press on a list (alternative to delete button)
     */
    async longPressOnList(listName: string): Promise<void> {
        await this.clickDeleteListButton(listName);
    }

    /**
     * Check if delete list dialog is displayed
     */
    async isDeleteListDialogDisplayed(): Promise<boolean> {
        return await this.elementExistsByKey(this.keys.deleteListDialog);
    }

    /**
     * Confirm list deletion and wait for dialog to close
     */
    async confirmDeleteList(): Promise<void> {
        await this.clickByKey(this.keys.confirmDeleteListButton);
        await this.waitForKey(this.keys.homeScreen);
    }

    /**
     * Cancel list deletion and wait for dialog to close
     */
    async cancelDeleteList(): Promise<void> {
        await this.clickByKey(this.keys.cancelDeleteListButton);
        await this.waitForKey(this.keys.homeScreen);
    }

    // === QUIZ ===

    /**
     * Click quiz button for a specific list and wait for quiz screen
     */
    async clickQuizButton(listName: string): Promise<void> {
        const quizButtonKey = `quiz_button_${listName}`;
        await this.clickByKey(quizButtonKey);
        await this.waitForKey('quiz_screen');
    }

    // === EMPTY STATE ===

    /**
     * Check if empty state is displayed
     */
    async isEmptyStateDisplayed(): Promise<boolean> {
        return await this.elementExistsByKey(this.keys.emptyState);
    }

    /**
     * Check if empty state message is displayed
     */
    async isEmptyStateMessageDisplayed(): Promise<boolean> {
        return await this.elementExistsByKey(this.keys.emptyStateTitle);
    }
}
