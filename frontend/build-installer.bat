@echo off
echo ========================================
echo Company360 Installer Builder
echo ========================================
echo.

REM Check if Inno Setup is installed
set INNO_FOUND=0
set INNO_PATH=

REM Try Program Files (x86) first
if exist "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" (
    set INNO_PATH=C:\Program Files (x86)\Inno Setup 6\ISCC.exe
    set INNO_FOUND=1
    goto :found
)

REM Try Program Files if not found
if exist "C:\Program Files\Inno Setup 6\ISCC.exe" (
    set INNO_PATH=C:\Program Files\Inno Setup 6\ISCC.exe
    set INNO_FOUND=1
    goto :found
)

:found
if %INNO_FOUND%==0 (
    echo ERROR: Inno Setup not found!
    echo Please install Inno Setup 6 from: https://jrsoftware.org/isdl.php
    echo.
    echo Expected locations:
    echo   C:\Program Files (x86)\Inno Setup 6\ISCC.exe
    echo   C:\Program Files\Inno Setup 6\ISCC.exe
    echo.
    pause
    exit /b 1
)

echo Found Inno Setup at: %INNO_PATH%
echo.

REM Build Flutter Windows app first
echo Step 1: Building Flutter Windows app...
call flutter build windows --release
if errorlevel 1 (
    echo ERROR: Flutter build failed!
    pause
    exit /b 1
)
echo.

REM Build the installer
echo Step 2: Building installer...
"%INNO_PATH%" "%~dp0setup.iss"
if errorlevel 1 (
    echo ERROR: Installer build failed!
    pause
    exit /b 1
)

echo.
echo ========================================
echo SUCCESS! Installer created!
echo ========================================
echo.
echo Installer location: installer\company360-setup.exe
echo.
pause
