# VocabularyApp - Install Project Dependencies Only
# Use this script when Flutter/JDK/Android Studio are already installed
# No administrator privileges required

# Color output functions
function Write-Success { Write-Host "✓ $args" -ForegroundColor Green }
function Write-Info { Write-Host "ℹ $args" -ForegroundColor Cyan }
function Write-Warning { Write-Host "⚠ $args" -ForegroundColor Yellow }
function Write-Error-Custom { Write-Host "✗ $args" -ForegroundColor Red }
function Write-Step { Write-Host "`n===> $args" -ForegroundColor Magenta }

Write-Host @"
╔════════════════════════════════════════════════════════════╗
║       VocabularyApp - Install Dependencies                 ║
╚════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan

$projectRoot = $PSScriptRoot
if ($projectRoot -eq "") {
    $projectRoot = Get-Location
}

# Check prerequisites
Write-Step "Checking prerequisites..."

$hasFlutter = $null -ne (Get-Command flutter -ErrorAction SilentlyContinue)
$hasNode = $null -ne (Get-Command node -ErrorAction SilentlyContinue)
$hasNpm = $null -ne (Get-Command npm -ErrorAction SilentlyContinue)

if (!$hasFlutter) {
    Write-Error-Custom "Flutter not found! Please install Flutter first or run setup-project.ps1"
    exit 1
}

if (!$hasNode -or !$hasNpm) {
    Write-Error-Custom "Node.js/npm not found! Please install Node.js first"
    exit 1
}

Write-Success "Flutter: $(flutter --version 2>&1 | Select-String 'Flutter' | Select-Object -First 1)"
Write-Success "Node.js: $(node --version)"
Write-Success "npm: $(npm --version)"

# Install Flutter dependencies
Write-Step "Installing Flutter packages..."
Set-Location $projectRoot
try {
    flutter pub get
    Write-Success "Flutter packages installed"
}
catch {
    Write-Error-Custom "Failed to install Flutter packages: $_"
    exit 1
}

# Install Appium test dependencies
$appiumTestDir = Join-Path $projectRoot "appium-tests"
if (Test-Path $appiumTestDir) {
    Write-Step "Installing Appium test dependencies..."
    Set-Location $appiumTestDir
    try {
        npm install
        Write-Success "Appium test dependencies installed"
    }
    catch {
        Write-Error-Custom "Failed to install Appium dependencies: $_"
        Set-Location $projectRoot
        exit 1
    }
    Set-Location $projectRoot
} else {
    Write-Warning "Appium tests directory not found, skipping"
}

# Optional: Install Appium globally if not present
$hasAppium = $null -ne (Get-Command appium -ErrorAction SilentlyContinue)
if (!$hasAppium) {
    Write-Step "Installing Appium (optional for E2E testing)..."
    $install = Read-Host "Install Appium globally? (Y/N)"
    if ($install -eq "Y" -or $install -eq "y") {
        try {
            npm install -g appium
            appium driver install flutter
            Write-Success "Appium installed"
        }
        catch {
            Write-Warning "Failed to install Appium: $_"
        }
    }
}

Write-Step "Dependencies installed successfully!"
Write-Host "`n========================================" -ForegroundColor Green
Write-Host "READY TO GO!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "Run the app: flutter run" -ForegroundColor White
Write-Host "Run tests: flutter test" -ForegroundColor White
Write-Host "Run Appium tests: cd appium-tests && npm test" -ForegroundColor White
Write-Host "========================================`n" -ForegroundColor Green
