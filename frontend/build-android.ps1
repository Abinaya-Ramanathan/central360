# Build Android APK Script for Central360
# Builds release APK for Android

param(
    [string]$API_URL = "",
    [switch]$SkipClean = $false
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Central360 Android Build Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if Flutter is installed
try {
    $flutterVersion = flutter --version 2>&1 | Select-Object -First 1
    Write-Host "[OK] Flutter found: $flutterVersion" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Flutter is not installed or not in PATH" -ForegroundColor Red
    Write-Host "Please install Flutter from: https://flutter.dev/docs/get-started/install" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

# Navigate to frontend directory
# Script is located in frontend/build-android.ps1, so $PSScriptRoot is the frontend directory
$frontendPath = $PSScriptRoot

# Verify we're in the right place by checking for pubspec.yaml
if (-not (Test-Path (Join-Path $frontendPath "pubspec.yaml"))) {
    Write-Host "[ERROR] pubspec.yaml not found in: $frontendPath" -ForegroundColor Red
    Write-Host "Please ensure this script is in the frontend directory." -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

Set-Location $frontendPath

# Get API URL
$DEFAULT_RAILWAY_URL = "https://central360-backend-production.up.railway.app"

if ([string]::IsNullOrEmpty($API_URL)) {
    Write-Host "API Configuration:" -ForegroundColor Yellow
    Write-Host "Press Enter for default: $DEFAULT_RAILWAY_URL" -ForegroundColor Gray
    $API_URL = Read-Host "Enter Railway API URL"
    if ([string]::IsNullOrEmpty($API_URL)) {
        $API_URL = $DEFAULT_RAILWAY_URL
    }
}

# Remove /api/v1 if included
$API_URL = $API_URL -replace '/api/v1$', ''

Write-Host ""
Write-Host "[INFO] Using API URL: $API_URL" -ForegroundColor Cyan
Write-Host "[INFO] Full API URL will be: $API_URL/api/v1" -ForegroundColor Gray
Write-Host ""

# Read version from pubspec.yaml
$pubspecPath = Join-Path $frontendPath "pubspec.yaml"
$pubspecContent = Get-Content $pubspecPath -Raw

if ($pubspecContent -match 'version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)') {
    $version = "$($matches[1]).$($matches[2]).$($matches[3])"
    $buildNumber = $matches[4]
    Write-Host "[INFO] Building version: $version+$buildNumber" -ForegroundColor Yellow
} else {
    Write-Host "[WARN] Could not parse version from pubspec.yaml" -ForegroundColor Yellow
    $version = "1.0.0"
    $buildNumber = "1"
}

Write-Host ""

# Clean previous builds
if (-not $SkipClean) {
    Write-Host "[INFO] Cleaning previous builds..." -ForegroundColor Yellow
    flutter clean
    
    # Also clean Gradle build cache to fix Kotlin incremental compilation issues
    if (Test-Path "android\.gradle") {
        Write-Host "[INFO] Cleaning Gradle cache..." -ForegroundColor Yellow
        Remove-Item -Path "android\.gradle" -Recurse -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path "build") {
        Write-Host "[INFO] Cleaning build directory..." -ForegroundColor Yellow
        Remove-Item -Path "build" -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    flutter pub get
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] Flutter clean/pub get failed" -ForegroundColor Red
        Read-Host "Press Enter to exit"
        exit 1
    }
} else {
    Write-Host "[INFO] Skipping clean (using --SkipClean)" -ForegroundColor Yellow
    flutter pub get
}

# Build Android APK
Write-Host ""
Write-Host "[INFO] Building Android APK (Release)..." -ForegroundColor Yellow
Write-Host "   This may take a few minutes..." -ForegroundColor Gray
Write-Host ""

flutter build apk --release --dart-define=API_BASE_URL=$API_URL

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Android APK build failed" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host ""
Write-Host "[OK] Android APK built successfully!" -ForegroundColor Green
Write-Host ""

# Get APK path
$apkPath = Join-Path $frontendPath "build\app\outputs\flutter-apk\app-release.apk"

if (Test-Path $apkPath) {
    $apkFile = Get-Item $apkPath
    $apkSize = [math]::Round($apkFile.Length / 1MB, 2)
    
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "Build Complete!" -ForegroundColor Green
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "[INFO] Version: $version+$buildNumber" -ForegroundColor Yellow
    Write-Host "[INFO] APK Location: $apkPath" -ForegroundColor Yellow
    Write-Host "[INFO] APK Size: $apkSize MB" -ForegroundColor Yellow
    Write-Host ""
    
    # Suggest rename
    $suggestedName = "central360-v$version.apk"
    Write-Host "Suggested filename for release: $suggestedName" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "Next Steps:" -ForegroundColor Cyan
    Write-Host "   1. Test the APK on an Android device" -ForegroundColor White
    Write-Host "   2. Update backend version in: backend/src/routes/app.routes.js" -ForegroundColor White
    Write-Host "      - Update android.downloadUrl with GitHub release URL" -ForegroundColor Gray
    Write-Host "   3. Push code to GitHub:" -ForegroundColor White
    Write-Host "      git add ." -ForegroundColor Gray
    Write-Host ('      git commit -m "Release Android v' + $version + ' Build ' + $buildNumber + '"') -ForegroundColor Gray
    Write-Host "      git push" -ForegroundColor Gray
    Write-Host ""
    Write-Host "   4. Create GitHub Release:" -ForegroundColor White
    Write-Host "      - Go to: https://github.com/Abinaya-Ramanathan/central360/releases/new" -ForegroundColor Gray
    Write-Host "      - Tag: v$version" -ForegroundColor Gray
    Write-Host "      - Title: Central360 v$version (Android)" -ForegroundColor Gray
    Write-Host "      - Upload: $suggestedName" -ForegroundColor Gray
    Write-Host ""
    Write-Host "   5. Update download URL in app.routes.js after release" -ForegroundColor White
    Write-Host ""
} else {
    Write-Host "[WARN] APK file not found at expected location: $apkPath" -ForegroundColor Yellow
}

Read-Host "Press Enter to exit"

