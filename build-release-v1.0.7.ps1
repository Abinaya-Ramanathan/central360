# Build Script for Company360 v1.0.7
# Builds Windows and Android releases

param(
    [switch]$SkipBuild,
    [switch]$SkipAndroid,
    [switch]$SkipWindows,
    [switch]$SkipInstaller
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Company360 v1.0.7 Build Script" -ForegroundColor Cyan
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
if (-not $SkipWindows) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "Building Windows Release..." -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    
    flutter build windows --release
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Windows build failed" -ForegroundColor Red
        exit 1
    }
    
    Write-Host ""
    Write-Host "Windows build completed successfully!" -ForegroundColor Green
    Write-Host "Output: frontend\build\windows\x64\runner\Release\company360.exe" -ForegroundColor Cyan
}

# Build Android
if (-not $SkipAndroid) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "Building Android Release APK..." -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    
    flutter build apk --release
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Android build failed" -ForegroundColor Red
        exit 1
    }
    
    # Copy APK to frontend root with version name
    $apkSource = "build\app\outputs\flutter-apk\app-release.apk"
    $apkDest = "company360-v1.0.7.apk"
    
    if (Test-Path $apkSource) {
        Copy-Item -Path $apkSource -Destination $apkDest -Force
        Write-Host ""
        Write-Host "Android APK build completed successfully!" -ForegroundColor Green
        Write-Host "Output: frontend\$apkDest" -ForegroundColor Cyan
    } else {
        Write-Host "WARNING: APK file not found at expected location: $apkSource" -ForegroundColor Yellow
    }
}

# Build Windows Installer with Inno Setup
if (-not $SkipInstaller -and -not $SkipWindows) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "Building Windows Installer..." -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    
    # Check if Inno Setup is installed
    $innoSetupPaths = @(
        "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
        "${env:ProgramFiles}\Inno Setup 6\ISCC.exe",
        "${env:ProgramFiles(x86)}\Inno Setup 5\ISCC.exe",
        "${env:ProgramFiles}\Inno Setup 5\ISCC.exe"
    )
    
    $innoSetupExe = $null
    foreach ($path in $innoSetupPaths) {
        if (Test-Path $path) {
            $innoSetupExe = $path
            break
        }
    }
    
    if ($null -eq $innoSetupExe) {
        Write-Host "WARNING: Inno Setup not found. Skipping installer build." -ForegroundColor Yellow
        Write-Host "Please install Inno Setup from: https://jrsoftware.org/isdl.php" -ForegroundColor Yellow
        Write-Host "Or run the installer build manually using the setup.iss file." -ForegroundColor Yellow
    } else {
        Write-Host "Found Inno Setup at: $innoSetupExe" -ForegroundColor Cyan
        Write-Host "Compiling installer..." -ForegroundColor Yellow
        
        & $innoSetupExe "setup.iss"
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host ""
            Write-Host "Windows Installer built successfully!" -ForegroundColor Green
            Write-Host "Output: frontend\installer\company360-setup.exe" -ForegroundColor Cyan
        } else {
            Write-Host "ERROR: Inno Setup compilation failed" -ForegroundColor Red
            exit 1
        }
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Build Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Version: 1.0.7" -ForegroundColor White
Write-Host "Build Number: 8" -ForegroundColor White
Write-Host ""

if (-not $SkipWindows) {
    Write-Host "Windows:" -ForegroundColor Green
    Write-Host "  - Executable: frontend\build\windows\x64\runner\Release\company360.exe" -ForegroundColor Cyan
    if (-not $SkipInstaller) {
        Write-Host "  - Installer: frontend\installer\company360-setup.exe" -ForegroundColor Cyan
    }
}

if (-not $SkipAndroid) {
    Write-Host "Android:" -ForegroundColor Green
    Write-Host "  - APK: frontend\company360-v1.0.7.apk" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "Build completed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Test the builds" -ForegroundColor White
Write-Host "2. Create GitHub release with version tag v1.0.7" -ForegroundColor White
Write-Host "3. Upload installer and APK to GitHub release" -ForegroundColor White
Write-Host "4. Push code to repository" -ForegroundColor White

Set-Location -Path ".."

