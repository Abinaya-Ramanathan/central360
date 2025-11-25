@echo off
REM Build Release Script for Central360 (Windows)
REM Builds APK for Android and Windows executable
setlocal enabledelayedexpansion

echo 🚀 Building Central360 Release Versions...
echo.

REM Check if Flutter is installed
where flutter >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo ❌ Flutter is not installed or not in PATH
    pause
    exit /b 1
)

REM Get production API URL from user or use default Railway URL
set DEFAULT_RAILWAY_URL=https://central360-backend-production.up.railway.app

if "%API_BASE_URL%"=="" (
    echo Default Railway URL: %DEFAULT_RAILWAY_URL%
    set /p API_URL="Enter Production API Base URL (press Enter for default): "
    if "!API_URL!"=="" set API_URL=%DEFAULT_RAILWAY_URL%
) else (
    set API_URL=%API_BASE_URL%
)

REM Remove /api/v1 if user included it
set API_URL=!API_URL:/api/v1=!

echo 📡 Using API Base URL: !API_URL!
echo 📡 Full API URL will be: !API_URL!/api/v1
echo.

REM Clean previous builds
echo 🧹 Cleaning previous builds...
call flutter clean
call flutter pub get

REM Build Android APK
echo.
echo 📱 Building Android APK...
call flutter build apk --release --dart-define=API_BASE_URL=!API_URL!

if %ERRORLEVEL% EQU 0 (
    echo ✅ Android APK built successfully!
    echo 📦 Location: build\app\outputs\flutter-apk\app-release.apk
) else (
    echo ❌ Android APK build failed
    pause
    exit /b 1
)

REM Build Windows executable
echo.
echo 💻 Building Windows executable...
call flutter build windows --release --dart-define=API_BASE_URL=!API_URL!

if %ERRORLEVEL% EQU 0 (
    echo ✅ Windows executable built successfully!
    echo 📦 Location: build\windows\x64\runner\Release\
) else (
    echo ❌ Windows build failed
    pause
    exit /b 1
)

echo.
echo 🎉 Build completed successfully!
echo.
echo 📦 Output files:
echo   - Android APK: build\app\outputs\flutter-apk\app-release.apk
echo   - Windows EXE: build\windows\x64\runner\Release\central360.exe
echo.
echo 📝 Next steps:
echo   1. Upload APK to your website or Google Play Store
echo   2. Upload Windows executable to your website or create installer
echo.
pause

