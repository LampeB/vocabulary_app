# =============================================================================
# Script complet pour lancer les tests Appium avec reporting Allure
# Usage: .\run-all.ps1 [-Emulator <name>] [-SkipBuild] [-SmokeOnly] [-NoReport]
#
# Exemples:
#   .\run-all.ps1                           # Tout lancer (emulateur, build, appium, tests)
#   .\run-all.ps1 -SkipBuild                # Skip le build Flutter
#   .\run-all.ps1 -SmokeOnly                # Lancer uniquement le smoke test
#   .\run-all.ps1 -Emulator "Pixel_5"       # Utiliser un emulateur specifique
#   .\run-all.ps1 -NoReport                 # Ne pas ouvrir le rapport automatiquement
# =============================================================================

param(
    [string]$Emulator = "",
    [switch]$SkipBuild,
    [switch]$SmokeOnly,
    [switch]$NoReport
)

# =============================================================================
# CONFIGURATION DES LOGS
# =============================================================================
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$logsDir = Join-Path $PSScriptRoot "logs"
$mainLogFile = Join-Path $logsDir "test-run-$timestamp.log"
$appiumLogFile = Join-Path $logsDir "appium-$timestamp.log"

# Creer le dossier logs s'il n'existe pas
if (-not (Test-Path $logsDir)) {
    New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
}

# Fonction pour logger avec timestamp
function Write-Log {
    param(
        [string]$Message,
        [string]$Color = "White",
        [switch]$NoNewline
    )
    $logTimestamp = Get-Date -Format "HH:mm:ss"
    $logMessage = "[$logTimestamp] $Message"

    # Afficher dans la console
    if ($NoNewline) {
        Write-Host $Message -ForegroundColor $Color -NoNewline
    } else {
        Write-Host $Message -ForegroundColor $Color
    }

    # Ecrire dans le fichier log
    Add-Content -Path $mainLogFile -Value $logMessage
}

Write-Log "=============================================" "Cyan"
Write-Log "   LANCEMENT DES TESTS APPIUM" "Cyan"
Write-Log "=============================================" "Cyan"
Write-Log "Log file: $mainLogFile" "Gray"
Write-Log ""

# Configuration des variables d'environnement
$env:ANDROID_HOME = "C:\Users\thoma\AppData\Local\Android\sdk"
$env:ANDROID_SDK_ROOT = "C:\Users\thoma\AppData\Local\Android\sdk"
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"

$emulatorExe = Join-Path $env:ANDROID_HOME "emulator\emulator.exe"
$adb = Join-Path $env:ANDROID_HOME "platform-tools\adb.exe"

# Chemins
$appiumTestsDir = $PSScriptRoot
$vocabularyAppDir = Split-Path -Parent $PSScriptRoot
$apkPath = Join-Path $vocabularyAppDir "build\app\outputs\flutter-apk\app-debug.apk"
$allureResultsDir = Join-Path $appiumTestsDir "allure-results"
$allureReportDir = Join-Path $appiumTestsDir "allure-report"

# Nettoyer les anciens resultats Allure
if (Test-Path $allureResultsDir) {
    Remove-Item -Path $allureResultsDir -Recurse -Force
    Write-Log "Anciens resultats Allure nettoyes" "Gray"
}

# -----------------------------------------------------------------------------
# ETAPE 1: Lancer l'emulateur si necessaire
# -----------------------------------------------------------------------------
Write-Log "[1/5] Verification de l'emulateur Android..." "Yellow"

$emulatorStarted = $false

