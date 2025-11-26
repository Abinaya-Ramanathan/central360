# Build Windows App Only (Without Installer)
# Use this if you don't have Inno Setup installed
# This creates the executable but not the installer package

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Company360 Windows App Builder" -ForegroundColor Cyan
Write-Host "(Without Installer)" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Default Railway URL for production builds
$railwayUrl = "https://central360-backend-production.up.railway.app"

# Build Flutter Windows app with Railway URL
Write-Host "Building Flutter Windows app with Railway URL..." -ForegroundColor Cyan
Write-Host "Using API URL: $railwayUrl" -ForegroundColor Gray
Write-Host ""

flutter build windows --release --dart-define=API_BASE_URL=$railwayUrl

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Flutter build failed!" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "SUCCESS! Windows app built!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Executable location: build\windows\x64\runner\Release\company360.exe" -ForegroundColor Green
Write-Host ""
Write-Host "Note: This is the executable only, not an installer." -ForegroundColor Yellow
Write-Host "To create an installer, install Inno Setup 6 and run build-installer.ps1" -ForegroundColor Yellow
Write-Host ""
Read-Host "Press Enter to exit"

