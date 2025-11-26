# Build and Release Script for Company360
# Simplified version without emojis to avoid encoding issues

param(
    [string]$Version = "",
    [string]$BuildNumber = "",
    [switch]$SkipInstaller = $false
)

$ErrorActionPreference = "Stop"

Write-Host "Company360 Build and Release Script" -ForegroundColor Cyan
Write-Host ""

# Check if Flutter is installed
try {
    $flutterVersion = flutter --version 2>&1 | Select-Object -First 1
    Write-Host "[OK] Flutter found: $flutterVersion" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Flutter is not installed or not in PATH" -ForegroundColor Red
    exit 1
}

# Navigate to frontend directory
$frontendPath = Join-Path $PSScriptRoot "frontend"
if (-not (Test-Path $frontendPath)) {
    Write-Host "[ERROR] Frontend directory not found: $frontendPath" -ForegroundColor Red
    exit 1
}

Set-Location $frontendPath

# Read current version from pubspec.yaml
$pubspecPath = Join-Path $frontendPath "pubspec.yaml"
$pubspecContent = Get-Content $pubspecPath -Raw

if ($pubspecContent -match 'version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)') {
    $currentVersion = "$($matches[1]).$($matches[2]).$($matches[3])"
    $currentBuild = $matches[4]
    Write-Host "[INFO] Current Version: $currentVersion+$currentBuild" -ForegroundColor Yellow
} else {
    Write-Host "[ERROR] Could not parse version from pubspec.yaml" -ForegroundColor Red
    exit 1
}

# Get new version if not provided
if ([string]::IsNullOrEmpty($Version)) {
    Write-Host ""
    Write-Host "Enter new version (current: $currentVersion)" -ForegroundColor Yellow
    Write-Host "Press Enter to keep $currentVersion" -ForegroundColor Gray
    $Version = Read-Host "Version"
    if ([string]::IsNullOrEmpty($Version)) {
        $Version = $currentVersion
    }
}

if ([string]::IsNullOrEmpty($BuildNumber)) {
    $newBuild = [int]$currentBuild + 1
    Write-Host ""
    Write-Host "Enter new build number (current: $currentBuild)" -ForegroundColor Yellow
    Write-Host "Press Enter for $newBuild" -ForegroundColor Gray
    $BuildNumber = Read-Host "Build Number"
    if ([string]::IsNullOrEmpty($BuildNumber)) {
        $BuildNumber = $newBuild
    }
}

Write-Host ""
Write-Host "[INFO] New Version: $Version+$BuildNumber" -ForegroundColor Cyan
Write-Host ""

# Update pubspec.yaml
Write-Host "[INFO] Updating pubspec.yaml..." -ForegroundColor Yellow
$pubspecContent = $pubspecContent -replace 'version:\s*\d+\.\d+\.\d+\+\d+', "version: $Version+$BuildNumber"
Set-Content -Path $pubspecPath -Value $pubspecContent -NoNewline
Write-Host "[OK] Version updated in pubspec.yaml" -ForegroundColor Green

# Get Railway URL
$DEFAULT_RAILWAY_URL = "https://central360-backend-production.up.railway.app"
Write-Host ""
Write-Host "API Configuration:" -ForegroundColor Yellow
Write-Host "Press Enter for default: $DEFAULT_RAILWAY_URL" -ForegroundColor Gray
$API_URL = Read-Host "Enter Railway API URL"
if ([string]::IsNullOrEmpty($API_URL)) {
    $API_URL = $DEFAULT_RAILWAY_URL
}

# Remove /api/v1 if included
$API_URL = $API_URL -replace '/api/v1$', ''

Write-Host "[INFO] Using API URL: $API_URL" -ForegroundColor Cyan
Write-Host ""

# Clean previous builds
Write-Host "[INFO] Cleaning previous builds..." -ForegroundColor Yellow
flutter clean
flutter pub get

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Flutter clean/pub get failed" -ForegroundColor Red
    exit 1
}

# Build Windows app
Write-Host ""
Write-Host "[INFO] Building Windows app (Release)..." -ForegroundColor Yellow
Write-Host "   This may take a few minutes..." -ForegroundColor Gray

flutter build windows --release --dart-define=API_BASE_URL=$API_URL

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Windows build failed" -ForegroundColor Red
    exit 1
}

