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

    // Default timeout for waiting on elements
    protected defaultTimeout = 5000;
    // Single attempt timeout (short, but we retry)
    protected singleAttemptTimeout = 500;
    // Max retries for existence checks
    protected maxRetries = 6;

    /**
     * Retry helper - attempts an operation multiple times with short timeouts.
     * Fast when element exists, patient when it doesn't.
     */
    private async withRetry<T>(
        operation: () => Promise<T>,
        maxAttempts: number = this.maxRetries
    ): Promise<T> {
        let lastError: any;
        for (let attempt = 1; attempt <= maxAttempts; attempt++) {
            try {
                return await operation();
            } catch (error) {
                lastError = error;
                if (attempt < maxAttempts) {
                    // Small delay between retries
                    await new Promise(resolve => setTimeout(resolve, 200));
                }
            }
        }
        throw lastError;
    }

    /**
     * Find element by text using Flutter execute command
     */
    async findByText(text: string): Promise<any> {
        return await this.withRetry(() =>
            this.flutter.execute('flutter:waitFor', byText(text), this.singleAttemptTimeout)
        );
    }

    /**
     * Find element by semantics label (accessibility)
     */
    async findByAccessibilityId(id: string): Promise<any> {
        return await this.withRetry(() =>
            this.flutter.execute('flutter:waitFor', bySemanticsLabel(id), this.singleAttemptTimeout)
        );
    }

    /**
     * Find element by key
     */
    async findByKey(key: string): Promise<any> {
        return await this.withRetry(() =>
            this.flutter.execute('flutter:waitFor', byValueKey(key), this.singleAttemptTimeout)
        );
    }

    /**
     * Wait for element by text with timeout (uses retry)
     */
    async waitForText(text: string, timeout: number = 3000): Promise<any> {
        const attempts = Math.ceil(timeout / (this.singleAttemptTimeout + 200));
        return await this.withRetry(
            () => this.flutter.execute('flutter:waitFor', byText(text), this.singleAttemptTimeout),
            attempts
        );
    }

    /**
     * Click element by text
     */
    async clickByText(text: string): Promise<void> {
        const finder = byText(text);
        await this.withRetry(() =>
            this.flutter.execute('flutter:waitFor', finder, this.singleAttemptTimeout)
        );
        await this.driver.elementClick(finder);
    }

    /**
     * Click element by accessibility ID (semantics label)
     */
    async clickByAccessibilityId(id: string): Promise<void> {
        const finder = bySemanticsLabel(id);
        await this.withRetry(() =>
            this.flutter.execute('flutter:waitFor', finder, this.singleAttemptTimeout)
        );
        await this.driver.elementClick(finder);
    }

    /**
     * Click element by key
     */
    async clickByKey(key: string): Promise<void> {
        const finder = byValueKey(key);
        await this.withRetry(() =>
            this.flutter.execute('flutter:waitFor', finder, this.singleAttemptTimeout)
        );
        await this.driver.elementClick(finder);
    }

    /**
     * Enter text into element by key
     */
    async enterTextByKey(key: string, text: string): Promise<void> {
        const finder = byValueKey(key);
        await this.withRetry(() =>
            this.flutter.execute('flutter:waitFor', finder, this.singleAttemptTimeout)
        );
        await this.driver.elementSendKeys(finder, text);
    }

    /**
     * Enter text using finder (for compatibility)
     */
    async enterText(finder: any, text: string): Promise<void> {
        await this.driver.elementSendKeys(finder, text);
    }

    /**
     * Check if element exists by text (uses retry mechanism)
     */
    async elementExistsByText(text: string): Promise<boolean> {
        try {
            await this.withRetry(
                () => this.flutter.execute('flutter:waitFor', byText(text), this.singleAttemptTimeout),
                3 // fewer retries for existence checks
            );
            return true;
        } catch (error) {
            return false;
        }
    }

    /**
     * Check if element exists by key (uses retry mechanism)
     */
    async elementExistsByKey(key: string): Promise<boolean> {
        try {
            await this.withRetry(
                () => this.flutter.execute('flutter:waitFor', byValueKey(key), this.singleAttemptTimeout),
                3 // fewer retries for existence checks
            );
            return true;
        } catch (error) {
            return false;
        }
    }

    /**
     * Wait for element by key with timeout (uses retry)
     */
    async waitForKey(key: string, timeout: number = 3000): Promise<any> {
        const attempts = Math.ceil(timeout / (this.singleAttemptTimeout + 200));
        return await this.withRetry(
            () => this.flutter.execute('flutter:waitFor', byValueKey(key), this.singleAttemptTimeout),
            attempts
        );
    }

    /**
     * Wait for element by semantics label with timeout (uses retry)
     */
    async waitForSemanticsLabel(label: string, timeout: number = 3000): Promise<any> {
        const attempts = Math.ceil(timeout / (this.singleAttemptTimeout + 200));
        return await this.withRetry(
            () => this.flutter.execute('flutter:waitFor', bySemanticsLabel(label), this.singleAttemptTimeout),
            attempts
        );
    }

    /**
     * Click element by semantics label
     */
    async clickBySemanticsLabel(label: string): Promise<void> {
        const finder = bySemanticsLabel(label);
        await this.withRetry(() =>
            this.flutter.execute('flutter:waitFor', finder, this.singleAttemptTimeout)
        );
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
