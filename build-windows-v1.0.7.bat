@echo off
REM Build Windows Release for Company360 v1.0.7

echo ========================================
echo Company360 v1.0.7 - Windows Build
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
echo.

flutter build windows --release

if errorlevel 1 (
    echo.
    echo ERROR: Windows build failed
    cd ..
    pause
    exit /b 1
)

REM Check if executable exists
if exist "build\windows\x64\runner\Release\company360.exe" (
    echo.
    echo ========================================
    echo Windows build completed successfully!
    echo ========================================
    echo.
    echo Output: frontend\build\windows\x64\runner\Release\company360.exe
    echo.
    echo Version: 1.0.7
    echo Build Number: 8
    echo.
    echo To build installer, run:
    echo   build-installer-only.ps1
) else (
    echo.
    echo WARNING: Executable not found at expected location
    echo Please check the build output for errors.
)

cd ..
pause

