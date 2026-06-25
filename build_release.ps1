# Build a sideloadable release APK and optionally install it on the connected device.
# Usage:
#   .\build_release.ps1          # build only
#   .\build_release.ps1 -Install # build + adb install

param([switch]$Install)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$EnvFile = ".env.json"
$ApkOut  = "build\app\outputs\flutter-apk\app-release.apk"

# Guard: .env.json must exist and contain the three required keys
if (-not (Test-Path $EnvFile)) {
    Write-Error "Missing $EnvFile — Supabase and RevenueCat keys will be empty and the app will hang on startup."
}
$env = Get-Content $EnvFile | ConvertFrom-Json
foreach ($key in @('SUPABASE_URL','SUPABASE_ANON_KEY','REVENUECAT_API_KEY')) {
    if (-not $env.$key) {
        Write-Error "$EnvFile is missing or has an empty '$key' — the app will hang or crash at startup."
    }
}

Write-Host "Building release APK..."
flutter build apk --release --dart-define-from-file=$EnvFile
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$size = [math]::Round((Get-Item $ApkOut).Length / 1MB, 1)
Write-Host "Built: $ApkOut ($size MB)"

if ($Install) {
    $devices = (adb devices) -match "^\S+\s+device$"
    if (-not $devices) {
        Write-Error "No ADB device found. Connect the phone and enable USB debugging, then re-run with -Install."
    }
    Write-Host "Installing on device..."
    adb install -r $ApkOut
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    Write-Host "Installed successfully."
}
