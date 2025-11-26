# Quick Release Script - Minimal prompts
# Use this for faster releases when you know the version

param(
    [Parameter(Mandatory=$true)]
    [string]$Version,
    
    [Parameter(Mandatory=$false)]
    [string]$BuildNumber = "",
    
    [string]$API_URL = "https://central360-backend-production.up.railway.app"
)

$ErrorActionPreference = "Stop"

Write-Host "🚀 Quick Release: v$Version" -ForegroundColor Cyan
Write-Host ""

# Navigate to frontend
$frontendPath = Join-Path $PSScriptRoot "frontend"
Set-Location $frontendPath

# Get build number
if ([string]::IsNullOrEmpty($BuildNumber)) {
    $pubspecContent = Get-Content "pubspec.yaml" -Raw
    if ($pubspecContent -match '\+(\d+)') {
        $currentBuild = [int]$matches[1]
        $BuildNumber = $currentBuild + 1
    } else {
        $BuildNumber = "1"
    }
}

Write-Host "📦 Version: $Version+$BuildNumber" -ForegroundColor Yellow
Write-Host ""

# Update pubspec.yaml
$pubspecContent = Get-Content "pubspec.yaml" -Raw
$pubspecContent = $pubspecContent -replace 'version:\s*\d+\.\d+\.\d+\+\d+', "version: $Version+$BuildNumber"
Set-Content -Path "pubspec.yaml" -Value $pubspecContent -NoNewline

# Build
Write-Host "💻 Building..." -ForegroundColor Yellow
flutter clean | Out-Null
flutter pub get | Out-Null
flutter build windows --release --dart-define=API_BASE_URL=$API_URL

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Build failed" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "✅ Build complete!" -ForegroundColor Green
Write-Host ""
Write-Host "📝 Next:" -ForegroundColor Cyan
Write-Host "   1. Update backend/src/routes/app.routes.js" -ForegroundColor White
Write-Host "   2. Create installer (if Inno Setup installed)" -ForegroundColor White
Write-Host "   3. git add . && git commit -m 'Release v$Version' && git push" -ForegroundColor White
Write-Host "   4. Create GitHub release: v$Version" -ForegroundColor White
Write-Host ""

