# VocabularyApp Project Setup Script
# This script automatically downloads and installs all required dependencies
# Intelligently detects what's already installed and only installs what's missing

param(
    [switch]$SkipFlutter,
    [switch]$SkipJDK,
    [switch]$SkipAndroidStudio,
    [switch]$SkipAppium,
    [switch]$Force
)

# Configuration
$ErrorActionPreference = "Stop"
$ProgressPreference = 'SilentlyContinue'

# URLs for downloads
$FLUTTER_URL = "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.24.5-stable.zip"
$JDK_URL = "https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.5%2B11/OpenJDK21U-jdk_x64_windows_hotspot_21.0.5_11.msi"
$ANDROID_STUDIO_URL = "https://redirector.gvt1.com/edgedl/android/studio/install/2024.2.1.12/android-studio-2024.2.1.12-windows.exe"

# Installation directories
$INSTALL_DIR = "C:\Development"
$FLUTTER_DIR = "$INSTALL_DIR\flutter"
$TEMP_DIR = "$env:TEMP\vocabulary_app_setup"

# Track what needs to be installed
$script:needsInstall = @{
    Flutter = $false
    JDK = $false
    AndroidStudio = $false
    Appium = $false
    NodeJS = $false
}

$script:needsAdmin = $false
# Helper functions
function Test-Administrator {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-Command {
    param($Command)
    $null = Get-Command $Command -ErrorAction SilentlyContinue
    return $?
}

function Initialize-Directories {
    if (!(Test-Path $INSTALL_DIR)) {
        New-Item -ItemType Directory -Path $INSTALL_DIR -Force | Out-Null
    }
    if (!(Test-Path $TEMP_DIR)) {
        New-Item -ItemType Directory -Path $TEMP_DIR -Force | Out-Null
    }
}

# Check installations
function Test-FlutterInstalled {
    if ($Force) { return $false }
    if (Test-Command "flutter") {
        try {
            $version = flutter --version 2>&1 | Select-String "Flutter" | Select-Object -First 1
            Write-Host "[OK] Flutter already installed: $version" -ForegroundColor Green
            return $true
        }
        catch { return $false }
    }
    if (Test-Path "$FLUTTER_DIR\bin\flutter.bat") {
        Write-Host "[OK] Flutter found at $FLUTTER_DIR" -ForegroundColor Green
        return $true
    }
    return $false
}

function Test-JDKInstalled {
    if ($Force) { return $false }
    if (Test-Command "java") {
        try {
            $version = java -version 2>&1 | Select-String "version" | Select-Object -First 1
            Write-Host "[OK] Java JDK already installed: $version" -ForegroundColor Green
            return $true
        }
        catch { return $false }
    }
    $jdkPaths = @(
        "${env:ProgramFiles}\Eclipse Adoptium",
        "${env:ProgramFiles}\Java",
        "${env:ProgramFiles(x86)}\Java"
    )
    foreach ($path in $jdkPaths) {
        if (Test-Path $path) {
            Write-Host "[OK] Java JDK found at $path" -ForegroundColor Green
            return $true
        }
    }
    return $false
}

function Test-AndroidStudioInstalled {
    if ($Force) { return $false }
    $asPaths = @(
        "${env:ProgramFiles}\Android\Android Studio",
        "${env:LOCALAPPDATA}\Programs\Android Studio",
        "${env:ProgramFiles(x86)}\Android\Android Studio"
    )
    foreach ($path in $asPaths) {
        if (Test-Path "$path\bin\studio64.exe") {
            Write-Host "[OK] Android Studio found at $path" -ForegroundColor Green
            return $true
        }
    }
    return $false
}

function Test-NodeJSInstalled {
    if (Test-Command "node") {
        $nodeVersion = node --version
        $npmVersion = npm --version
        Write-Host "[OK] Node.js $nodeVersion and npm $npmVersion already installed" -ForegroundColor Green
        return $true
    }
    return $false
}

function Test-AppiumInstalled {
    if ($Force) { return $false }
    if (Test-Command "appium") {
        try {
            $version = appium --version 2>&1
            Write-Host "[OK] Appium already installed: v$version" -ForegroundColor Green
            return $true
        }
        catch { return $false }
    }
    return $false
}

# Detect what needs installation
function Get-InstallationNeeds {
    Write-Host "`n==> Checking what's already installed...`n" -ForegroundColor Magenta

    if (!(Test-NodeJSInstalled)) {
        $script:needsInstall.NodeJS = $true
        Write-Host "[ERROR] Node.js is NOT installed (required)" -ForegroundColor Red
    }

    if (!$SkipFlutter -and !(Test-FlutterInstalled)) {
        $script:needsInstall.Flutter = $true
        $script:needsAdmin = $true
        Write-Host "[MISSING] Flutter needs to be installed" -ForegroundColor Yellow
    }

    if (!$SkipJDK -and !(Test-JDKInstalled)) {
        $script:needsInstall.JDK = $true
        $script:needsAdmin = $true
        Write-Host "[MISSING] Java JDK needs to be installed" -ForegroundColor Yellow
    }

    if (!$SkipAndroidStudio -and !(Test-AndroidStudioInstalled)) {
        $script:needsInstall.AndroidStudio = $true
        $script:needsAdmin = $true
        Write-Host "[MISSING] Android Studio needs to be installed" -ForegroundColor Yellow
    }

    if (!$SkipAppium -and !(Test-AppiumInstalled)) {
        $script:needsInstall.Appium = $true
        Write-Host "[MISSING] Appium needs to be installed" -ForegroundColor Yellow
    }

    $installCount = ($script:needsInstall.Values | Where-Object { $_ -eq $true }).Count

    if ($script:needsInstall.NodeJS) {
        Write-Host "`n========================================" -ForegroundColor Red
        Write-Host "ERROR: Node.js is required!" -ForegroundColor Red
        Write-Host "========================================" -ForegroundColor Red
        Write-Host "Please install Node.js first from: https://nodejs.org/" -ForegroundColor Yellow
        Write-Host "Then run this script again.`n" -ForegroundColor Yellow
        exit 1
    }

    if ($installCount -eq 0) {
        Write-Host "`n========================================" -ForegroundColor Green
        Write-Host "ALL REQUIRED TOOLS ALREADY INSTALLED!" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Green
        Write-Host "Skipping to project dependencies installation...`n" -ForegroundColor Cyan
        return $false
    }

    Write-Host "`n========================================" -ForegroundColor Yellow
    Write-Host "INSTALLATION PLAN" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Yellow
    if ($script:needsInstall.Flutter) { Write-Host "* Flutter SDK" }
    if ($script:needsInstall.JDK) { Write-Host "* Java JDK 21" }
    if ($script:needsInstall.AndroidStudio) { Write-Host "* Android Studio" }
    if ($script:needsInstall.Appium) { Write-Host "* Appium + Flutter Driver" }
    Write-Host "========================================`n" -ForegroundColor Yellow

    return $true
}

# Download and install functions
function Download-File {
    param([string]$Url, [string]$Output, [string]$Name)
    Write-Host "Downloading $Name..." -ForegroundColor Cyan
    try {
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($Url, $Output)
        Write-Host "[OK] Downloaded $Name" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "[ERROR] Failed to download $Name : $_" -ForegroundColor Red
        return $false
    }
}

function Add-ToPath {
    param([string]$PathToAdd)
    $currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    if ($currentPath -notlike "*$PathToAdd*") {
        Write-Host "Adding to PATH: $PathToAdd" -ForegroundColor Cyan
        [Environment]::SetEnvironmentVariable("Path", "$currentPath;$PathToAdd", "Machine")
        $env:Path = "$env:Path;$PathToAdd"
        Write-Host "[OK] Added to PATH" -ForegroundColor Green
    } else {
        Write-Host "Already in PATH: $PathToAdd" -ForegroundColor Cyan
    }
}

function Install-Flutter {
    if (!$script:needsInstall.Flutter) { return }
    Write-Host "`n==> Installing Flutter SDK...`n" -ForegroundColor Magenta
    $zipFile = "$TEMP_DIR\flutter.zip"
    if (Download-File -Url $FLUTTER_URL -Output $zipFile -Name "Flutter SDK") {
        Write-Host "Extracting Flutter SDK (this may take a few minutes)..." -ForegroundColor Cyan
        Expand-Archive -Path $zipFile -DestinationPath $INSTALL_DIR -Force
        Write-Host "[OK] Flutter SDK extracted to $FLUTTER_DIR" -ForegroundColor Green
        Add-ToPath "$FLUTTER_DIR\bin"
        Remove-Item $zipFile -Force -ErrorAction SilentlyContinue
    }
}

function Install-JDK {
    if (!$script:needsInstall.JDK) { return }
    Write-Host "`n==> Installing Java JDK...`n" -ForegroundColor Magenta
    $msiFile = "$TEMP_DIR\openjdk.msi"
    if (Download-File -Url $JDK_URL -Output $msiFile -Name "OpenJDK 21") {
        Write-Host "Installing OpenJDK (this may take a few minutes)..." -ForegroundColor Cyan
        Start-Process msiexec.exe -ArgumentList "/i `"$msiFile`" /quiet /norestart" -Wait -NoNewWindow
        Write-Host "[OK] Java JDK installed" -ForegroundColor Green
        Remove-Item $msiFile -Force -ErrorAction SilentlyContinue
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    }
}

function Install-AndroidStudio {
    if (!$script:needsInstall.AndroidStudio) { return }
    Write-Host "`n==> Installing Android Studio...`n" -ForegroundColor Magenta
    $exeFile = "$TEMP_DIR\android-studio.exe"
    if (Download-File -Url $ANDROID_STUDIO_URL -Output $exeFile -Name "Android Studio") {
        Write-Host "Installing Android Studio (this may take 10-15 minutes)..." -ForegroundColor Cyan
        Write-Host "[WARNING] The installer may open a window - please wait for it to complete" -ForegroundColor Yellow
        Start-Process -FilePath $exeFile -ArgumentList "/S" -Wait -NoNewWindow
        Write-Host "[OK] Android Studio installed" -ForegroundColor Green
        Remove-Item $exeFile -Force -ErrorAction SilentlyContinue
        Write-Host "`n[IMPORTANT] After setup completes, open Android Studio and:" -ForegroundColor Yellow
        Write-Host "  1. Complete the setup wizard" -ForegroundColor Yellow
        Write-Host "  2. Install Android SDK" -ForegroundColor Yellow
        Write-Host "  3. Accept Android licenses: flutter doctor --android-licenses`n" -ForegroundColor Yellow
    }
}

function Install-Appium {
    if (!$script:needsInstall.Appium) { return }
    Write-Host "`n==> Installing Appium...`n" -ForegroundColor Magenta
    Write-Host "Installing Appium globally..." -ForegroundColor Cyan
    npm install -g appium
    Write-Host "[OK] Appium installed" -ForegroundColor Green
    Write-Host "Installing Appium Flutter driver..." -ForegroundColor Cyan
    appium driver install flutter
    Write-Host "[OK] Appium Flutter driver installed" -ForegroundColor Green
}

function Install-ProjectDependencies {
    Write-Host "`n==> Installing project dependencies...`n" -ForegroundColor Magenta
    $projectRoot = Split-Path -Parent $PSScriptRoot
    if ($PSScriptRoot -eq "") { $projectRoot = Get-Location }

    if (Test-Command "flutter") {
        Write-Host "Installing Flutter packages..." -ForegroundColor Cyan
        Set-Location $projectRoot
        flutter pub get
        Write-Host "[OK] Flutter packages installed" -ForegroundColor Green
    } else {
        Write-Host "[WARNING] Flutter not found in PATH. Skipping flutter pub get" -ForegroundColor Yellow
        Write-Host "[WARNING] After restarting your terminal, run: flutter pub get" -ForegroundColor Yellow
    }

    $appiumTestDir = Join-Path $projectRoot "appium-tests"
    if (Test-Path $appiumTestDir) {
        Write-Host "Installing Appium test dependencies..." -ForegroundColor Cyan
        Set-Location $appiumTestDir
        npm install
        Write-Host "[OK] Appium test dependencies installed" -ForegroundColor Green
        Set-Location $projectRoot
    }
}

function Show-InstallationSummary {
    Write-Host "`n==> Installation Summary`n" -ForegroundColor Magenta
    $results = @()

    if (Test-Command "flutter") {
        $flutterVersion = flutter --version 2>&1 | Select-String "Flutter" | Select-Object -First 1
        $results += @{ Tool = "Flutter"; Status = "[OK]"; Info = $flutterVersion }
    } else {
        $results += @{ Tool = "Flutter"; Status = "[--]"; Info = "Not found in PATH (restart terminal)" }
    }

    if (Test-Command "dart") {
        $dartVersion = dart --version 2>&1
        $results += @{ Tool = "Dart"; Status = "[OK]"; Info = $dartVersion }
    } else {
        $results += @{ Tool = "Dart"; Status = "[--]"; Info = "Not found (comes with Flutter)" }
    }

    if (Test-Command "java") {
        $javaVersion = java -version 2>&1 | Select-String "version" | Select-Object -First 1
        $results += @{ Tool = "Java"; Status = "[OK]"; Info = $javaVersion }
    } else {
        $results += @{ Tool = "Java"; Status = "[--]"; Info = "Not found in PATH (restart terminal)" }
    }

    if (Test-Command "node") {
        $nodeVersion = node --version
        $results += @{ Tool = "Node.js"; Status = "[OK]"; Info = $nodeVersion }
    } else {
        $results += @{ Tool = "Node.js"; Status = "[--]"; Info = "Not found" }
    }

    if (Test-Command "npm") {
        $npmVersion = npm --version
        $results += @{ Tool = "npm"; Status = "[OK]"; Info = $npmVersion }
    } else {
        $results += @{ Tool = "npm"; Status = "[--]"; Info = "Not found" }
    }

    if (Test-Command "appium") {
        $appiumVersion = appium --version 2>&1
        $results += @{ Tool = "Appium"; Status = "[OK]"; Info = "v$appiumVersion" }
    } else {
        $results += @{ Tool = "Appium"; Status = "[--]"; Info = "Not found" }
    }

    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "INSTALLATION SUMMARY" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    foreach ($result in $results) {
        $statusColor = if ($result.Status -eq "[OK]") { "Green" } else { "Yellow" }
        Write-Host "$($result.Status) $($result.Tool): " -ForegroundColor $statusColor -NoNewline
        Write-Host $result.Info -ForegroundColor Gray
    }
    Write-Host "========================================`n" -ForegroundColor Cyan
}

# Main execution
function Main {
    Write-Host @"

========================================================
   VocabularyApp Project Setup Installer v2.0
   Smart Installation - Only Installs What's Missing
========================================================

"@ -ForegroundColor Cyan

    $needsInstallation = Get-InstallationNeeds

    if ($script:needsAdmin -and !(Test-Administrator)) {
        Write-Host "`n========================================" -ForegroundColor Red
        Write-Host "ADMINISTRATOR PRIVILEGES REQUIRED" -ForegroundColor Red
        Write-Host "========================================" -ForegroundColor Red
        Write-Host "Some installations require admin privileges." -ForegroundColor Yellow
        Write-Host "Please run PowerShell as Administrator and try again.`n" -ForegroundColor Yellow
        Write-Host "Right-click PowerShell -> Run as Administrator`n" -ForegroundColor White
        exit 1
    }

    if (!$needsInstallation) {
        Install-ProjectDependencies
        Show-InstallationSummary
        Write-Host "`n========================================" -ForegroundColor Green
        Write-Host "READY TO GO!" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Green
        Write-Host "Run the app: flutter run" -ForegroundColor White
        Write-Host "Run tests: flutter test" -ForegroundColor White
        Write-Host "========================================`n" -ForegroundColor Green
        return
    }

    $continue = Read-Host "`nContinue with installation? (Y/N)"
    if ($continue -ne "Y" -and $continue -ne "y") {
        Write-Host "Installation cancelled" -ForegroundColor Cyan
        exit
    }

    $startTime = Get-Date

    try {
        Initialize-Directories
        Install-Flutter
        Install-JDK
        Install-AndroidStudio
        Install-Appium
        Install-ProjectDependencies

        $endTime = Get-Date
        $duration = $endTime - $startTime

        Write-Host "`n==> Installation Complete!" -ForegroundColor Magenta
        Write-Host "[OK] Total time: $($duration.ToString('mm\:ss'))" -ForegroundColor Green

        Show-InstallationSummary

        Write-Host "`n========================================" -ForegroundColor Yellow
        Write-Host "NEXT STEPS:" -ForegroundColor Yellow
        Write-Host "========================================" -ForegroundColor Yellow
        Write-Host "1. RESTART your terminal/PowerShell" -ForegroundColor White
        Write-Host "2. Run: flutter doctor" -ForegroundColor White
        if ($script:needsInstall.AndroidStudio) {
            Write-Host "3. Open Android Studio and complete setup wizard" -ForegroundColor White
            Write-Host "4. Accept Android licenses: flutter doctor --android-licenses" -ForegroundColor White
            Write-Host "5. Navigate to project and run: flutter run" -ForegroundColor White
        } else {
            Write-Host "3. Navigate to project and run: flutter run" -ForegroundColor White
        }
        Write-Host "========================================`n" -ForegroundColor Yellow

    }
    catch {
        Write-Host "`n[ERROR] Installation failed: $_" -ForegroundColor Red
        Write-Host $_.ScriptStackTrace -ForegroundColor Red
        exit 1
    }
    finally {
        if (Test-Path $TEMP_DIR) {
            Write-Host "Cleaning up temporary files..." -ForegroundColor Cyan
            Remove-Item $TEMP_DIR -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# Run main function
Main
