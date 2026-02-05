import { Before, After, BeforeAll, AfterAll, BeforeStep, setDefaultTimeout, ITestCaseHookParameter, ITestStepHookParameter } from '@cucumber/cucumber';
import { remote } from 'webdriverio';
import * as path from 'path';
import * as fs from 'fs';
import { exec } from 'child_process';

// Set default timeout for all steps
setDefaultTimeout(300 * 1000); // 5 minutes (Flutter driver session creation can be slow)

// Global driver instance - REUSED across all scenarios
let driver: any = null;
let sessionActive = false;

// Platform configuration
const platform = process.env.PLATFORM || 'android';

// App package name
const APP_PACKAGE = 'com.example.vocabulary_app';

// Progress tracking
let totalScenarios = 0;
let currentScenario = 0;
let passedCount = 0;
let failedCount = 0;
let undefinedCount = 0;
let skippedCount = 0;
let suiteStartTime = 0;
let scenarioStartTime = 0;
let currentStepIndex = 0;
let currentScenarioStepCount = 0;

function elapsed(): string {
    const secs = Math.floor((Date.now() - suiteStartTime) / 1000);
    const m = Math.floor(secs / 60);
    const s = secs % 60;
    return `${m}m${s.toString().padStart(2, '0')}s`;
}

function scenarioDuration(): string {
    const secs = Math.floor((Date.now() - scenarioStartTime) / 1000);
    return `${secs}s`;
}

