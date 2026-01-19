import { BasePage } from './BasePage';
import { Browser } from 'webdriverio';

interface HomePageKeys {
    homeScreen: string;
    homeTitle: string;
    addListButton: string;
    emptyState: string;
    listView: string;
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
            listView: 'vocabulary_list_view'
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
        await this.pause(1000);
    }

    /**
     * Click add list button
     */
    async clickAddListButton(): Promise<void> {
        await this.clickByKey(this.keys.addListButton);
        await this.pause(1000);
    }

    /**
     * Click on a vocabulary list by name
     */
    async clickListByName(listName: string): Promise<void> {
        await this.scrollUntilVisible('ListView', listName, 'down', 100);
        await this.clickByText(listName);
        await this.pause(2000);
    }

    /**
     * Check if list exists by name (quick check without scrolling)
     */
    async listExists(listName: string): Promise<boolean> {
        // Simple check - just look for the text without scrolling
        return await this.elementExistsByText(listName);
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
}
