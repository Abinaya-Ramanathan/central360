@echo off
REM Build Android APK for Company360 v1.0.7

echo ========================================
echo Company360 v1.0.7 - Android Build
echo ========================================
echo.

REM Check Flutter installation
echo Checking Flutter installation...
flutter --version
if errorlevel 1 (
    echo ERROR: Flutter is not installed or not in PATH
    pause
    exit /b 1
)

REM Navigate to frontend directory
cd frontend

REM Clean previous builds
echo.
echo Cleaning previous builds...
flutter clean
if errorlevel 1 (
    echo ERROR: Flutter clean failed
    pause
    exit /b 1
)

REM Get dependencies
echo.
echo Getting Flutter dependencies...
flutter pub get
if errorlevel 1 (
    echo ERROR: Flutter pub get failed
    pause
    exit /b 1
)

REM Build Android APK
echo.
echo ========================================
echo Building Android Release APK...
echo ========================================
echo.

flutter build apk --release

if errorlevel 1 (
    echo.
    echo ERROR: Android build failed
    cd ..
    pause
    exit /b 1
)

REM Copy APK to frontend root with version name
if exist "build\app\outputs\flutter-apk\app-release.apk" (
    copy /Y "build\app\outputs\flutter-apk\app-release.apk" "company360-v1.0.7.apk"
    echo.
    echo ========================================
    echo Android APK build completed successfully!
    echo ========================================
    echo.
    echo Output: frontend\company360-v1.0.7.apk
    echo.
    echo Version: 1.0.7
    echo Build Number: 8
) else (
    echo.
    echo WARNING: APK file not found at expected location
    echo Please check the build output for errors.
)

cd ..
pause