# Verifier si un emulateur tourne deja
$devices = & $adb devices 2>&1 | Out-String
if ($devices -match "emulator-\d+\s+device") {
    Write-Log "[OK] Emulateur deja en cours d'execution" "Green"
} else {
    Write-Log "Aucun emulateur detecte. Lancement automatique..." "Yellow"

    # Determiner quel emulateur utiliser
    if ($Emulator -eq "") {
        $avds = & $emulatorExe -list-avds 2>&1
        if (-not $avds -or $avds.Count -eq 0) {
            Write-Log "[ERREUR] Aucun AVD trouve! Cree un emulateur dans Android Studio." "Red"
            exit 1
        }
        $Emulator = ($avds | Select-Object -First 1).Trim()
    }

    Write-Log "  -> Lancement de l'emulateur: $Emulator" "Gray"
    Start-Process -FilePath $emulatorExe -ArgumentList "-avd", $Emulator, "-no-snapshot" -WindowStyle Minimized
    $emulatorStarted = $true

    # Attendre que l'emulateur soit pret
    Write-Log "  -> Attente du demarrage de l'emulateur..." "Gray"
    $maxWait = 120
    $waited = 0
    while ($waited -lt $maxWait) {
        Start-Sleep -Seconds 2
        $waited += 2

        $bootCompleted = & $adb shell getprop sys.boot_completed 2>&1 | Out-String
        if ($bootCompleted.Trim() -eq "1") {
            Write-Log "[OK] Emulateur demarre (apres $waited secondes)" "Green"
            Start-Sleep -Seconds 5
            break
        }

        if ($waited % 10 -eq 0) {
            Write-Log "  Attente de l'emulateur... ($waited/$maxWait)" "Gray"
        }
    }

    if ($waited -ge $maxWait) {
        Write-Log "[ERREUR] L'emulateur n'a pas demarre dans les temps!" "Red"
        exit 1
    }
}

# Verification de la sante de l'emulateur
Write-Log "  Verification de la sante de l'emulateur..." "Gray"
$settingsCheck = & $adb shell settings list system 2>&1 | Out-String
if ($settingsCheck -match "volume") {
    Write-Log "[OK] Emulateur sain (settings service OK)" "Green"
} else {
    Write-Log "[WARN] Settings service instable. Redemarrage cold-boot recommande." "Yellow"
}

Write-Log ""

# -----------------------------------------------------------------------------
# ETAPE 2: Construire l'APK si necessaire
# -----------------------------------------------------------------------------
Write-Log "[2/5] Verification de l'APK..." "Yellow"

if ($SkipBuild) {
    if (Test-Path $apkPath) {
        Write-Log "[OK] Build skip (-SkipBuild). APK existant utilise." "Green"
    } else {
        Write-Log "[ERREUR] -SkipBuild mais aucun APK trouve! Relance sans -SkipBuild." "Red"
        exit 1
    }
} else {
    $buildApk = $false

    if (-not (Test-Path $apkPath)) {
        Write-Log "APK non trouve. Construction necessaire..." "Yellow"
        $buildApk = $true
    } else {
        $apkAge = (Get-Date) - (Get-Item $apkPath).LastWriteTime
        if ($apkAge.TotalHours -gt 24) {
            Write-Log "APK date de plus de 24h. Reconstruction..." "Yellow"
            $buildApk = $true
        } else {
            Write-Log "[OK] APK trouve (date de $([math]::Round($apkAge.TotalMinutes)) minutes)" "Green"
        }
    }

    if ($buildApk) {
        Write-Log "Construction de l'APK..." "Yellow"
        Push-Location $vocabularyAppDir

        Write-Log "  -> flutter clean" "Gray"
        flutter clean 2>&1 | Tee-Object -Append -FilePath $mainLogFile | Out-Null

        Write-Log "  -> flutter pub get" "Gray"
        flutter pub get 2>&1 | Tee-Object -Append -FilePath $mainLogFile | Out-Null

        Write-Log "  -> flutter build apk --debug --target lib/main_appium.dart" "Gray"
        flutter build apk --debug --target lib/main_appium.dart 2>&1 | Tee-Object -Append -FilePath $mainLogFile

        Pop-Location

        if (-not (Test-Path $apkPath)) {
            Write-Log "[ERREUR] La construction de l'APK a echoue!" "Red"
            exit 1
        }
        Write-Log "[OK] APK construit avec succes" "Green"
    }
}
Write-Log ""

