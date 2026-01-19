/**
 * Script de test pour vérifier les finders Flutter
 * Usage: npx ts-node test-finder.ts
 */

import { remote } from 'webdriverio';
// @ts-ignore
import { byValueKey, byText } from 'appium-flutter-finder';
import * as path from 'path';

async function testFinder() {
    console.log('=== Test Finder Flutter ===\n');

    // Afficher ce que retournent les finders
    console.log('byValueKey("home_screen") =>', byValueKey('home_screen'));
    console.log('byText("Mes Listes") =>', byText('Mes Listes'));

    const appPath = path.resolve(__dirname, '../vocabulary_app/build/app/outputs/flutter-apk/app-debug.apk');
    console.log('\nAPK Path:', appPath);

    const driver = await remote({
        hostname: 'localhost',
        port: 4723,
        path: '/',
        capabilities: {
            platformName: 'Android',
            'appium:deviceName': 'Android Emulator',
            'appium:automationName': 'Flutter',
            'appium:app': appPath,
            'appium:noReset': true,
        },
        logLevel: 'info'
    });

    console.log('\n✓ Driver created, app launched');
    console.log('Waiting 5 seconds for app to load...');
    await driver.pause(5000);

    try {
        // Test 1: Essayer avec byValueKey
        console.log('\n--- Test 1: byValueKey("home_screen") ---');
        const keyFinder = byValueKey('home_screen');
        console.log('Finder object:', JSON.stringify(keyFinder));

        try {
            const result = await driver.execute('flutter:waitFor', keyFinder, 5000);
            console.log('✓ Found by key! Result:', result);
        } catch (e: any) {
            console.log('✗ Failed by key:', e.message);
        }

        // Test 2: Essayer avec byText
        console.log('\n--- Test 2: byText("Mes Listes") ---');
        const textFinder = byText('Mes Listes');
        console.log('Finder object:', JSON.stringify(textFinder));

        try {
            const result = await driver.execute('flutter:waitFor', textFinder, 5000);
            console.log('✓ Found by text! Result:', result);
        } catch (e: any) {
            console.log('✗ Failed by text:', e.message);
        }

        // Test 3: Essayer flutter:checkHealth
        console.log('\n--- Test 3: flutter:checkHealth ---');
        try {
            const health = await driver.execute('flutter:checkHealth');
            console.log('✓ Health check:', health);
        } catch (e: any) {
            console.log('✗ Health check failed:', e.message);
        }

        // Test 4: Lister les commandes flutter disponibles
        console.log('\n--- Test 4: flutter:getRenderTree ---');
        try {
            const tree = await driver.execute('flutter:getRenderTree');
            console.log('✓ Got render tree (first 500 chars):', JSON.stringify(tree).substring(0, 500));
        } catch (e: any) {
            console.log('✗ getRenderTree failed:', e.message);
        }

    } finally {
        console.log('\n--- Cleanup ---');
        await driver.deleteSession();
        console.log('✓ Session closed');
    }
}

testFinder().catch(console.error);
