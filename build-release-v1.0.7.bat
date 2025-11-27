@echo off
REM Build Script for Company360 v1.0.7
REM Builds Windows and Android releases

echo ========================================
echo Company360 v1.0.7 Build Script
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

REM Build Windows
echo.
echo ========================================
echo Building Windows Release...
echo ========================================
flutter build windows --release
if errorlevel 1 (
    echo ERROR: Windows build failed
    pause
    exit /b 1
)
echo.
echo Windows build completed successfully!
echo Output: frontend\build\windows\x64\runner\Release\company360.exe

REM Build Android
echo.
echo ========================================
echo Building Android Release APK...
echo ========================================
flutter build apk --release
if errorlevel 1 (
    echo ERROR: Android build failed
    pause
    exit /b 1
)

REM Copy APK to frontend root with version name
if exist "build\app\outputs\flutter-apk\app-release.apk" (
    copy /Y "build\app\outputs\flutter-apk\app-release.apk" "company360-v1.0.7.apk"
    echo.
    echo Android APK build completed successfully!
    echo Output: frontend\company360-v1.0.7.apk
) else (
    echo WARNING: APK file not found at expected location
)

REM Build Windows Installer with Inno Setup
echo.
echo ========================================
echo Building Windows Installer...
echo ========================================

REM Check for Inno Setup
set INNO_SETUP=
if exist "%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe" (
    set INNO_SETUP=%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe
) else if exist "%ProgramFiles%\Inno Setup 6\ISCC.exe" (
    set INNO_SETUP=%ProgramFiles%\Inno Setup 6\ISCC.exe
) else if exist "%ProgramFiles(x86)%\Inno Setup 5\ISCC.exe" (
    set INNO_SETUP=%ProgramFiles(x86)%\Inno Setup 5\ISCC.exe
) else if exist "%ProgramFiles%\Inno Setup 5\ISCC.exe" (
    set INNO_SETUP=%ProgramFiles%\Inno Setup 5\ISCC.exe
)

if "%INNO_SETUP%"=="" (
    echo WARNING: Inno Setup not found. Skipping installer build.
    echo Please install Inno Setup from: https://jrsoftware.org/isdl.php
    echo Or run the installer build manually using the setup.iss file.
) else (
    echo Found Inno Setup at: %INNO_SETUP%
    echo Compiling installer...
    "%INNO_SETUP%" setup.iss
    if errorlevel 1 (
        echo ERROR: Inno Setup compilation failed
        pause
        exit /b 1
    ) else (
        echo.
        echo Windows Installer built successfully!
        echo Output: frontend\installer\company360-setup.exe
    )
)

echo.
echo ========================================
echo Build Summary
echo ========================================
echo Version: 1.0.7
echo Build Number: 8
echo.
echo Windows:
echo   - Executable: frontend\build\windows\x64\runner\Release\company360.exe
echo   - Installer: frontend\installer\company360-setup.exe
echo.
echo Android:
echo   - APK: frontend\company360-v1.0.7.apk
echo.
echo Build completed successfully!
echo.
echo Next steps:
echo 1. Test the builds
echo 2. Create GitHub release with version tag v1.0.7
echo 3. Upload installer and APK to GitHub release
echo 4. Push code to repository
echo.

cd ..
pause