# -----------------------------------------------------------------------------
# ETAPE 3: Verifier/Installer les dependances npm
# -----------------------------------------------------------------------------
Write-Log "[3/5] Verification des dependances npm..." "Yellow"

Push-Location $appiumTestsDir

if (-not (Test-Path "node_modules")) {
    Write-Log "Installation des dependances npm..." "Yellow"
    npm install 2>&1 | Tee-Object -Append -FilePath $mainLogFile
}
Write-Log "[OK] Dependances npm installees" "Green"
Write-Log ""

# -----------------------------------------------------------------------------
# ETAPE 4: Demarrer Appium en arriere-plan
# -----------------------------------------------------------------------------
Write-Log "[4/5] Demarrage d'Appium..." "Yellow"

$appiumRunning = $false
try {
    $tcpTest = Test-NetConnection -ComputerName localhost -Port 4723 -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
    if ($tcpTest.TcpTestSucceeded) {
        $appiumRunning = $true
        Write-Log "[OK] Appium est deja en cours d'execution (port 4723 ouvert)" "Green"
    }
} catch {
    # Appium n'est pas en cours
}

if (-not $appiumRunning) {
    Write-Log "Demarrage d'Appium en arriere-plan..." "Yellow"

    # Demarrer Appium en arriere-plan avec logs dans un fichier
    $appiumCmd = "set `"ANDROID_HOME=$env:ANDROID_HOME`" && set `"ANDROID_SDK_ROOT=$env:ANDROID_SDK_ROOT`" && set `"JAVA_HOME=$env:JAVA_HOME`" && appium > `"$appiumLogFile`" 2>&1"
    Start-Process -FilePath "cmd.exe" -ArgumentList "/c", $appiumCmd -WindowStyle Hidden

    # Attendre qu'Appium soit pret
    $maxWait = 60
    $waited = 0
    Write-Log "  Attente du demarrage d'Appium..." "Gray"
    while ($waited -lt $maxWait) {
        Start-Sleep -Seconds 1
        $waited++
        try {
            $tcpTest = Test-NetConnection -ComputerName localhost -Port 4723 -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
            if ($tcpTest.TcpTestSucceeded) {
                Write-Log "[OK] Appium demarre (apres $waited secondes)" "Green"
                Write-Log "  Appium log: $appiumLogFile" "Gray"
                break
            }
        } catch {
            # Ignorer l'erreur
        }
        if ($waited % 5 -eq 0) {
            Write-Log "  Attente d'Appium... ($waited/$maxWait)" "Gray"
        }
    }

    if ($waited -ge $maxWait) {
        Write-Log "[ERREUR] Appium n'a pas demarre dans les temps!" "Red"
        Write-Log "" "Red"
        Write-Log "Essaie de lancer Appium manuellement dans une autre fenetre:" "Yellow"
        Write-Log "  appium" "White"
        Write-Log "" "Yellow"
        Write-Log "Puis relance ce script." "Yellow"
        exit 1
    }
}
Write-Log ""

# -----------------------------------------------------------------------------
# ETAPE 5: Lancer les tests
# -----------------------------------------------------------------------------
Write-Log "[5/5] Lancement des tests..." "Yellow"
Write-Log "=============================================" "Cyan"
Write-Log ""

$testStartTime = Get-Date

if ($SmokeOnly) {
    Write-Log "Mode: Smoke test uniquement" "Gray"
    npm run test:smoke 2>&1 | Tee-Object -Append -FilePath $mainLogFile
} else {
    Write-Log "Mode: Tous les tests" "Gray"
    npm test 2>&1 | Tee-Object -Append -FilePath $mainLogFile
}

$testExitCode = $LASTEXITCODE
$testEndTime = Get-Date
$testDuration = $testEndTime - $testStartTime

Write-Log ""
Write-Log "=============================================" "Cyan"

# =============================================================================
# RESUME DES TESTS
# =============================================================================
Write-Log ""
Write-Log "=============================================" "Magenta"
Write-Log "   RESUME DE L'EXECUTION" "Magenta"
Write-Log "=============================================" "Magenta"
Write-Log ""
Write-Log "  Duree totale: $($testDuration.Minutes)m $($testDuration.Seconds)s" "White"
Write-Log "  Logs:         $mainLogFile" "White"
Write-Log ""

if ($testExitCode -eq 0) {
    Write-Log "  Resultat: TESTS REUSSIS!" "Green"
} else {
    Write-Log "  Resultat: TESTS ECHOUES (code: $testExitCode)" "Red"

    # Afficher les screenshots si presents
    $screenshots = Get-ChildItem -Path ".\screenshots\*.png" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($screenshots) {
        Write-Log ""
        Write-Log "  Screenshot de debug disponible:" "Yellow"
        Write-Log "    $($screenshots.FullName)" "White"
    }
}

Write-Log ""
Write-Log "=============================================" "Magenta"

# =============================================================================
# GENERATION DU RAPPORT ALLURE
# =============================================================================
Write-Log ""
Write-Log "[6/6] Generation du rapport Allure..." "Yellow"

# Verifier si Allure est installe
$allureInstalled = $false
try {
    $allureVersion = & allure --version 2>&1
    if ($LASTEXITCODE -eq 0) {
        $allureInstalled = $true
        Write-Log "  Allure version: $allureVersion" "Gray"
    }
} catch {
    # Allure n'est pas installe
}

if (-not $allureInstalled) {
    Write-Log "  Allure CLI non trouve. Installation via npm..." "Yellow"
    npm install -g allure-commandline 2>&1 | Tee-Object -Append -FilePath $mainLogFile

    # Re-verifier
    try {
        $allureVersion = & allure --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            $allureInstalled = $true
        }
    } catch {
        # Toujours pas installe
    }
}

if ($allureInstalled -and (Test-Path $allureResultsDir)) {
    Write-Log "  Generation du rapport..." "Gray"
    & allure generate $allureResultsDir -o $allureReportDir --clean 2>&1 | Tee-Object -Append -FilePath $mainLogFile

    if (Test-Path (Join-Path $allureReportDir "index.html")) {
        Write-Log "[OK] Rapport Allure genere" "Green"

        if (-not $NoReport) {
            Write-Log ""
            Write-Log "  Ouverture du rapport dans le navigateur..." "Gray"
            $reportHtml = Join-Path $allureReportDir "index.html"
            Start-Process $reportHtml
        }
    } else {
        Write-Log "[WARN] Generation du rapport Allure echouee" "Yellow"
    }
} else {
    if (-not $allureInstalled) {
        Write-Log "[WARN] Allure CLI non disponible. Installez-le avec:" "Yellow"
        Write-Log "  npm install -g allure-commandline" "White"
        Write-Log "  ou: choco install allure" "White"
    }
    if (-not (Test-Path $allureResultsDir)) {
        Write-Log "[WARN] Aucun resultat Allure trouve dans $allureResultsDir" "Yellow"
    }
}

# Afficher les chemins des rapports
Write-Log ""
Write-Log "=============================================" "Cyan"
Write-Log "   RAPPORTS DISPONIBLES" "Cyan"
Write-Log "=============================================" "Cyan"

$cucumberReportPath = Join-Path $appiumTestsDir "reports\cucumber-report.html"
$allureReportPath = Join-Path $allureReportDir "index.html"

if (Test-Path $cucumberReportPath) {
    Write-Log "  Cucumber: $cucumberReportPath" "White"
}
if (Test-Path $allureReportPath) {
    Write-Log "  Allure:   $allureReportPath" "White"
}
Write-Log "  Logs:     $mainLogFile" "White"
Write-Log ""
Write-Log "=============================================" "Cyan"

Pop-Location

exit $testExitCode
