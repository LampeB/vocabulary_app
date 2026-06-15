param(
    [string]$EnvFile = "test.free.env.json",
    [string[]]$Tests = @(
        "patrol_test/auth_test.dart",
        "patrol_test/vocab_list_test.dart",
        "patrol_test/quiz_session_test.dart"
    ),
    [string]$Device = "emulator-5554"
)

$patrol = "$env:USERPROFILE\AppData\Local\Pub\Cache\bin\patrol.bat"

# Stop Gradle daemon so it releases file handles on UTP logs from previous run.
Write-Host "Stopping Gradle daemon..."
& "E:\Projects\vocab_kr\android\gradlew.bat" --stop 2>&1 | Out-Null

# Remove stale test results that Gradle can't delete on Windows due to UTP file locks.
$resultsDir = "E:\Projects\vocab_kr\build\app\outputs\androidTest-results\connected\debug"
if (Test-Path $resultsDir) {
    Remove-Item -Recurse -Force $resultsDir -ErrorAction SilentlyContinue
    Write-Host "Cleared stale test results."
}

# Build -t flags from the Tests array.
$tFlags = $Tests | ForEach-Object { "-t", $_ }

Set-Location E:\Projects\vocab_kr
Write-Host "Running tests: $Tests"
& $patrol test @tFlags --dart-define-from-file=$EnvFile -d $Device
