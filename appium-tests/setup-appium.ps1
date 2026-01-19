# Appium Setup Script for VocabApp
# Run this once to set up Appium and Flutter Driver

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Appium + Flutter Driver Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$ErrorActionPreference = "Continue"

# Check Node.js
Write-Host "[1/6] Checking Node.js..." -ForegroundColor Yellow
$nodeVersion = node --version 2>$null

if ($nodeVersion) {
    Write-Host "  ✓ Node.js installed: $nodeVersion" -ForegroundColor Green
} else {
    Write-Host "  ✗ Node.js not found!" -ForegroundColor Red
    Write-Host "  Please install Node.js from: https://nodejs.org/" -ForegroundColor Yellow
    exit 1
}

# Install npm dependencies
Write-Host ""
Write-Host "[2/6] Installing npm dependencies..." -ForegroundColor Yellow
npm install

if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✓ Dependencies installed" -ForegroundColor Green
} else {
    Write-Host "  ✗ Failed to install dependencies" -ForegroundColor Red
    exit 1
}

# Install Appium globally
Write-Host ""
Write-Host "[3/6] Installing Appium globally..." -ForegroundColor Yellow
npm install -g appium

if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✓ Appium installed" -ForegroundColor Green
} else {
    Write-Host "  ✗ Failed to install Appium" -ForegroundColor Red
    exit 1
}

# Install Flutter Driver
Write-Host ""
Write-Host "[4/6] Installing Appium Flutter Driver..." -ForegroundColor Yellow
appium driver install --source=npm appium-flutter-driver

if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✓ Flutter Driver installed" -ForegroundColor Green
} else {
    Write-Host "  ✗ Failed to install Flutter Driver" -ForegroundColor Red
    exit 1
}

# Verify installation
Write-Host ""
Write-Host "[5/6] Verifying installation..." -ForegroundColor Yellow
$appiumVersion = appium --version 2>$null

if ($appiumVersion) {
    Write-Host "  ✓ Appium version: $appiumVersion" -ForegroundColor Green
} else {
    Write-Host "  ✗ Appium verification failed" -ForegroundColor Red
}

# List installed drivers
Write-Host ""
Write-Host "[6/6] Installed Appium drivers:" -ForegroundColor Yellow
appium driver list --installed

# Create screenshots directory
if (-not (Test-Path "screenshots")) {
    New-Item -ItemType Directory -Path "screenshots" | Out-Null
    Write-Host "  ✓ Created screenshots directory" -ForegroundColor Green
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Setup Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Build your Flutter app for testing:" -ForegroundColor White
Write-Host "     cd ..\vocabulary_app" -ForegroundColor Gray
Write-Host "     flutter build apk --debug --target=lib/main_appium.dart" -ForegroundColor Gray
Write-Host ""
Write-Host "  2. Start Appium server:" -ForegroundColor White
Write-Host "     .\start-appium.ps1" -ForegroundColor Gray
Write-Host ""
Write-Host "  3. Run tests (in another terminal):" -ForegroundColor White
Write-Host "     .\run-appium-tests.ps1" -ForegroundColor Gray
Write-Host ""
