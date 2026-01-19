@echo off
echo ================================================
echo Starting Appium Server with Environment Variables
echo ================================================
echo.
echo Keep this window OPEN while running tests!
echo.
echo To run tests, open another terminal and run:
echo   cd E:\Projects\Quiz\appium-tests
echo   npm run test:smoke
echo.
echo ================================================

set ANDROID_HOME=C:\Users\thoma\AppData\Local\Android\sdk
set ANDROID_SDK_ROOT=C:\Users\thoma\AppData\Local\Android\sdk
set JAVA_HOME=C:\Program Files\Android\Android Studio\jbr

appium
