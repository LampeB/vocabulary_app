@echo off
echo =============================================
echo    LANCEMENT DES TESTS APPIUM
echo =============================================
echo.
echo Ce script va:
echo   1. Verifier l'emulateur
echo   2. Construire l'APK si necessaire
echo   3. Demarrer Appium
echo   4. Lancer les tests
echo.
pause

powershell -ExecutionPolicy Bypass -File "%~dp0run-all.ps1"

pause