function countScenarios(): number {
    const featuresDir = path.resolve(__dirname, '../features');
    let count = 0;
    try {
        const files = fs.readdirSync(featuresDir).filter(f => f.endsWith('.feature'));
        for (const file of files) {
            const content = fs.readFileSync(path.join(featuresDir, file), 'utf-8');
            const matches = content.match(/^\s*Scenario:/gm);
            if (matches) count += matches.length;
        }
    } catch (e) {}
    return count;
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

function delay(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
}

/**
 * Reset app data using pm clear - the most reliable way to wipe all app data.
 * This clears databases, shared_prefs, cache, files, and all other app data.
 */
async function resetAppData(): Promise<void> {
    if (platform !== 'android') return;

    try {
        await execCommand(`adb shell pm clear ${APP_PACKAGE}`);
        console.log('🗑️ App data reset (pm clear)');
    } catch (e) {
        // Silently ignore
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
            'appium:forceAppLaunch': true,
            'appium:newCommandTimeout': 240,
            'appium:autoGrantPermissions': true,
            'appium:showFlutterDriverLogs': true,
            'appium:retryBackoffTime': 5000,
            'appium:maxRetryCount': 5,
            'appium:skipPortForward': false,
            'appium:adbExecTimeout': 60000,
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
 * Before all scenarios - verify emulator health and clear app data
 */
BeforeAll(async function() {
    suiteStartTime = Date.now();
    totalScenarios = countScenarios();
    console.log(`🚀 Appium tests (${platform}) — ${totalScenarios} scenarios`);

    // Verify emulator health before starting
    try {
        await execCommand(`adb shell settings list system`);
        console.log('✅ Emulator health check passed');
    } catch (e) {
        console.error('❌ Emulator health check FAILED - settings service unavailable');
        throw new Error('Emulator is not healthy. Restart it and try again.');
    }

    // Clear logcat to prevent Flutter driver from matching stale Dart VM service URLs
    try {
        await execCommand(`adb logcat -c`);
        console.log('🗑️ Logcat cleared');
    } catch (e) {}

    // Use pm clear to fully wipe app data (only affects this app, not io.appium.settings)
    try {
        await execCommand(`adb shell pm clear ${APP_PACKAGE}`);
        console.log('🗑️ App data fully cleared (pm clear)');
    } catch (e) {
        // App may not be installed yet - that's fine
        console.log('ℹ️ App not installed yet, skipping data clear');
    }
});

/**
 * Create a new Appium session with retry logic
 */
async function createSession(maxRetries = 3): Promise<any> {
    const capabilities = getCapabilities();

    // Force-stop app and clear logcat before session creation
    // This ensures the Flutter driver finds the correct (new) Dart VM service URL
    try { await execCommand(`adb shell am force-stop ${APP_PACKAGE}`); } catch (e) {}
    try { await execCommand(`adb logcat -c`); } catch (e) {}
    await delay(1000);

    for (let attempt = 1; attempt <= maxRetries; attempt++) {
        try {
            const newDriver = await remote({
                hostname: 'localhost',
                port: 4723,
                path: '/',
                capabilities,
                logLevel: 'error'
            }) as any;
            await newDriver.pause(1500);
            return newDriver;
        } catch (error: any) {
            const msg = error.message?.substring(0, 80) || 'Unknown error';
            console.log(`⚠️ Session attempt ${attempt}/${maxRetries} failed: ${msg}`);

            if (attempt < maxRetries) {
                // Clean up stale processes and logcat
                try { await execCommand(`adb shell am force-stop ${APP_PACKAGE}`); } catch (e) {}
                try { await execCommand(`adb shell am force-stop io.appium.uiautomator2.server`); } catch (e) {}
                try { await execCommand(`adb shell am force-stop io.appium.uiautomator2.server.test`); } catch (e) {}
                try { await execCommand(`adb forward --remove-all`); } catch (e) {}
                try { await execCommand(`adb logcat -c`); } catch (e) {}
                await delay(5000);
            } else {
                throw error;
            }
        }
    }
}

/**
 * Before each scenario - reuse session or create new one
 */
Before(async function(this: any, { pickle }: ITestCaseHookParameter) {
    currentScenario++;
    scenarioStartTime = Date.now();
    currentStepIndex = 0;
    currentScenarioStepCount = pickle.steps?.length || 0;
    const feature = pickle.uri ? path.basename(pickle.uri, '.feature') : '';
    console.log(`\n[${currentScenario}/${totalScenarios}] ${elapsed()} | ${feature} > ${pickle.name}`);

    if (!sessionActive) {
        // First scenario - create new session
        driver = await createSession();
        sessionActive = true;
        console.log('✅ Session created');
    } else {
        // Reuse session - terminate and relaunch app for fresh state
        try {
            await driver.terminateApp(APP_PACKAGE);
            await delay(500);
            await resetAppData();
            await driver.activateApp(APP_PACKAGE);
            await delay(1500);
            console.log('✅ App relaunched');
        } catch (error: any) {
            // Session broken - recreate
            console.log(`⚠️ Session lost, recreating...`);
            try { await driver.deleteSession(); } catch (e) {}
            try { await execCommand(`adb shell am force-stop io.appium.uiautomator2.server`); } catch (e) {}
            try { await execCommand(`adb shell am force-stop io.appium.uiautomator2.server.test`); } catch (e) {}
            try { await execCommand(`adb forward --remove-all`); } catch (e) {}
            await delay(3000);

            driver = await createSession();
            console.log('✅ New session created');
        }
        sessionActive = true;
    }

    this.driver = driver;
});

/**
 * Before each step - log step progress
 */
BeforeStep(function({ pickleStep }: ITestStepHookParameter) {
    currentStepIndex++;
    const stepText = pickleStep.text || '';
    console.log(`  Step ${currentStepIndex}/${currentScenarioStepCount}: ${stepText}`);
});

/**
 * After each scenario - take screenshot on failure, track results
 */
After(async function(this: any, { pickle, result }: ITestCaseHookParameter) {
    const status = result?.status || 'UNKNOWN';
    const icon = status === 'PASSED' ? '✅' : status === 'FAILED' ? '❌' : status === 'UNDEFINED' ? '❓' : '⏭️';

    if (status === 'PASSED') passedCount++;
    else if (status === 'FAILED') failedCount++;
    else if (status === 'UNDEFINED') undefinedCount++;
    else skippedCount++;

    console.log(`${icon} ${status} (${scenarioDuration()}) [passed: ${passedCount} | failed: ${failedCount} | undefined: ${undefinedCount}]`);

    if (status === 'FAILED' && driver) {
        try {
            const screenshotName = `failure-${pickle.name.replace(/[^a-z0-9]/gi, '-')}.png`;
            await driver.saveScreenshot(`./screenshots/${screenshotName}`);
            console.log(`📸 Screenshot: ${screenshotName}`);
        } catch (error: any) {
            // Ignore screenshot errors
        }
    }
});

/**
 * After all scenarios - cleanup
 */
AfterAll(async function() {
    if (driver && sessionActive) {
        try {
            await driver.deleteSession();
            sessionActive = false;
        } catch (e) {}
    }

    // Final summary
    console.log(`\n${'═'.repeat(50)}`);
    console.log(`  RESULTS — ${elapsed()} total`);
    console.log(`${'═'.repeat(50)}`);
    console.log(`  ✅ Passed:    ${passedCount}`);
    console.log(`  ❌ Failed:    ${failedCount}`);
    console.log(`  ❓ Undefined: ${undefinedCount}`);
    console.log(`  ⏭️ Skipped:   ${skippedCount}`);
    console.log(`  📊 Total:     ${currentScenario}/${totalScenarios}`);
    console.log(`${'═'.repeat(50)}`);
    console.log('✅ Done');

    if (process.env.RESET_DB_AFTER !== 'false') {
        try {
            await execCommand(`adb shell pm clear ${APP_PACKAGE}`);
            console.log('🗑️ App data cleared (pm clear)');
        } catch (e) {}
    }
});

// Export driver getter for step definitions
export const getDriver = () => driver;

/**
 * Reset the session: clear app data and relaunch for a guaranteed fresh state.
 * Returns the driver instance with a clean app.
 */
export async function resetSession(): Promise<any> {
    if (!driver || !sessionActive) {
        throw new Error('No active session to reset');
    }
    console.log('🔄 Starting session reset...');

    // Terminate the app completely
    await driver.terminateApp(APP_PACKAGE);
    await delay(500);

    // Use pm clear to fully wipe all app data (most reliable method)
    console.log('🗑️ Clearing app data (pm clear)...');
    await resetAppData();
    await delay(500);

    // Relaunch using activateApp (maintains Flutter driver connection)
    console.log('🚀 Relaunching app...');
    await driver.activateApp(APP_PACKAGE);
    await delay(3000); // Give Flutter time to initialize and load data from (empty) DB

    console.log('🔄 Session reset complete');
    return driver;
}
