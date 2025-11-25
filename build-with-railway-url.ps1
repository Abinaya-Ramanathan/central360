# Company360 - Build Production Installer
# Usage: .\build-with-railway-url.ps1

Write-Host "========================================"
Write-Host "Company360 - Production Installer Builder"
Write-Host "========================================"
Write-Host ""

# Get Railway URL
$railwayUrl = Read-Host "Enter your Railway API URL (e.g., https://your-app.railway.app)"

if ([string]::IsNullOrWhiteSpace($railwayUrl)) {
    Write-Host "ERROR: Railway URL is required!" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host ""
Write-Host "Using Railway URL: $railwayUrl"
Write-Host ""

# Navigate to frontend
Set-Location "frontend"

# Clean previous builds
Write-Host "Step 1: Cleaning previous builds..."
flutter clean
Write-Host ""

# Build Windows app with production API URL
Write-Host "Step 2: Building Windows app with production API..."
Write-Host "Command: flutter build windows --release --dart-define=API_BASE_URL=$railwayUrl"
flutter build windows --release --dart-define=API_BASE_URL=$railwayUrl

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Flutter build failed!" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host ""
Write-Host "Step 3: Build installer using Inno Setup"
Write-Host "Please:"
Write-Host "  1. Open Inno Setup Compiler"
Write-Host "  2. File -> Open -> setup.iss"
Write-Host "  3. Build -> Compile (F9)"
Write-Host ""
Write-Host "Installer will be created at: installer\company360-setup.exe"
Write-Host ""

Set-Location ".."

Write-Host "========================================"
Write-Host "Next Steps:"
Write-Host "========================================"
Write-Host "1. Create installer in Inno Setup (see above)"
Write-Host "2. Go to: https://github.com/Abinaya-Ramanathan/company360/releases"
Write-Host "3. Create new release:"
Write-Host "   - Tag: v1.0.0"
Write-Host "   - Upload: installer\company360-setup.exe"
Write-Host "   - Publish"
Write-Host ""
Write-Host "Your download link will be:"
Write-Host "https://github.com/Abinaya-Ramanathan/company360/releases/latest/download/company360-setup.exe"
Write-Host ""
Read-Host "Press Enter to exit"

