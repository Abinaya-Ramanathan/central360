@echo off
REM Run Company360 with console output visible
echo Starting Company360...
echo.
echo Debug logs will appear below:
echo ========================================
echo.

cd /d "%~dp0build\windows\x64\runner\Release"
company360.exe

pause

