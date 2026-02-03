import { Before, After, BeforeAll, AfterAll, setDefaultTimeout, ITestCaseHookParameter } from '@cucumber/cucumber';
import { remote } from 'webdriverio';
import * as path from 'path';
import { exec } from 'child_process';

// Set default timeout for all steps
setDefaultTimeout(60 * 1000); // 1 minute

// Global driver instance
let driver: any = null;
let sessionActive = false;
let appInstalled = false;

// Platform configuration
const platform = process.env.PLATFORM || 'android';

// App package name
const APP_PACKAGE = 'com.example.vocabulary_app';

// Resolve adb path from ANDROID_HOME (bare 'adb' may not be in PATH for child processes)
const ANDROID_HOME = process.env.ANDROID_HOME || process.env.ANDROID_SDK_ROOT || '';
const ADB = ANDROID_HOME ? path.join(ANDROID_HOME, 'platform-tools', 'adb') : 'adb';
const DEVICE_UDID = process.env.DEVICE_UDID || '';

/**
 * Build adb command with optional device targeting
 */
function adbCmd(args: string): string {
    const deviceFlag = DEVICE_UDID ? `-s ${DEVICE_UDID}` : '';
    return `"${ADB}" ${deviceFlag} ${args}`;
}

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
        await execCommand(adbCmd(`shell pm clear ${APP_PACKAGE}`));
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
        const deviceName = process.env.DEVICE_NAME || 'Android Emulator';
        const udid = process.env.DEVICE_UDID || '';

        const caps: any = {
            platformName: 'Android',
            'appium:deviceName': deviceName,
            'appium:automationName': 'Flutter',
            'appium:noReset': true,
            'appium:fullReset': false,
            'appium:newCommandTimeout': 60,
            'appium:autoGrantPermissions': true,
            'appium:forceAppLaunch': true,
        };

        if (!appInstalled) {
            // First session: provide APK path so Appium installs it
            const appPath = path.resolve(__dirname, '../../build/app/outputs/flutter-apk/app-debug.apk');
            caps['appium:app'] = appPath;
        } else {
            // Subsequent sessions: just launch the already-installed app (faster)
            caps['appium:appPackage'] = APP_PACKAGE;
            caps['appium:appActivity'] = '.MainActivity';
        }

        if (udid) {
            caps['appium:udid'] = udid;
        }

        return caps;
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
    // Keep phone screen on during tests (requires USB/charging)
    if (platform === 'android') {
        try {
            await execCommand(adbCmd('shell svc power stayon usb'));
        } catch (e) {}
    }
});

/**
 * Before each scenario - create a fresh session (kills & relaunches the app)
 * Flutter Driver cannot reconnect after app restart, so we recreate the full session.
 * With noReset:true, app data persists but the app process is fresh.
 */
Before(async function(this: any, { pickle }: ITestCaseHookParameter) {
    console.log(`\n📝 ${pickle.name}`);

    // Clean up previous session if any
    if (driver && sessionActive) {
        try { await driver.deleteSession(); } catch (e) {}
        sessionActive = false;
    }

    // Create a fresh session (installs APK on first run, just launches on subsequent)
    try {
        const capabilities = getCapabilities();
        driver = await remote({
            hostname: 'localhost',
            port: 4723,
            path: '/',
            capabilities,
            logLevel: 'error'
        }) as any;
        sessionActive = true;
        appInstalled = true;
        await driver.pause(2000); // Wait for Flutter Driver to connect
        console.log('✓ App launched');
    } catch (error: any) {
        console.error(`✗ Session creation failed: ${error.message}`);
        throw error;
    }

    this.driver = driver;
});

/**
 * After each scenario - take screenshot on failure, then kill the app
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
    // Session is deleted in the next Before hook (or AfterAll for the last scenario)
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
            await execCommand(adbCmd(`shell pm clear ${APP_PACKAGE}`));
            console.log('🗑️ App data cleared');
        } catch (e) {}
    }
});

/**
 * Reset session: clear app data and create a fresh Appium session.
 * Needed when tests must start from empty state (pm clear kills the app
 * and breaks the Flutter Driver connection, so we must recreate the session).
 */
export async function resetSession(): Promise<any> {
    // Close existing session
    if (driver && sessionActive) {
        try {
            await driver.deleteSession();
        } catch (e) {}
        sessionActive = false;
    }

    // Clear app data
    await clearAppData();

    // Create a new session
    const capabilities = getCapabilities();
    driver = await remote({
        hostname: 'localhost',
        port: 4723,
        path: '/',
        capabilities,
        logLevel: 'error'
    }) as any;
    sessionActive = true;
    await driver.pause(3000); // Longer wait for Flutter Driver to fully connect
    console.log('✓ Session recreated with fresh data');
    return driver;
}

// Export driver getter for step definitions
export const getDriver = () => driver;
