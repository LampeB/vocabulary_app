# Smoke Test - Quick verification of all installations
# Tests that all required tools are installed and working

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "SMOKE TEST - VocabularyApp Setup" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$testResults = @()
$allPassed = $true

# Test 1: Flutter
Write-Host "Testing Flutter..." -ForegroundColor Yellow
try {
    $flutterVersion = flutter --version 2>&1 | Select-String "Flutter" | Select-Object -First 1
    if ($flutterVersion) {
        Write-Host "[PASS] Flutter is working: $flutterVersion" -ForegroundColor Green
        $testResults += "Flutter: PASS"
    } else {
        throw "Flutter version not found"
    }
} catch {
    Write-Host "[FAIL] Flutter is not working" -ForegroundColor Red
    $testResults += "Flutter: FAIL"
    $allPassed = $false
}

# Test 2: Dart
Write-Host "`nTesting Dart..." -ForegroundColor Yellow
try {
    $dartVersion = dart --version 2>&1
    if ($dartVersion) {
        Write-Host "[PASS] Dart is working: $dartVersion" -ForegroundColor Green
        $testResults += "Dart: PASS"
    } else {
        throw "Dart version not found"
    }
} catch {
    Write-Host "[FAIL] Dart is not working" -ForegroundColor Red
    $testResults += "Dart: FAIL"
    $allPassed = $false
}

# Test 3: Java
Write-Host "`nTesting Java JDK..." -ForegroundColor Yellow
try {
    $javaVersion = java -version 2>&1 | Select-String "version" | Select-Object -First 1
    if ($javaVersion) {
        Write-Host "[PASS] Java is working: $javaVersion" -ForegroundColor Green
        $testResults += "Java: PASS"
    } else {
        throw "Java version not found"
    }
} catch {
    Write-Host "[FAIL] Java is not working" -ForegroundColor Red
    $testResults += "Java: FAIL"
    $allPassed = $false
}

# Test 4: Node.js
Write-Host "`nTesting Node.js..." -ForegroundColor Yellow
try {
    $nodeVersion = node --version
    if ($nodeVersion) {
        Write-Host "[PASS] Node.js is working: $nodeVersion" -ForegroundColor Green
        $testResults += "Node.js: PASS"
    } else {
        throw "Node version not found"
    }
} catch {
    Write-Host "[FAIL] Node.js is not working" -ForegroundColor Red
    $testResults += "Node.js: FAIL"
    $allPassed = $false
}

# Test 5: npm
Write-Host "`nTesting npm..." -ForegroundColor Yellow
try {
    $npmVersion = npm --version
    if ($npmVersion) {
        Write-Host "[PASS] npm is working: v$npmVersion" -ForegroundColor Green
        $testResults += "npm: PASS"
    } else {
        throw "npm version not found"
    }
} catch {
    Write-Host "[FAIL] npm is not working" -ForegroundColor Red
    $testResults += "npm: FAIL"
    $allPassed = $false
}

# Test 6: Appium
Write-Host "`nTesting Appium..." -ForegroundColor Yellow
try {
    $appiumVersion = appium --version 2>&1
    if ($appiumVersion) {
        Write-Host "[PASS] Appium is working: v$appiumVersion" -ForegroundColor Green
        $testResults += "Appium: PASS"
    } else {
        throw "Appium version not found"
    }
} catch {
    Write-Host "[FAIL] Appium is not working" -ForegroundColor Red
    $testResults += "Appium: FAIL"
    $allPassed = $false
}

# Test 7: Flutter Doctor
Write-Host "`nRunning Flutter Doctor (quick check)..." -ForegroundColor Yellow
try {
    $doctorOutput = flutter doctor 2>&1
    Write-Host "[INFO] Flutter Doctor output:" -ForegroundColor Cyan
    Write-Host $doctorOutput -ForegroundColor Gray
    $testResults += "Flutter Doctor: COMPLETED"
} catch {
    Write-Host "[WARN] Flutter Doctor failed to run" -ForegroundColor Yellow
    $testResults += "Flutter Doctor: FAILED"
}

# Test 8: Project Dependencies
Write-Host "`nChecking project dependencies..." -ForegroundColor Yellow
if (Test-Path ".dart_tool") {
    Write-Host "[PASS] Flutter packages are installed" -ForegroundColor Green
    $testResults += "Flutter packages: PASS"
} else {
    Write-Host "[FAIL] Flutter packages are NOT installed" -ForegroundColor Red
    $testResults += "Flutter packages: FAIL"
    $allPassed = $false
}

if (Test-Path "appium-tests/node_modules") {
    Write-Host "[PASS] Appium test dependencies are installed" -ForegroundColor Green
    $testResults += "Appium tests: PASS"
} else {
    Write-Host "[FAIL] Appium test dependencies are NOT installed" -ForegroundColor Red
    $testResults += "Appium tests: FAIL"
    $allPassed = $false
}

# Test 9: Android Studio
Write-Host "`nChecking Android Studio installation..." -ForegroundColor Yellow
$asPaths = @(
    "${env:ProgramFiles}\Android\Android Studio",
    "${env:LOCALAPPDATA}\Programs\Android Studio"
)
$asFound = $false
foreach ($path in $asPaths) {
    if (Test-Path "$path\bin\studio64.exe") {
        Write-Host "[PASS] Android Studio found at: $path" -ForegroundColor Green
        $testResults += "Android Studio: PASS"
        $asFound = $true
        break
    }
}
if (!$asFound) {
    Write-Host "[FAIL] Android Studio executable not found" -ForegroundColor Red
    $testResults += "Android Studio: FAIL"
    $allPassed = $false
}

# Summary
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "SMOKE TEST RESULTS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
foreach ($result in $testResults) {
    if ($result -like "*PASS*") {
        Write-Host $result -ForegroundColor Green
    } elseif ($result -like "*FAIL*") {
        Write-Host $result -ForegroundColor Red
    } else {
        Write-Host $result -ForegroundColor Yellow
    }
}
Write-Host "========================================`n" -ForegroundColor Cyan

if ($allPassed) {
    Write-Host "ALL CRITICAL TESTS PASSED!" -ForegroundColor Green
    Write-Host "Your development environment is ready!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "SOME TESTS FAILED!" -ForegroundColor Red
    Write-Host "Please check the failed items above." -ForegroundColor Yellow
    exit 1
}
