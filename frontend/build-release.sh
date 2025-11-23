#!/bin/bash
# Build Release Script for Central360
# Builds APK for Android and Windows executable

echo "🚀 Building Central360 Release Versions..."
echo ""

# Check if Flutter is installed
if ! command -v flutter &> /dev/null
then
    echo "❌ Flutter is not installed or not in PATH"
    exit 1
fi

# Get production API URL from user or use default
if [ -z "$API_BASE_URL" ]; then
    read -p "Enter Production API URL (or press Enter for localhost): " API_URL
    API_URL=${API_URL:-http://localhost:4000}
else
    API_URL=$API_BASE_URL
fi

echo "📡 Using API URL: $API_URL"
echo ""

# Clean previous builds
echo "🧹 Cleaning previous builds..."
flutter clean
flutter pub get

# Build Android APK
echo ""
echo "📱 Building Android APK..."
flutter build apk --release --dart-define=API_BASE_URL=$API_URL

if [ $? -eq 0 ]; then
    echo "✅ Android APK built successfully!"
    echo "📦 Location: build/app/outputs/flutter-apk/app-release.apk"
else
    echo "❌ Android APK build failed"
    exit 1
fi

# Build Windows executable
echo ""
echo "💻 Building Windows executable..."
flutter build windows --release --dart-define=API_BASE_URL=$API_URL

if [ $? -eq 0 ]; then
    echo "✅ Windows executable built successfully!"
    echo "📦 Location: build/windows/x64/runner/Release/"
else
    echo "❌ Windows build failed"
    exit 1
fi

echo ""
echo "🎉 Build completed successfully!"
echo ""
echo "📦 Output files:"
echo "  - Android APK: build/app/outputs/flutter-apk/app-release.apk"
echo "  - Windows EXE: build/windows/x64/runner/Release/central360.exe"
echo ""
echo "📝 Next steps:"
echo "  1. Upload APK to your website or Google Play Store"
echo "  2. Upload Windows executable to your website or create installer"
echo ""

