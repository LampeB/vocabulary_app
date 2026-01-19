# =============================================================================
# Script complet pour lancer les tests Appium
# Usage: .\run-all.ps1
# =============================================================================

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "   LANCEMENT DES TESTS APPIUM" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""

# Configuration des variables d'environnement
$env:ANDROID_HOME = "C:\Users\thoma\AppData\Local\Android\sdk"
$env:ANDROID_SDK_ROOT = "C:\Users\thoma\AppData\Local\Android\sdk"
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"

# Chemins
$projectRoot = Split-Path -Parent $PSScriptRoot
$appiumTestsDir = $PSScriptRoot
$vocabularyAppDir = Join-Path $projectRoot "vocabulary_app"
$apkPath = Join-Path $vocabularyAppDir "build\app\outputs\flutter-apk\app-debug.apk"

# -----------------------------------------------------------------------------
# ETAPE 1: Verifier l'emulateur
# -----------------------------------------------------------------------------
Write-Host "[1/5] Verification de l'emulateur Android..." -ForegroundColor Yellow

$devices = adb devices 2>&1
if ($devices -notmatch "emulator|device") {
    Write-Host "[ERREUR] Aucun emulateur detecte!" -ForegroundColor Red
    Write-Host "Lance un emulateur depuis Android Studio et reessaie." -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Emulateur connecte" -ForegroundColor Green
Write-Host ""

# -----------------------------------------------------------------------------
# ETAPE 2: Construire l'APK si necessaire
# -----------------------------------------------------------------------------
Write-Host "[2/5] Verification de l'APK..." -ForegroundColor Yellow

$buildApk = $false

if (-not (Test-Path $apkPath)) {
    Write-Host "APK non trouve. Construction necessaire..." -ForegroundColor Yellow
    $buildApk = $true
} else {
    $apkAge = (Get-Date) - (Get-Item $apkPath).LastWriteTime
    if ($apkAge.TotalHours -gt 24) {
        Write-Host "APK date de plus de 24h. Reconstruction recommandee..." -ForegroundColor Yellow
        $response = Read-Host "Reconstruire l'APK? (O/n)"
        if ($response -ne "n" -and $response -ne "N") {
            $buildApk = $true
        }
    } else {
        Write-Host "[OK] APK trouve (date de $([math]::Round($apkAge.TotalMinutes)) minutes)" -ForegroundColor Green
    }
}

if ($buildApk) {
    Write-Host "Construction de l'APK..." -ForegroundColor Yellow
    Push-Location $vocabularyAppDir

    Write-Host "  -> flutter clean" -ForegroundColor Gray
    flutter clean | Out-Null

    Write-Host "  -> flutter pub get" -ForegroundColor Gray
    flutter pub get | Out-Null

    Write-Host "  -> flutter build apk --debug --target lib/main_appium.dart" -ForegroundColor Gray
    flutter build apk --debug --target lib/main_appium.dart

    Pop-Location

    if (-not (Test-Path $apkPath)) {
        Write-Host "[ERREUR] La construction de l'APK a echoue!" -ForegroundColor Red
        exit 1
    }
    Write-Host "[OK] APK construit avec succes" -ForegroundColor Green
}
Write-Host ""

# -----------------------------------------------------------------------------
# ETAPE 3: Verifier/Installer les dependances npm
# -----------------------------------------------------------------------------
Write-Host "[3/5] Verification des dependances npm..." -ForegroundColor Yellow

Push-Location $appiumTestsDir

if (-not (Test-Path "node_modules")) {
    Write-Host "Installation des dependances npm..." -ForegroundColor Yellow
    npm install
}
Write-Host "[OK] Dependances npm installees" -ForegroundColor Green
Write-Host ""

# -----------------------------------------------------------------------------
# ETAPE 4: Demarrer Appium en arriere-plan
# -----------------------------------------------------------------------------
Write-Host "[4/5] Demarrage d'Appium..." -ForegroundColor Yellow

# Verifier si Appium est deja en cours
$appiumRunning = $false
try {
    # Utiliser Test-NetConnection comme methode alternative
    $tcpTest = Test-NetConnection -ComputerName localhost -Port 4723 -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
    if ($tcpTest.TcpTestSucceeded) {
        $appiumRunning = $true
        Write-Host "[OK] Appium est deja en cours d'execution (port 4723 ouvert)" -ForegroundColor Green
    }
} catch {
    # Appium n'est pas en cours
}

if (-not $appiumRunning) {
    Write-Host "Demarrage d'Appium dans une nouvelle fenetre..." -ForegroundColor Yellow

    # Demarrer Appium dans une nouvelle fenetre CMD avec les variables d'environnement
    $appiumCmd = "set ANDROID_HOME=$env:ANDROID_HOME && set ANDROID_SDK_ROOT=$env:ANDROID_SDK_ROOT && set JAVA_HOME=$env:JAVA_HOME && appium"
    Start-Process -FilePath "cmd.exe" -ArgumentList "/k", $appiumCmd -WindowStyle Normal

    # Attendre qu'Appium soit pret (Flutter driver peut prendre 30+ secondes a charger)
    $maxWait = 60
    $waited = 0
    Write-Host "  Attente du demarrage d'Appium..." -ForegroundColor Gray
    while ($waited -lt $maxWait) {
        Start-Sleep -Seconds 1
        $waited++
        try {
            $tcpTest = Test-NetConnection -ComputerName localhost -Port 4723 -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
            if ($tcpTest.TcpTestSucceeded) {
                Write-Host "[OK] Appium demarre (apres $waited secondes)" -ForegroundColor Green
                break
            }
        } catch {
            # Ignorer l'erreur
        }
        if ($waited % 5 -eq 0) {
            Write-Host "  Attente d'Appium... ($waited/$maxWait)" -ForegroundColor Gray
        }
    }

    if ($waited -ge $maxWait) {
        Write-Host "[ERREUR] Appium n'a pas demarre dans les temps!" -ForegroundColor Red
        Write-Host "" -ForegroundColor Red
        Write-Host "Essaie de lancer Appium manuellement dans une autre fenetre:" -ForegroundColor Yellow
        Write-Host "  appium" -ForegroundColor White
        Write-Host "" -ForegroundColor Yellow
        Write-Host "Puis relance ce script." -ForegroundColor Yellow
        exit 1
    }
}
Write-Host ""

# -----------------------------------------------------------------------------
# ETAPE 5: Lancer les tests
# -----------------------------------------------------------------------------
Write-Host "[5/5] Lancement des tests..." -ForegroundColor Yellow
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""

# Lancer le test smoke
npm run test:smoke

$testExitCode = $LASTEXITCODE

Write-Host ""
Write-Host "=============================================" -ForegroundColor Cyan

if ($testExitCode -eq 0) {
    Write-Host "   TESTS REUSSIS!" -ForegroundColor Green
} else {
    Write-Host "   TESTS ECHOUES (code: $testExitCode)" -ForegroundColor Red

    # Afficher les screenshots si presents
    $screenshots = Get-ChildItem -Path ".\screenshots\*.png" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($screenshots) {
        Write-Host ""
        Write-Host "Screenshot de debug disponible:" -ForegroundColor Yellow
        Write-Host "  $($screenshots.FullName)" -ForegroundColor White

        # Ouvrir le screenshot automatiquement
        Start-Process $screenshots.FullName
    }
}

Write-Host "=============================================" -ForegroundColor Cyan

# Note: Appium reste ouvert dans sa propre fenetre
# Tu peux le fermer manuellement quand tu as fini les tests

Pop-Location

exit $testExitCode
