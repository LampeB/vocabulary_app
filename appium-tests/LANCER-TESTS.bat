@echo off
echo =============================================
echo    LANCEMENT DES TESTS APPIUM
echo =============================================
echo.
echo Ce script va automatiquement:
echo   1. Lancer l'emulateur Android (si pas deja ouvert)
echo   2. Construire l'APK Flutter (si necessaire)
echo   3. Demarrer Appium (si pas deja lance)
echo   4. Desinstaller l'ancienne app (fresh install)
echo   5. Lancer tous les tests
echo.
echo Options disponibles (via PowerShell):
echo   -SkipBuild    : ne pas reconstruire l'APK
echo   -SmokeOnly    : lancer uniquement le smoke test
echo   -Emulator "X" : choisir un emulateur specifique
echo.
pause

powershell -ExecutionPolicy Bypass -File "%~dp0run-all.ps1"

pause
