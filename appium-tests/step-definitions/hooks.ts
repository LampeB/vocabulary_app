import { Before, After, BeforeAll, AfterAll, setDefaultTimeout, ITestCaseHookParameter } from '@cucumber/cucumber';
import { remote } from 'webdriverio';
import * as path from 'path';
import { exec } from 'child_process';

// Set default timeout for all steps
setDefaultTimeout(120 * 1000); // 2 minutes

// Global driver instance - REUSED across all scenarios
let driver: any = null;
let sessionActive = false;

// Platform configuration
const platform = process.env.PLATFORM || 'android';

// App package name
const APP_PACKAGE = 'com.example.vocabulary_app';

/**
 * Execute a shell command and return a promise
 */
function execCommand(command: string): Promise<string> {
    return new Promise((resolve, reject) => {
        exec(command, (error, stdout, stderr) => {
            if (error) {
                reject(error);
            } else {
                resolve(stdout || stderr);
            }
        });
    });
}

/**
 * Clear app data (database, preferences) for a fresh start.
 * Appium handles APK installation itself via the 'app' capability.
 */
async function clearAppData(): Promise<void> {
    if (platform !== 'android') return;

    try {
        await execCommand(`adb shell pm clear ${APP_PACKAGE}`);
        console.log('🗑️ App data cleared');
    } catch (error: any) {
        // App might not be installed yet (first run) - that's fine
        console.log(`ℹ️ App not installed yet, skipping clear`);
    }
}

/**
 * Get capabilities based on platform
 */
function getCapabilities(): any {
    if (platform === 'android') {
        const appPath = path.resolve(__dirname, '../../build/app/outputs/flutter-apk/app-debug.apk');

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
    console.log(`🚀 Appium tests (${platform})`);
    // Clear app data for a fresh start (Appium handles APK install via 'app' capability)
    await clearAppData();
});

/**
 * Before each scenario - launch the app (session already exists)
 */
Before(async function(this: any, { pickle }: ITestCaseHookParameter) {
    console.log(`\n📝 ${pickle.name}`);

    // Create session only once (first scenario)
    if (!sessionActive) {
        const capabilities = getCapabilities();
        driver = await remote({
            hostname: 'localhost',
            port: 4723,
            path: '/',
            capabilities,
            logLevel: 'error'
        }) as any;
        sessionActive = true;
        await driver.pause(1500); // Wait for initial launch
        console.log('✓ Session created & app installed');
    } else {
        // Session exists - just activate/launch the app
        try {
            await driver.activateApp(APP_PACKAGE);
            await driver.pause(500); // Brief wait for app to be ready
        } catch (error: any) {
            console.log(`⚠️ Could not activate app: ${error.message}`);
        }
    }

    this.driver = driver;
});

/**
 * After each scenario - terminate the app (keep session alive)
 */
After(async function(this: any, { pickle, result }: ITestCaseHookParameter) {
    // Take screenshot on failure
    if (result?.status === 'FAILED' && driver) {
        try {
            const screenshotName = `failure-${pickle.name.replace(/[^a-z0-9]/gi, '-')}.png`;
            await driver.saveScreenshot(`./screenshots/${screenshotName}`);
            console.log(`📸 Screenshot: ${screenshotName}`);
        } catch (error: any) {
            // Ignore screenshot errors
        }
    }

    // Terminate the app (but keep session alive for next scenario)
    if (driver && sessionActive) {
        try {
            await driver.terminateApp(APP_PACKAGE);
        } catch (error: any) {
            // Ignore termination errors
        }
    }
});

/**
 * After all scenarios - close session and reset database
 */
AfterAll(async function() {
    // Close the session at the very end
    if (driver && sessionActive) {
        try {
            await driver.deleteSession();
            sessionActive = false;
        } catch (e) {}
    }
    console.log('✅ Done');

    // Clear app data after all tests (unless disabled)
    if (process.env.RESET_DB_AFTER !== 'false') {
        try {
            await execCommand(`adb shell pm clear ${APP_PACKAGE}`);
            console.log('🗑️ App data cleared');
        } catch (e) {}
    }
});

// Export driver getter for step definitions
export const getDriver = () => driver;
