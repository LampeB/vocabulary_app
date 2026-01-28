# =============================================================================
# Script complet pour lancer les tests Appium
# Usage: .\run-all.ps1 [-Emulator <name>] [-SkipBuild] [-SmokeOnly]
#
# Exemples:
#   .\run-all.ps1                           # Tout lancer (emulateur, build, appium, tests)
#   .\run-all.ps1 -SkipBuild                # Skip le build Flutter
#   .\run-all.ps1 -SmokeOnly                # Lancer uniquement le smoke test
#   .\run-all.ps1 -Emulator "Pixel_5"       # Utiliser un emulateur specifique
# =============================================================================

param(
    [string]$Emulator = "",
    [switch]$SkipBuild,
    [switch]$SmokeOnly
)

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "   LANCEMENT DES TESTS APPIUM" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""

# Configuration des variables d'environnement
$env:ANDROID_HOME = "C:\Users\thoma\AppData\Local\Android\sdk"
$env:ANDROID_SDK_ROOT = "C:\Users\thoma\AppData\Local\Android\sdk"
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"

$emulatorExe = Join-Path $env:ANDROID_HOME "emulator\emulator.exe"
$adb = Join-Path $env:ANDROID_HOME "platform-tools\adb.exe"

# Chemins
# Le script est dans vocabulary_app/appium-tests/, donc le parent direct est vocabulary_app/
$appiumTestsDir = $PSScriptRoot
$vocabularyAppDir = Split-Path -Parent $PSScriptRoot
$apkPath = Join-Path $vocabularyAppDir "build\app\outputs\flutter-apk\app-debug.apk"

# -----------------------------------------------------------------------------
# ETAPE 1: Lancer l'emulateur si necessaire
# -----------------------------------------------------------------------------
Write-Host "[1/5] Verification de l'emulateur Android..." -ForegroundColor Yellow

$emulatorStarted = $false

# Verifier si un emulateur tourne deja
$devices = & $adb devices 2>&1 | Out-String
if ($devices -match "emulator-\d+\s+device") {
    Write-Host "[OK] Emulateur deja en cours d'execution" -ForegroundColor Green
} else {
    Write-Host "Aucun emulateur detecte. Lancement automatique..." -ForegroundColor Yellow

    # Determiner quel emulateur utiliser
    if ($Emulator -eq "") {
        # Lister les AVDs disponibles et prendre le premier
        $avds = & $emulatorExe -list-avds 2>&1
        if (-not $avds -or $avds.Count -eq 0) {
            Write-Host "[ERREUR] Aucun AVD trouve! Cree un emulateur dans Android Studio." -ForegroundColor Red
            exit 1
        }
        # Prendre le premier AVD disponible
        $Emulator = ($avds | Select-Object -First 1).Trim()
    }

    Write-Host "  -> Lancement de l'emulateur: $Emulator" -ForegroundColor Gray
    Start-Process -FilePath $emulatorExe -ArgumentList "-avd", $Emulator, "-no-snapshot-load" -WindowStyle Normal
    $emulatorStarted = $true

    # Attendre que l'emulateur soit pret (boot complet)
    Write-Host "  -> Attente du demarrage de l'emulateur..." -ForegroundColor Gray
    $maxWait = 120
    $waited = 0
    while ($waited -lt $maxWait) {
        Start-Sleep -Seconds 2
        $waited += 2

        $bootCompleted = & $adb shell getprop sys.boot_completed 2>&1 | Out-String
        if ($bootCompleted.Trim() -eq "1") {
            Write-Host "[OK] Emulateur demarre (apres $waited secondes)" -ForegroundColor Green
            # Attendre encore un peu pour que l'UI soit stable
            Start-Sleep -Seconds 5
            break
        }

        if ($waited % 10 -eq 0) {
            Write-Host "  Attente de l'emulateur... ($waited/$maxWait)" -ForegroundColor Gray
        }
    }

    if ($waited -ge $maxWait) {
        Write-Host "[ERREUR] L'emulateur n'a pas demarre dans les temps!" -ForegroundColor Red
        exit 1
    }
}
Write-Host ""

# -----------------------------------------------------------------------------
# ETAPE 2: Construire l'APK si necessaire
# -----------------------------------------------------------------------------
Write-Host "[2/5] Verification de l'APK..." -ForegroundColor Yellow

if ($SkipBuild) {
    if (Test-Path $apkPath) {
        Write-Host "[OK] Build skip (-SkipBuild). APK existant utilise." -ForegroundColor Green
    } else {
        Write-Host "[ERREUR] -SkipBuild mais aucun APK trouve! Relance sans -SkipBuild." -ForegroundColor Red
        exit 1
    }
} else {
    $buildApk = $false

    if (-not (Test-Path $apkPath)) {
        Write-Host "APK non trouve. Construction necessaire..." -ForegroundColor Yellow
        $buildApk = $true
    } else {
        $apkAge = (Get-Date) - (Get-Item $apkPath).LastWriteTime
        if ($apkAge.TotalHours -gt 24) {
            Write-Host "APK date de plus de 24h. Reconstruction..." -ForegroundColor Yellow
            $buildApk = $true
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
    # Les guillemets autour de chaque "set" evitent que CMD inclue l'espace avant && dans la valeur
    $appiumCmd = "set `"ANDROID_HOME=$env:ANDROID_HOME`" && set `"ANDROID_SDK_ROOT=$env:ANDROID_SDK_ROOT`" && set `"JAVA_HOME=$env:JAVA_HOME`" && appium"
    Start-Process -FilePath "cmd.exe" -ArgumentList "/k", $appiumCmd -WindowStyle Normal

    # Attendre qu'Appium soit pret
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

if ($SmokeOnly) {
    Write-Host "Mode: Smoke test uniquement" -ForegroundColor Gray
    npm run test:smoke
} else {
    Write-Host "Mode: Tous les tests" -ForegroundColor Gray
    npm test
}

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

# Ouvrir le rapport HTML
$reportPath = Join-Path $appiumTestsDir "reports\cucumber-report.html"
if (Test-Path $reportPath) {
    Write-Host ""
    Write-Host "Rapport: $reportPath" -ForegroundColor Gray
}

Pop-Location

exit $testExitCode
