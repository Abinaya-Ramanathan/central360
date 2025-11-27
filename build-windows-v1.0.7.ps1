# Build Windows Release for Company360 v1.0.7

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Company360 v1.0.7 - Windows Build" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check Flutter installation
Write-Host "Checking Flutter installation..." -ForegroundColor Yellow
flutter --version
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Flutter is not installed or not in PATH" -ForegroundColor Red
    exit 1
}

# Navigate to frontend directory
Set-Location -Path "frontend"

# Clean previous builds
Write-Host ""
Write-Host "Cleaning previous builds..." -ForegroundColor Yellow
flutter clean
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Flutter clean failed" -ForegroundColor Red
    exit 1
}

# Get dependencies
Write-Host ""
Write-Host "Getting Flutter dependencies..." -ForegroundColor Yellow
flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Flutter pub get failed" -ForegroundColor Red
    exit 1
}

# Build Windows
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Building Windows Release..." -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

flutter build windows --release

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "ERROR: Windows build failed" -ForegroundColor Red
    Set-Location -Path ".."
    exit 1
}

# Check if executable exists
$exePath = "build\windows\x64\runner\Release\company360.exe"
if (Test-Path $exePath) {
    $fileSize = (Get-Item $exePath).Length / 1MB
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "Windows build completed successfully!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Output: frontend\$exePath" -ForegroundColor Cyan
    Write-Host "File size: $([math]::Round($fileSize, 2)) MB" -ForegroundColor White
    Write-Host ""
    Write-Host "Version: 1.0.7" -ForegroundColor White
    Write-Host "Build Number: 8" -ForegroundColor White
    Write-Host ""
    Write-Host "To build installer, run:" -ForegroundColor Yellow
    Write-Host "  .\build-installer-only.ps1" -ForegroundColor Cyan
} else {
    Write-Host ""
    Write-Host "WARNING: Executable not found at expected location: $exePath" -ForegroundColor Yellow
    Write-Host "Please check the build output for errors." -ForegroundColor Yellow
}

Set-Location -Path ".."

