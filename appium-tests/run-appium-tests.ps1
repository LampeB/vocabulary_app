# Run Appium Tests
# Make sure Appium server is running before executing this script

param(
    [string]$Platform = "android"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Running Appium Tests - $Platform" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if Appium server is running
Write-Host "Checking if Appium server is running..." -ForegroundColor Yellow
$appiumRunning = Test-NetConnection -ComputerName localhost -Port 4723 -InformationLevel Quiet -WarningAction SilentlyContinue

if (-not $appiumRunning) {
    Write-Host "✗ Appium server is not running!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please start Appium server first:" -ForegroundColor Yellow
    Write-Host "  .\start-appium.ps1" -ForegroundColor Gray
    Write-Host ""
    exit 1
}

Write-Host "✓ Appium server is running" -ForegroundColor Green
Write-Host ""

# Set platform environment variable
$env:PLATFORM = $Platform

# Check if app is built
if ($Platform -eq "android") {
    $appPath = "..\vocabulary_app\build\app\outputs\flutter-apk\app-debug.apk"

    if (-not (Test-Path $appPath)) {
        Write-Host "✗ Android APK not found!" -ForegroundColor Red
        Write-Host ""
        Write-Host "Please build the app first:" -ForegroundColor Yellow
        Write-Host "  cd ..\vocabulary_app" -ForegroundColor Gray
        Write-Host "  flutter build apk --debug --target=lib/main_appium.dart" -ForegroundColor Gray
        Write-Host ""
        exit 1
    }

    Write-Host "✓ Android APK found" -ForegroundColor Green

    # Check if emulator is running
    Write-Host "Checking for Android emulator..." -ForegroundColor Yellow
    $devices = adb devices 2>$null | Select-String "emulator"

    if (-not $devices) {
        Write-Host "✗ No Android emulator found!" -ForegroundColor Red
        Write-Host ""
        Write-Host "Please start an Android emulator first" -ForegroundColor Yellow
        exit 1
    }

    Write-Host "✓ Android emulator is running" -ForegroundColor Green
} elseif ($Platform -eq "windows") {
    $appPath = "..\vocabulary_app\build\windows\x64\runner\Release\vocabulary_app.exe"

    if (-not (Test-Path $appPath)) {
        Write-Host "✗ Windows executable not found!" -ForegroundColor Red
        Write-Host ""
        Write-Host "Please build the app first:" -ForegroundColor Yellow
        Write-Host "  cd ..\vocabulary_app" -ForegroundColor Gray
        Write-Host "  flutter build windows --target=lib/main_appium.dart" -ForegroundColor Gray
        Write-Host ""
        exit 1
    }

    Write-Host "✓ Windows executable found" -ForegroundColor Green
}

Write-Host ""
Write-Host "Running tests..." -ForegroundColor Yellow
Write-Host ""

# Run tests
npm test

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "All Tests Passed!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Screenshots saved in: screenshots/" -ForegroundColor Gray
} else {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Tests Failed" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Cyan
}
