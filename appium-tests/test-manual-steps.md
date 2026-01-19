# Manual Testing Steps

Since the PowerShell background job has issues, follow these manual steps to run tests:

## Prerequisites
- Android emulator running: `adb devices` should show `emulator-5554`
- Node.js v22.22.0 installed

## Step 1: Start Appium Server

Open a **NEW** PowerShell/Command Prompt window and run:

```powershell
cd E:\Projects\Quiz\appium-tests
set ANDROID_HOME=C:\Users\thoma\AppData\Local\Android\sdk
set ANDROID_SDK_ROOT=C:\Users\thoma\AppData\Local\Android\sdk
set JAVA_HOME=C:\Program Files\Android\Android Studio\jbr
appium
```

Leave this window open. You should see:
```
[Appium] Welcome to Appium v3.1.2
[Appium] Appium REST http interface listener started on http://0.0.0.0:4723
```

## Step 2: Run Smoke Test

In a **SECOND** PowerShell/Command Prompt window:

```powershell
cd E:\Projects\Quiz\appium-tests
npm run test:smoke
```

This will run just ONE scenario (3 steps) to verify the setup works.

## Step 3: Run All Tests (if smoke test passes)

```powershell
cd E:\Projects\Quiz\appium-tests
npm test
```

## What Was Fixed

1. **Built APK in profile mode** (required for Appium Flutter Driver):
   - File: `vocabulary_app/build/app/outputs/flutter-apk/app-profile.apk`
   - Command used: `flutter build apk --profile --target lib/main_appium.dart`

2. **Updated hooks.ts** to use profile APK instead of debug APK

3. **Created smoke test** to run just one scenario instead of all 13

4. **Environment variables** are properly set in the manual commands

## Troubleshooting

If you get "Cannot connect to Dart Observatory" error:
- Make sure you're using the **profile APK** (not debug or release)
- Rebuild: `cd vocabulary_app && flutter build apk --profile --target lib/main_appium.dart`

If you get port errors:
- Restart ADB: `adb kill-server && adb start-server`
- Check emulator: `adb devices`

If tests fail to find elements:
- Verify the app has Keys defined in Flutter widgets
- Check that the APK is installed on emulator: `adb shell pm list packages | grep vocabulary`
