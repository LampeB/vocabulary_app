import { Before, After, BeforeAll, AfterAll, setDefaultTimeout, ITestCaseHookParameter } from '@cucumber/cucumber';
import { remote, Browser } from 'webdriverio';
import * as path from 'path';

// Set default timeout for all steps
setDefaultTimeout(300 * 1000); // 5 minutes

// Global driver instance
let driver: Browser;

// Platform configuration
const platform = process.env.PLATFORM || 'android';

/**
 * Get capabilities based on platform
 */
function getCapabilities(): any {
    if (platform === 'android') {
        const appPath = path.resolve(__dirname, '../../vocabulary_app/build/app/outputs/flutter-apk/app-debug.apk');

        return {
            platformName: 'Android',
            'appium:deviceName': 'Android Emulator',
            'appium:automationName': 'Flutter',
            'appium:app': appPath,
            'appium:noReset': true,
            'appium:fullReset': false,
            'appium:newCommandTimeout': 240,
            'appium:autoGrantPermissions': true,
            'appium:showFlutterDriverLogs': true,
            'appium:retryBackoffTime': 3000,
            'appium:maxRetryCount': 10,
            // Force Appium to wait longer for VM Service and auto-discover from logcat
            'appium:skipPortForward': false,
            'appium:observatoryWsUri': '', // Let Appium auto-detect from logcat
        };
    } else if (platform === 'windows') {
        const appPath = path.resolve(__dirname, '../../vocabulary_app/build/windows/x64/runner/Release/vocabulary_app.exe');

        return {
            platformName: 'Windows',
            'appium:automationName': 'Flutter',
            'appium:app': appPath,
            'appium:deviceName': 'WindowsPC',
            'appium:showFlutterDriverLogs': true,
        };
    }
}

/**
 * Before all scenarios
 */
BeforeAll(async function() {
    console.log('🚀 Starting Appium test suite...');
    console.log(`📱 Platform: ${platform}`);
});

/**
 * Before each scenario
 */
Before(async function(this: any, { pickle }: ITestCaseHookParameter) {
    console.log(`\n📝 Starting scenario: ${pickle.name}`);

    // Create driver connection
    const capabilities = getCapabilities();

    driver = await remote({
        hostname: 'localhost',
        port: 4723,
        path: '/',
        capabilities,
        logLevel: 'error'
    });

    // Store driver in world context
    this.driver = driver;

    // Wait for app to launch
    await driver.pause(3000);

    console.log('✓ App launched successfully');
});

/**
 * After each scenario
 */
After(async function(this: any, { pickle, result }: ITestCaseHookParameter) {
    // Take screenshot on failure
    if (result?.status === 'FAILED') {
        try {
            const timestamp = Date.now();
            const screenshotName = `failure-${pickle.name.replace(/[^a-z0-9]/gi, '-')}-${timestamp}.png`;
            await driver.saveScreenshot(`./screenshots/${screenshotName}`);
            console.log(`📸 Failure screenshot saved: ${screenshotName}`);
        } catch (error: any) {
            console.log('Failed to capture screenshot:', error.message);
        }
    }

    // Close app and driver
    if (driver) {
        try {
            // Terminate the app explicitly
            if (platform === 'android') {
                await driver.execute('mobile: terminateApp', { appId: 'com.example.vocabulary_app' });
                console.log('✓ App terminated');
            }
        } catch (e) {
            // App might already be closed, ignore error
        }

        await driver.deleteSession();
        console.log('✓ Session closed');
    }
});

/**
 * After all scenarios
 */
AfterAll(async function() {
    console.log('\n✅ Test suite completed!');
});

// Export driver getter for step definitions
export const getDriver = (): Browser => driver;
