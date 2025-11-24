Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Company360 Installer Builder" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if Inno Setup is installed
$innoSetupPaths = @(
    "C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
    "C:\Program Files\Inno Setup 6\ISCC.exe"
)

$innoSetupPath = $null
foreach ($path in $innoSetupPaths) {
    if (Test-Path $path) {
        $innoSetupPath = $path
        break
    }
}

if (-not $innoSetupPath) {
    Write-Host "ERROR: Inno Setup not found!" -ForegroundColor Red
    Write-Host "Please install Inno Setup 6 from: https://jrsoftware.org/isdl.php" -ForegroundColor Yellow
    Write-Host "Expected locations:" -ForegroundColor Yellow
    foreach ($path in $innoSetupPaths) {
        Write-Host "  $path" -ForegroundColor Yellow
    }
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host "Found Inno Setup at: $innoSetupPath" -ForegroundColor Green
Write-Host ""

# Build Flutter Windows app first
Write-Host "Step 1: Building Flutter Windows app..." -ForegroundColor Cyan
& flutter build windows --release
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Flutter build failed!" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}
Write-Host ""

# Build the installer
Write-Host "Step 2: Building installer..." -ForegroundColor Cyan
$setupScript = Join-Path $PSScriptRoot "setup.iss"
& $innoSetupPath $setupScript
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Installer build failed!" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "SUCCESS! Installer created!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Installer location: installer\company360-setup.exe" -ForegroundColor Green
Write-Host ""
Read-Host "Press Enter to exit"

