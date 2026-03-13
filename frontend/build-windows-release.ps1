# Build Windows Release and package for GitHub
# Produces: (1) Full Release folder, (2) ZIP for upload, (3) Optional installer if Inno Setup is installed.
# Users must get the ZIP or the installer - the .exe alone (~76 KB) will not run (dependencies failed).

$ErrorActionPreference = "Stop"
$frontendPath = $PSScriptRoot

# API URL for release (Railway production)
$railwayUrl = "https://central360-backend-production.up.railway.app"
if ($env:API_BASE_URL) { $railwayUrl = $env:API_BASE_URL }

# Read version from pubspec.yaml (e.g. 1.0.25+26 -> 1.0.25)
$versionLine = Get-Content (Join-Path $frontendPath "pubspec.yaml") | Where-Object { $_ -match "^version:\s*(\d+\.\d+\.\d+)" }
$version = "1.0.25"
if ($versionLine -match "version:\s*(\d+\.\d+\.\d+)") { $version = $Matches[1] }

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Company360 Windows Release Build" -ForegroundColor Cyan
Write-Host "Version: $version | API: $railwayUrl" -ForegroundColor Gray
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Set-Location $frontendPath

# Step 1: Clean and get deps
Write-Host "[1/4] flutter clean..." -ForegroundColor Cyan
flutter clean
if ($LASTEXITCODE -ne 0) { Write-Host "ERROR: flutter clean failed" -ForegroundColor Red; exit 1 }

Write-Host "[2/4] flutter pub get..." -ForegroundColor Cyan
flutter pub get
if ($LASTEXITCODE -ne 0) { Write-Host "ERROR: flutter pub get failed" -ForegroundColor Red; exit 1 }

# Step 2: Build Windows release
Write-Host "[3/4] flutter build windows (release)..." -ForegroundColor Cyan
flutter build windows --release --dart-define=API_BASE_URL=$railwayUrl
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Flutter Windows build failed!" -ForegroundColor Red
    exit 1
}

$releaseDir = Join-Path $frontendPath "build\windows\x64\runner\Release"
if (-not (Test-Path $releaseDir)) {
    Write-Host "ERROR: Release folder not found: $releaseDir" -ForegroundColor Red
    exit 1
}

# Show sizes
$exePath = Join-Path $releaseDir "company360.exe"
$dllPath = Join-Path $releaseDir "flutter_windows.dll"
$exeSize = (Get-Item $exePath).Length / 1KB
$dllSize = (Get-Item $dllPath).Length / 1MB
$totalSize = (Get-ChildItem $releaseDir -Recurse | Measure-Object -Property Length -Sum).Sum / 1MB
Write-Host ""
Write-Host "Build output:" -ForegroundColor Green
Write-Host "  company360.exe     : $([math]::Round($exeSize, 1)) KB (launcher - normal to be small)" -ForegroundColor Gray
Write-Host "  flutter_windows.dll: $([math]::Round($dllSize, 2)) MB" -ForegroundColor Gray
Write-Host "  Total Release folder: $([math]::Round($totalSize, 2)) MB" -ForegroundColor Gray
Write-Host ""

# Step 3: Create ZIP for GitHub (entire Release folder - required for app to run)
$releaseZipDir = Join-Path $frontendPath "release"
if (-not (Test-Path $releaseZipDir)) { New-Item -ItemType Directory -Path $releaseZipDir | Out-Null }
$zipName = "Company360-Windows-$version.zip"
$zipPath = Join-Path $releaseZipDir $zipName

Write-Host "[4/4] Creating ZIP for GitHub: $zipName ..." -ForegroundColor Cyan
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Compress-Archive -Path "$releaseDir\*" -DestinationPath $zipPath -CompressionLevel Optimal
$zipSize = (Get-Item $zipPath).Length / 1MB
Write-Host "  Created: $zipPath ($([math]::Round($zipSize, 2)) MB)" -ForegroundColor Green
Write-Host ""

# Optional: Build installer if Inno Setup is available
$innoPaths = @("C:\Program Files (x86)\Inno Setup 6\ISCC.exe", "C:\Program Files\Inno Setup 6\ISCC.exe")
$innoExe = $innoPaths | Where-Object { Test-Path $_ } | Select-Object -First 1
if ($innoExe) {
    Write-Host "Building installer (Inno Setup)..." -ForegroundColor Cyan
    $setupScript = Join-Path $frontendPath "setup.iss"
    & $innoExe $setupScript
    if ($LASTEXITCODE -eq 0) {
        $installerPath = Join-Path $frontendPath "installer\company360-setup.exe"
        if (Test-Path $installerPath) {
            $installerSize = (Get-Item $installerPath).Length / 1MB
            Write-Host "  Installer: $installerPath ($([math]::Round($installerSize, 2)) MB)" -ForegroundColor Green
        }
    }
} else {
    Write-Host "Inno Setup not found - skipping installer. ZIP is enough for GitHub." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "SUCCESS" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "For GitHub Release, upload ONE of:" -ForegroundColor White
Write-Host "  1) $zipName  (users: unzip, then run company360.exe from inside the folder)" -ForegroundColor Cyan
Write-Host "  2) installer\company360-setup.exe  (if built above; single installer)" -ForegroundColor Cyan
Write-Host ""
Write-Host "Do NOT upload only company360.exe - it will show 'dependencies failed'." -ForegroundColor Yellow
Write-Host ""
