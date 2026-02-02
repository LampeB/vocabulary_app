# Fix PATH - Add Flutter and Java to system PATH
# Run this as Administrator

#Requires -RunAsAdministrator

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "PATH Fix Script" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Paths to add
$FLUTTER_PATH = "C:\Development\flutter\bin"
$JAVA_BASE = "C:\Program Files\Eclipse Adoptium"

# Get current system PATH
$currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
$pathsToAdd = @()

# Check Flutter
Write-Host "Checking Flutter..." -ForegroundColor Yellow
if (Test-Path $FLUTTER_PATH) {
    if ($currentPath -notlike "*$FLUTTER_PATH*") {
        Write-Host "[ACTION] Will add Flutter to PATH: $FLUTTER_PATH" -ForegroundColor Yellow
        $pathsToAdd += $FLUTTER_PATH
    } else {
        Write-Host "[OK] Flutter already in PATH" -ForegroundColor Green
    }
} else {
    Write-Host "[ERROR] Flutter directory not found at: $FLUTTER_PATH" -ForegroundColor Red
}

# Check Java
Write-Host "`nChecking Java..." -ForegroundColor Yellow
if (Test-Path $JAVA_BASE) {
    # Find the JDK directory
    $jdkDirs = Get-ChildItem -Path $JAVA_BASE -Directory | Where-Object { $_.Name -like "jdk-*" }
    if ($jdkDirs) {
        $jdkPath = $jdkDirs[0].FullName
        $javaBinPath = "$jdkPath\bin"

        if (Test-Path $javaBinPath) {
            if ($currentPath -notlike "*$javaBinPath*") {
                Write-Host "[ACTION] Will add Java to PATH: $javaBinPath" -ForegroundColor Yellow
                $pathsToAdd += $javaBinPath
            } else {
                Write-Host "[OK] Java already in PATH" -ForegroundColor Green
            }
        } else {
            Write-Host "[ERROR] Java bin directory not found at: $javaBinPath" -ForegroundColor Red
        }
    } else {
        Write-Host "[ERROR] No JDK directory found in: $JAVA_BASE" -ForegroundColor Red
    }
} else {
    Write-Host "[ERROR] Eclipse Adoptium directory not found at: $JAVA_BASE" -ForegroundColor Red
}

# Apply changes if needed
if ($pathsToAdd.Count -gt 0) {
    Write-Host "`n========================================" -ForegroundColor Yellow
    Write-Host "PATHS TO ADD:" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Yellow
    foreach ($path in $pathsToAdd) {
        Write-Host "  + $path" -ForegroundColor White
    }
    Write-Host ""

    $confirm = Read-Host "Add these paths to system PATH? (Y/N)"
    if ($confirm -eq "Y" -or $confirm -eq "y") {
        try {
            $newPath = $currentPath
            foreach ($path in $pathsToAdd) {
                $newPath += ";$path"
            }

            [Environment]::SetEnvironmentVariable("Path", $newPath, "Machine")

            # Also update current session
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                        [System.Environment]::GetEnvironmentVariable("Path", "User")

            Write-Host "`n[SUCCESS] PATH updated successfully!" -ForegroundColor Green
            Write-Host "[INFO] Close and reopen PowerShell for changes to take effect" -ForegroundColor Cyan

            # Verify
            Write-Host "`n========================================" -ForegroundColor Cyan
            Write-Host "VERIFICATION (in new PowerShell)" -ForegroundColor Cyan
            Write-Host "========================================" -ForegroundColor Cyan
            Write-Host "Run these commands in a NEW PowerShell window:" -ForegroundColor White
            Write-Host "  flutter --version" -ForegroundColor Yellow
            Write-Host "  java -version" -ForegroundColor Yellow
            Write-Host "  dart --version" -ForegroundColor Yellow

        } catch {
            Write-Host "`n[ERROR] Failed to update PATH: $_" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "`n[CANCELLED] No changes made" -ForegroundColor Yellow
        exit 0
    }
} else {
    Write-Host "`n========================================" -ForegroundColor Green
    Write-Host "NO CHANGES NEEDED" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "All required paths are already in PATH" -ForegroundColor White

    Write-Host "`nIf commands still don't work, try:" -ForegroundColor Yellow
    Write-Host "  1. Close and reopen PowerShell" -ForegroundColor White
    Write-Host "  2. If that doesn't work, restart your computer" -ForegroundColor White
}

Write-Host ""
