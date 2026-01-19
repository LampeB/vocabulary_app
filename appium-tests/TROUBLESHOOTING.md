# Troubleshooting Guide

## Current Status

Your test suite is fully set up, but the smoke test is timing out during the Before hook. This means Appium is trying to create a session but cannot connect to the Flutter app.

## Error: "function timed out, ensure the promise resolves within 300000 milliseconds"

**What this means**: Appium Flutter Driver cannot establish a connection to the Dart VM in your Flutter app.

### Verification Checklist

Run these commands to verify your setup:

```bash
# 1. Check Android SDK is accessible
echo %ANDROID_HOME%
# Should show: C:\Users\thoma\AppData\Local\Android\sdk

# 2. Check Java is accessible
echo %JAVA_HOME%
# Should show: C:\Program Files\Android\Android Studio\jbr

# 3. Check emulator is running
adb devices
# Should show: emulator-5554   device

# 4. Check Appium is running
curl http://localhost:4723/status
# Should return JSON with "ready": true

# 5. Check APK exists
dir vocabulary_app\build\app\outputs\flutter-apk\app-profile.apk
# Should show the file (72MB)

# 6. Check Flutter Driver is installed
appium driver list --installed
# Should show: flutter@3.3.0 [installed (npm)]
```

## Common Solutions

### Solution 1: Enable Flutter Driver Extension (RECOMMENDED)

The issue might be that even in profile mode, Flutter needs the driver extension enabled. Update `main_appium.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_driver/driver_extension.dart';
import 'main.dart' as app;

void main() {
  // Enable Flutter Driver extension
  enableFlutterDriverExtension();

  // Run the app
  app.main();
}
```

Then rebuild:
```bash
cd vocabulary_app
flutter build apk --profile --target lib/main_appium.dart
```

### Solution 2: Add flutter_driver Dependency

Add to `vocabulary_app/pubspec.yaml`:

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_driver:
    sdk: flutter
```

Then:
```bash
cd vocabulary_app
flutter pub get
flutter build apk --profile --target lib/main_appium.dart
```

### Solution 3: Use Debug Mode with --observatory-port

Some Flutter/Appium setups work better with debug mode:

```bash
cd vocabulary_app
flutter build apk --debug --target lib/main_appium.dart
```

Update hooks.ts to use `app-debug.apk` again.

### Solution 4: Verify Appium Can Install the APK

Manually test if Appium can install and launch the app:

```bash
# Install APK manually
adb install -r vocabulary_app/build/app/outputs/flutter-apk/app-profile.apk

# Launch it manually
adb shell am start -n com.example.vocabulary_app/com.example.vocabulary_app.MainActivity

# Check if it shows Observatory URL
adb logcat | grep -i observatory
# Should show something like: "Observatory listening on http://127.0.0.1:XXXXX"
```

### Solution 5: Check Appium Logs

When Appium times out, check its console output. Look for:
- "Cannot connect to the Dart Observatory"
- "No observatory URL found"
- Any ADB errors

## Testing Steps After Fix

1. **Rebuild the APK** with the chosen solution
2. **Restart everything**:
   ```bash
   # Kill all
   taskkill /F /IM node.exe
   adb kill-server
   adb start-server
   ```

3. **Start Appium** (use START-APPIUM-HERE.bat)

4. **Run smoke test**:
   ```bash
   cd appium-tests
   npm run test:smoke
   ```

## Alternative: Test with Appium Inspector

Download [Appium Inspector](https://github.com/appium/appium-inspector/releases) to manually test the connection:

1. Set capabilities:
   ```json
   {
     "platformName": "Android",
     "appium:automationName": "Flutter",
     "appium:deviceName": "emulator-5554",
     "appium:app": "E:/Projects/Quiz/vocabulary_app/build/app/outputs/flutter-apk/app-profile.apk"
   }
   ```

2. Click "Start Session"
3. If it connects, your setup is correct
4. If it fails, the error message will tell you exactly what's wrong

## Known Working Configuration

According to Appium Flutter Driver docs, the working setup is:

1. **APK built in debug or profile mode** ✅ (we have profile)
2. **Flutter Driver extension enabled** ⚠️ (we need to verify this)
3. **Android emulator running** ✅
4. **Appium 3.x installed** ✅ (we have 3.1.2)
5. **Flutter Driver plugin installed** ✅ (we have 3.3.0)

The missing piece is likely #2 - enabling the Flutter Driver extension.

## Next Steps

1. Try Solution 1 (enable extension in main_appium.dart)
2. If that doesn't work, try Solution 2 (add flutter_driver dependency)
3. Use Appium Inspector to get more detailed error messages
4. Check Appium server logs when the test runs

## Getting Help

If issues persist, gather these logs and check:
- Appium server output during test run
- `adb logcat` output when app launches
- Test output with `--verbose` flag

The error message in the Appium logs will tell you exactly what's preventing the connection.
