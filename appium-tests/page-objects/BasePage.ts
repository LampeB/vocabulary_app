import { Browser } from 'webdriverio';
// @ts-ignore - no types available for this package
import { byValueKey, byText, bySemanticsLabel, byType } from 'appium-flutter-finder';

// Type for Flutter driver execute with 3 arguments
type FlutterDriver = Browser & {
    execute(script: string, finder: any, timeoutOrOptions: number | object): Promise<any>;
};

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

    // Cast driver for Flutter-specific execute calls (3 arguments)
    private get flutter(): FlutterDriver {
        return this.driver as FlutterDriver;
    }

    // Default timeout - reduced for speed
    protected defaultTimeout = 1500;
    // Fast timeout for existence checks
    protected fastTimeout = 300;

    /**
     * Find element by text using Flutter execute command
     */
    async findByText(text: string): Promise<any> {
        return await this.flutter.execute('flutter:waitFor', byText(text), this.defaultTimeout);
    }

    /**
     * Find element by semantics label (accessibility)
     */
    async findByAccessibilityId(id: string): Promise<any> {
        return await this.flutter.execute('flutter:waitFor', bySemanticsLabel(id), this.defaultTimeout);
    }

    /**
     * Find element by key
     */
    async findByKey(key: string): Promise<any> {
        return await this.flutter.execute('flutter:waitFor', byValueKey(key), this.defaultTimeout);
    }

    /**
     * Wait for element by text with timeout
     */
    async waitForText(text: string, timeout: number = 3000): Promise<any> {
        return await this.flutter.execute('flutter:waitFor', byText(text), timeout);
    }

    /**
     * Click element by text
     */
    async clickByText(text: string): Promise<void> {
        const finder = byText(text);
        await this.flutter.execute('flutter:waitFor', finder, this.defaultTimeout);
        await this.driver.elementClick(finder);
    }

    /**
     * Click element by accessibility ID (semantics label)
     */
    async clickByAccessibilityId(id: string): Promise<void> {
        const finder = bySemanticsLabel(id);
        await this.flutter.execute('flutter:waitFor', finder, this.defaultTimeout);
        await this.driver.elementClick(finder);
    }

    /**
     * Click element by key
     */
    async clickByKey(key: string): Promise<void> {
        const finder = byValueKey(key);
        await this.flutter.execute('flutter:waitFor', finder, this.defaultTimeout);
        await this.driver.elementClick(finder);
    }

    /**
     * Enter text into element by key
     */
    async enterTextByKey(key: string, text: string): Promise<void> {
        const finder = byValueKey(key);
        await this.flutter.execute('flutter:waitFor', finder, this.defaultTimeout);
        await this.driver.elementSendKeys(finder, text);
    }

    /**
     * Enter text using finder (for compatibility)
     */
    async enterText(finder: any, text: string): Promise<void> {
        await this.driver.elementSendKeys(finder, text);
    }

    /**
     * Check if element exists by text (FAST - 300ms timeout)
     */
    async elementExistsByText(text: string): Promise<boolean> {
        try {
            await this.flutter.execute('flutter:waitFor', byText(text), this.fastTimeout);
            return true;
        } catch (error) {
            return false;
        }
    }

    /**
     * Check if element exists by key (FAST - 300ms timeout)
     */
    async elementExistsByKey(key: string): Promise<boolean> {
        try {
            await this.flutter.execute('flutter:waitFor', byValueKey(key), this.fastTimeout);
            return true;
        } catch (error) {
            return false;
        }
    }

    /**
     * Wait for element by key with timeout
     */
    async waitForKey(key: string, timeout: number = 2000): Promise<any> {
        return await this.flutter.execute('flutter:waitFor', byValueKey(key), timeout);
    }

    /**
     * Wait for element by semantics label with timeout
     */
    async waitForSemanticsLabel(label: string, timeout: number = 2000): Promise<any> {
        return await this.flutter.execute('flutter:waitFor', bySemanticsLabel(label), timeout);
    }

    /**
     * Click element by semantics label
     */
    async clickBySemanticsLabel(label: string): Promise<void> {
        const finder = bySemanticsLabel(label);
        await this.flutter.execute('flutter:waitFor', finder, this.defaultTimeout);
        await this.driver.elementClick(finder);
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
            await this.flutter.execute('flutter:scrollUntilVisible', scrollableFinder, {
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
