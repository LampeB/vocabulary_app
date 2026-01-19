// WebdriverIO configuration for Appium Flutter Driver
const path = require('path');

// Determine platform from environment variable or default to Android
const platform = process.env.PLATFORM || 'android';

// Base configuration
const config = {
    runner: 'local',
    port: 4723,
    path: '/',

    specs: [
        './test/**/*.spec.js'
    ],

    exclude: [],

    maxInstances: 1,

    capabilities: [],

    logLevel: 'info',
    bail: 0,
    waitforTimeout: 30000,
    connectionRetryTimeout: 120000,
    connectionRetryCount: 3,

    framework: 'mocha',
    reporters: ['spec'],

    mochaOpts: {
        ui: 'bdd',
        timeout: 300000
    },

    // Hooks
    before: function (capabilities, specs) {
        console.log('Starting Appium test session...');
    },

    after: function (result, capabilities, specs) {
        console.log('Test session completed');
    }
};

// Platform-specific capabilities
if (platform === 'android') {
    const appPath = path.resolve('../vocabulary_app/build/app/outputs/flutter-apk/app-debug.apk');

    config.capabilities = [{
        platformName: 'Android',
        'appium:deviceName': 'Android Emulator',
        'appium:automationName': 'Flutter',
        'appium:app': appPath,
        'appium:noReset': false,
        'appium:fullReset': false,
        'appium:newCommandTimeout': 240,
        'appium:autoGrantPermissions': true,

        // Flutter-specific options
        'appium:showFlutterDriverLogs': true,
        'appium:flutterSystemPort': 4724,
        'appium:remoteAdbHost': 'localhost',
    }];
} else if (platform === 'windows') {
    const appPath = path.resolve('../vocabulary_app/build/windows/x64/runner/Release/vocabulary_app.exe');

    config.capabilities = [{
        platformName: 'Windows',
        'appium:automationName': 'Flutter',
        'appium:app': appPath,
        'appium:deviceName': 'WindowsPC',

        // Flutter-specific options
        'appium:showFlutterDriverLogs': true,
    }];
}

exports.config = config;
