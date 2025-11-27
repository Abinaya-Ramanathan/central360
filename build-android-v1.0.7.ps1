# Build Android APK for Company360 v1.0.7

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Company360 v1.0.7 - Android Build" -ForegroundColor Cyan
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

# Build Android APK
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Building Android Release APK..." -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

flutter build apk --release

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "ERROR: Android build failed" -ForegroundColor Red
    Set-Location -Path ".."
    exit 1
}

# Copy APK to frontend root with version name
$apkSource = "build\app\outputs\flutter-apk\app-release.apk"
$apkDest = "company360-v1.0.7.apk"

if (Test-Path $apkSource) {
    Copy-Item -Path $apkSource -Destination $apkDest -Force
    $fileSize = (Get-Item $apkDest).Length / 1MB
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "Android APK build completed successfully!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Output: frontend\$apkDest" -ForegroundColor Cyan
    Write-Host "File size: $([math]::Round($fileSize, 2)) MB" -ForegroundColor White
    Write-Host ""
    Write-Host "Version: 1.0.7" -ForegroundColor White
    Write-Host "Build Number: 8" -ForegroundColor White
} else {
    Write-Host ""
    Write-Host "WARNING: APK file not found at expected location: $apkSource" -ForegroundColor Yellow
    Write-Host "Please check the build output for errors." -ForegroundColor Yellow
}

Set-Location -Path ".."

