@echo off
echo ========================================
echo Company360 - Production Installer Builder
echo ========================================
echo.

REM Check if Railway URL is provided
if "%RAILWAY_URL%"=="" (
    echo ERROR: Railway URL not provided!
    echo.
    echo Usage:
    echo   set RAILWAY_URL=https://your-app.railway.app
    echo   build-production-installer.bat
    echo.
    echo Or provide it now:
    set /p RAILWAY_URL="Enter your Railway API URL (e.g., https://your-app.railway.app): "
)

if "%RAILWAY_URL%"=="" (
    echo ERROR: Railway URL is required!
    pause
    exit /b 1
)

echo Using Railway URL: %RAILWAY_URL%
echo.

REM Navigate to frontend directory
cd /d "%~dp0frontend"
if errorlevel 1 (
    echo ERROR: Could not navigate to frontend directory
    pause
    exit /b 1
)

REM Clean previous builds
echo Step 1: Cleaning previous builds...
call flutter clean
echo.

REM Build Windows app with production API URL
echo Step 2: Building Windows app with production API...
echo Command: flutter build windows --release --dart-define=API_BASE_URL=%RAILWAY_URL%
call flutter build windows --release --dart-define=API_BASE_URL=%RAILWAY_URL%
if errorlevel 1 (
    echo ERROR: Flutter build failed!
    pause
    exit /b 1
)
echo.

REM Check if Inno Setup is installed
set INNO_FOUND=0
set INNO_PATH=

if exist "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" (
    set INNO_PATH=C:\Program Files (x86)\Inno Setup 6\ISCC.exe
    set INNO_FOUND=1
    goto :found
)

if exist "C:\Program Files\Inno Setup 6\ISCC.exe" (
    set INNO_PATH=C:\Program Files\Inno Setup 6\ISCC.exe
    set INNO_FOUND=1
    goto :found
)

:found
if %INNO_FOUND%==0 (
    echo WARNING: Inno Setup not found!
    echo Please build the installer manually:
    echo   1. Open Inno Setup Compiler
    echo   2. File -^> Open -^> setup.iss
    echo   3. Build -^> Compile
    echo.
    echo Installer location: installer\company360-setup.exe
    pause
    exit /b 0
)

REM Build the installer
echo Step 3: Building installer...
"%INNO_PATH%" "%~dp0setup.iss"
if errorlevel 1 (
    echo ERROR: Installer build failed!
    pause
    exit /b 1
)

echo.
echo ========================================
echo SUCCESS! Production installer created!
echo ========================================
echo.
echo Installer location: installer\company360-setup.exe
echo Railway API URL: %RAILWAY_URL%
echo.
echo Next steps:
echo   1. Test the installer on a clean machine
echo   2. Upload to GitHub Releases
echo   3. Share the download link
echo.
pause

