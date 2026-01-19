# PowerShell script to start Appium and run tests automatically
# This script starts Appium in the background, runs tests, and opens the report

# Set Android SDK and Java environment variables
$env:ANDROID_HOME = "C:\Users\thoma\AppData\Local\Android\sdk"
$env:ANDROID_SDK_ROOT = "C:\Users\thoma\AppData\Local\Android\sdk"
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"

Write-Host "Starting Appium server..." -ForegroundColor Cyan

# Start Appium in background with environment variables
$appiumJob = Start-Job -ScriptBlock {
    $env:ANDROID_HOME = "C:\Users\thoma\AppData\Local\Android\sdk"
    $env:ANDROID_SDK_ROOT = "C:\Users\thoma\AppData\Local\Android\sdk"
    $env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
    Set-Location $using:PSScriptRoot
    appium
}

Write-Host "Waiting for Appium server to start (10 seconds)..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

# Check if Appium is running
try {
    $response = Invoke-WebRequest -Uri "http://localhost:4723/status" -UseBasicParsing -TimeoutSec 5
    Write-Host "Appium server is ready!" -ForegroundColor Green
}
catch {
    Write-Host "Warning: Could not verify Appium server status, but continuing..." -ForegroundColor Yellow
}

# Run tests
Write-Host ""
Write-Host "Running tests..." -ForegroundColor Cyan
npm test

# Open report
Write-Host ""
Write-Host "Opening test report..." -ForegroundColor Cyan
Start-Process "reports/cucumber-report.html"

# Stop Appium
Write-Host ""
Write-Host "Stopping Appium server..." -ForegroundColor Yellow
Stop-Job -Job $appiumJob
Remove-Job -Job $appiumJob

Write-Host "Done!" -ForegroundColor Green
