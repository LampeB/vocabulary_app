# Start Appium Server
# Run this before executing tests

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Starting Appium Server" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Appium server will start on port 4723" -ForegroundColor Yellow
Write-Host "Press Ctrl+C to stop the server" -ForegroundColor Gray
Write-Host ""

# Start Appium with logging
appium --log-level info --allow-insecure chromedriver_autodownload
