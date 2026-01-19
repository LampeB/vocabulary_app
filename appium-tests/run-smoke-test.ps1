# PowerShell script to run a single smoke test
# This helps verify the Appium setup works before running all tests

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

Write-Host "Waiting for Appium server to start..." -ForegroundColor Yellow

# Wait up to 30 seconds for Appium to be ready
$maxAttempts = 30
$attempt = 0
$appiumReady = $false

while ($attempt -lt $maxAttempts -and -not $appiumReady) {
    $attempt++
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:4723/status" -UseBasicParsing -TimeoutSec 2 -ErrorAction Stop
        Write-Host "Appium server is ready!" -ForegroundColor Green
        $appiumReady = $true
    }
    catch {
        Write-Host "Waiting... ($attempt/$maxAttempts)" -ForegroundColor Yellow
        Start-Sleep -Seconds 1
    }
}

if (-not $appiumReady) {
    Write-Host "ERROR: Appium server failed to start!" -ForegroundColor Red
    Stop-Job -Job $appiumJob -ErrorAction SilentlyContinue
    Remove-Job -Job $appiumJob -ErrorAction SilentlyContinue
    exit 1
}

# Run smoke test only
Write-Host ""
Write-Host "Running smoke test..." -ForegroundColor Cyan
npx cucumber-js features/smoke.feature

# Stop Appium
Write-Host ""
Write-Host "Stopping Appium server..." -ForegroundColor Yellow
Stop-Job -Job $appiumJob
Remove-Job -Job $appiumJob

Write-Host "Done!" -ForegroundColor Green
