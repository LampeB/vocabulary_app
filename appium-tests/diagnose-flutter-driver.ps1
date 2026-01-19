# Diagnostic script for Appium Flutter Driver issues
# This helps identify why Observatory connection fails

Write-Host "=== Appium Flutter Driver Diagnostic ===" -ForegroundColor Cyan
Write-Host ""

# Step 1: Check versions
Write-Host "Step 1: Checking versions..." -ForegroundColor Yellow
Write-Host "Appium version:" -NoNewline
appium --version
Write-Host "Flutter Driver (global):"
appium driver list --installed | Select-String "flutter"
Write-Host "Flutter version:"
cd ..\vocabulary_app
flutter --version | Select-String "Flutter"
cd ..\appium-tests
Write-Host ""

# Step 2: Check environment
Write-Host "Step 2: Checking environment variables..." -ForegroundColor Yellow
Write-Host "ANDROID_HOME: $env:ANDROID_HOME"
Write-Host "JAVA_HOME: $env:JAVA_HOME"
Write-Host ""

# Step 3: Check emulator
Write-Host "Step 3: Checking Android emulator..." -ForegroundColor Yellow
adb devices
Write-Host ""

# Step 4: Check if app is installed
Write-Host "Step 4: Checking if app is installed..." -ForegroundColor Yellow
$appInstalled = adb shell pm list packages | Select-String "vocabulary"
if ($appInstalled) {
    Write-Host "[OK] App is installed: $appInstalled" -ForegroundColor Green
} else {
    Write-Host "[ERROR] App is not installed" -ForegroundColor Red
}
Write-Host ""

# Step 5: Install and launch app manually
Write-Host "Step 5: Installing debug APK..." -ForegroundColor Yellow
adb install -r ..\vocabulary_app\build\app\outputs\flutter-apk\app-debug.apk
Write-Host ""

Write-Host "Step 6: Launching app..." -ForegroundColor Yellow
adb shell am start -n com.example.vocabulary_app/com.example.vocabulary_app.MainActivity
Start-Sleep -Seconds 3
Write-Host ""

# Step 7: Check for Observatory/VM Service URL
Write-Host "Step 7: Checking for Dart VM Service URL..." -ForegroundColor Yellow
Write-Host "Searching logcat for VM Service URL..."
$logcat = adb logcat -d | Select-String -Pattern "Observatory|Dart VM service"
if ($logcat) {
    Write-Host "[OK] Found VM Service entries:" -ForegroundColor Green
    $logcat | ForEach-Object { Write-Host $_ -ForegroundColor White }
} else {
    Write-Host "[ERROR] No VM Service URL found in logcat!" -ForegroundColor Red
    Write-Host "This means flutter_driver extension is not working properly." -ForegroundColor Red
}
Write-Host ""

# Step 8: Check for flutter_driver
Write-Host "Step 8: Checking main_appium.dart..." -ForegroundColor Yellow
$mainAppium = Get-Content ..\vocabulary_app\lib\main_appium.dart
if ($mainAppium -match "enableFlutterDriverExtension") {
    Write-Host "[OK] enableFlutterDriverExtension is present" -ForegroundColor Green
} else {
    Write-Host "[ERROR] enableFlutterDriverExtension is MISSING!" -ForegroundColor Red
}
Write-Host ""

# Step 9: Check pubspec.yaml
Write-Host "Step 9: Checking pubspec.yaml..." -ForegroundColor Yellow
$pubspec = Get-Content ..\vocabulary_app\pubspec.yaml
if ($pubspec -match "flutter_driver") {
    Write-Host "[OK] flutter_driver dependency found" -ForegroundColor Green
} else {
    Write-Host "[ERROR] flutter_driver dependency MISSING!" -ForegroundColor Red
}
Write-Host ""

Write-Host "=== Diagnostic Complete ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "If Observatory URL was found above, copy it and we'll use it directly." -ForegroundColor Yellow
Write-Host "If no Observatory URL, the flutter_driver extension is not enabled correctly." -ForegroundColor Yellow
