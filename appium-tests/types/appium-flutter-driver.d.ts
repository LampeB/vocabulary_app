/**
 * Type definitions for appium-flutter-driver custom commands
 * Extends the WebdriverIO Browser type with Flutter Driver methods
 */

declare module 'webdriverio' {
    interface Browser {
        // Flutter Driver element locators
        elementByText(text: string): Promise<any>;
        elementByAccessibilityId(id: string): Promise<any>;
        elementByKey(key: string): Promise<any>;

        // Additional WebdriverIO methods
        back(): Promise<void>;
        pause(ms: number): Promise<void>;
        saveScreenshot(filepath: string): Promise<void>;
        getPageSource(): Promise<string>;
        execute(command: string, args?: any): Promise<any>;
        deleteSession(): Promise<void>;
    }
}

export {};
