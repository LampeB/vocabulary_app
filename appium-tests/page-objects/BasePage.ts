import { Browser } from 'webdriverio';
// @ts-ignore - no types available for this package
import { byValueKey, byText, bySemanticsLabel, byType } from 'appium-flutter-finder';

/**
 * Base Page Object
 * Contains common methods used by all page objects
 * Uses Appium Flutter Driver commands via execute()
 */
export class BasePage {
    protected driver: Browser;

    constructor(driver: Browser) {
        this.driver = driver;
    }

    /**
     * Find element by text using Flutter execute command
     */
    async findByText(text: string): Promise<any> {
        return await this.driver.execute('flutter:waitFor', byText(text), 5000);
    }

    /**
     * Find element by semantics label (accessibility)
     */
    async findByAccessibilityId(id: string): Promise<any> {
        return await this.driver.execute('flutter:waitFor', bySemanticsLabel(id), 5000);
    }

    /**
     * Find element by key
     */
    async findByKey(key: string): Promise<any> {
        return await this.driver.execute('flutter:waitFor', byValueKey(key), 5000);
    }

    /**
     * Wait for element by text with timeout
     */
    async waitForText(text: string, timeout: number = 10000): Promise<any> {
        return await this.driver.execute('flutter:waitFor', byText(text), timeout);
    }

    /**
     * Click element by text
     */
    async clickByText(text: string): Promise<void> {
        const finder = byText(text);
        await this.driver.execute('flutter:waitFor', finder, 5000);
        await this.driver.elementClick(finder);
    }

    /**
     * Click element by accessibility ID (semantics label)
     */
    async clickByAccessibilityId(id: string): Promise<void> {
        const finder = bySemanticsLabel(id);
        await this.driver.execute('flutter:waitFor', finder, 5000);
        await this.driver.elementClick(finder);
    }

    /**
     * Click element by key
     */
    async clickByKey(key: string): Promise<void> {
        const finder = byValueKey(key);
        await this.driver.execute('flutter:waitFor', finder, 5000);
        await this.driver.elementClick(finder);
    }

    /**
     * Enter text into element by key
     */
    async enterTextByKey(key: string, text: string): Promise<void> {
        const finder = byValueKey(key);
        await this.driver.execute('flutter:waitFor', finder, 5000);
        await this.driver.elementSendKeys(finder, text);
    }

    /**
     * Enter text using finder (for compatibility)
     */
    async enterText(finder: any, text: string): Promise<void> {
        await this.driver.elementSendKeys(finder, text);
    }

    /**
     * Check if element exists by key
     */
    async elementExistsByText(text: string): Promise<boolean> {
        try {
            await this.driver.execute('flutter:waitFor', byText(text), 3000);
            return true;
        } catch (error) {
            return false;
        }
    }

    /**
     * Check if element exists by key
     */
    async elementExistsByKey(key: string): Promise<boolean> {
        try {
            await this.driver.execute('flutter:waitFor', byValueKey(key), 3000);
            return true;
        } catch (error) {
            return false;
        }
    }

    /**
     * Wait for element by key with timeout
     */
    async waitForKey(key: string, timeout: number = 10000): Promise<any> {
        return await this.driver.execute('flutter:waitFor', byValueKey(key), timeout);
    }

    /**
     * Scroll until element is visible
     */
    async scrollUntilVisible(
        scrollView: string,
        itemText: string,
        direction: 'up' | 'down' = 'down',
        delta: number = 100
    ): Promise<void> {
        try {
            const scrollableFinder = byType(scrollView);
            const itemFinder = byText(itemText);
            await this.driver.execute('flutter:scrollUntilVisible', scrollableFinder, {
                item: itemFinder,
                dxScroll: 0,
                dyScroll: direction === 'down' ? -delta : delta
            });
        } catch (error) {
            console.log(`Scroll not needed or ${itemText} already visible`);
        }
    }

    /**
     * Go back
     */
    async goBack(): Promise<void> {
        await this.driver.back();
    }

    /**
     * Pause/Wait
     */
    async pause(ms: number = 1000): Promise<void> {
        await this.driver.pause(ms);
    }

    /**
     * Take screenshot
     */
    async takeScreenshot(filename: string): Promise<void> {
        await this.driver.saveScreenshot(`./screenshots/${filename}`);
    }

    /**
     * Get page source (for debugging)
     */
    async getPageSource(): Promise<string> {
        return await this.driver.getPageSource();
    }
}