Write-Host "[OK] Windows app built successfully!" -ForegroundColor Green
Write-Host ""

# Create installer if not skipped
if (-not $SkipInstaller) {
    Write-Host "[INFO] Creating installer..." -ForegroundColor Yellow
    
    # Check if Inno Setup is installed
    $innoSetupPaths = @(
        "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
        "${env:ProgramFiles}\Inno Setup 6\ISCC.exe",
        "${env:ProgramFiles(x86)}\Inno Setup 5\ISCC.exe",
        "${env:ProgramFiles}\Inno Setup 5\ISCC.exe"
    )
    
    $innoSetup = $null
    foreach ($path in $innoSetupPaths) {
        if (Test-Path $path) {
            $innoSetup = $path
            break
        }
    }
    
    if ($null -eq $innoSetup) {
        Write-Host "[WARN] Inno Setup not found. Skipping installer creation." -ForegroundColor Yellow
        Write-Host "   Installer can be created manually later using setup.iss" -ForegroundColor Gray
    } else {
        $setupIssPath = Join-Path $frontendPath "setup.iss"
        if (Test-Path $setupIssPath) {
            Write-Host "   Using Inno Setup: $innoSetup" -ForegroundColor Gray
            & $innoSetup $setupIssPath
            
            if ($LASTEXITCODE -eq 0) {
                $outputDir = Join-Path $frontendPath "Output"
                if (Test-Path $outputDir) {
                    $installerFile = Get-ChildItem -Path $outputDir -Filter "Company360-Setup.exe" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
                    if ($installerFile) {
                        Write-Host "[OK] Installer created: $($installerFile.FullName)" -ForegroundColor Green
                    }
                }
            } else {
                Write-Host "[WARN] Installer creation failed, but build is complete" -ForegroundColor Yellow
            }
        } else {
            Write-Host "[WARN] setup.iss not found. Skipping installer creation." -ForegroundColor Yellow
        }
    }
}

# Summary
Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "Build Complete!" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "[INFO] Version: $Version+$BuildNumber" -ForegroundColor Yellow
Write-Host "[INFO] Build Location: build\windows\x64\runner\Release\" -ForegroundColor Yellow
Write-Host ""

if (-not $SkipInstaller) {
    $outputDir = Join-Path $frontendPath "Output"
    if (Test-Path $outputDir) {
        $installerFile = Get-ChildItem -Path $outputDir -Filter "Company360-Setup.exe" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($installerFile) {
            Write-Host "[INFO] Installer: $($installerFile.FullName)" -ForegroundColor Yellow
            Write-Host ""
        }
    }
}

Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "   1. Update backend version in: backend/src/routes/app.routes.js" -ForegroundColor White
Write-Host "      - version: '$Version'" -ForegroundColor Gray
Write-Host "      - buildNumber: '$BuildNumber'" -ForegroundColor Gray
Write-Host "      - downloadUrl: 'https://github.com/YOUR_USERNAME/central360/releases/download/v$Version/Company360-Setup.exe'" -ForegroundColor Gray
Write-Host "      - releaseNotes: 'Your release notes here'" -ForegroundColor Gray
Write-Host ""
Write-Host "   2. Test the installer on a clean machine" -ForegroundColor White
Write-Host ""
Write-Host "   3. Push code to GitHub:" -ForegroundColor White
Write-Host "      git add ." -ForegroundColor Gray
$commitMsg = "Release v$Version Build $BuildNumber - Scroll fixes"
Write-Host ('      git commit -m "' + $commitMsg + '"') -ForegroundColor Gray
Write-Host "      git push" -ForegroundColor Gray
Write-Host ""
Write-Host "   4. Deploy backend to Railway (if version changed)" -ForegroundColor White
Write-Host ""
Write-Host "   5. Create GitHub Release:" -ForegroundColor White
Write-Host "      - Go to: https://github.com/YOUR_USERNAME/central360/releases/new" -ForegroundColor Gray
Write-Host "      - Tag: v$Version" -ForegroundColor Gray
Write-Host "      - Title: Company360 v$Version" -ForegroundColor Gray
Write-Host "      - Description: Release notes" -ForegroundColor Gray
Write-Host "      - Upload: Company360-Setup.exe" -ForegroundColor Gray
Write-Host ""
Write-Host "   6. Customers will be notified automatically on next app launch" -ForegroundColor Green
Write-Host ""

