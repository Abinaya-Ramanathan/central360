# Build Windows Installer Only (using Inno Setup)
# Run this after building Windows release

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Company360 v1.0.7 Installer Build" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Navigate to frontend directory
Set-Location -Path "frontend"

# Check if Windows build exists
$exePath = "build\windows\x64\runner\Release\company360.exe"
if (-not (Test-Path $exePath)) {
    Write-Host "ERROR: Windows build not found at: $exePath" -ForegroundColor Red
    Write-Host "Please run the Windows build first:" -ForegroundColor Yellow
    Write-Host "  flutter build windows --release" -ForegroundColor White
    exit 1
}

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
    Write-Host "ERROR: Inno Setup not found!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please install Inno Setup from:" -ForegroundColor Yellow
    Write-Host "  https://jrsoftware.org/isdl.php" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Or manually compile setup.iss using Inno Setup Compiler" -ForegroundColor Yellow
    exit 1
}

Write-Host "Found Inno Setup at: $innoSetupExe" -ForegroundColor Green
Write-Host "Compiling installer..." -ForegroundColor Yellow
Write-Host ""

# Compile the installer
& $innoSetupExe "setup.iss"

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "Installer built successfully!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Output: installer\company360-setup.exe" -ForegroundColor Cyan
    Write-Host ""
    
    # Check if file exists
    $installerPath = "installer\company360-setup.exe"
    if (Test-Path $installerPath) {
        $fileSize = (Get-Item $installerPath).Length / 1MB
        Write-Host "File size: $([math]::Round($fileSize, 2)) MB" -ForegroundColor White
    }
} else {
    Write-Host ""
    Write-Host "ERROR: Inno Setup compilation failed" -ForegroundColor Red
    Write-Host "Exit code: $LASTEXITCODE" -ForegroundColor Red
    exit 1
}

Set-Location -Path ".."

