#!/bin/bash
# Build Android APK Script for Central360
# Builds release APK for Android

set -e

echo "========================================"
echo "Central360 Android Build Script"
echo "========================================"
echo ""

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "[ERROR] Flutter is not installed or not in PATH"
    echo "Please install Flutter from: https://flutter.dev/docs/get-started/install"
    exit 1
fi

FLUTTER_VERSION=$(flutter --version 2>&1 | head -n 1)
echo "[OK] Flutter found: $FLUTTER_VERSION"

# Navigate to frontend directory
# Script is located in frontend/build-android.sh, so script dir is the frontend directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
FRONTEND_PATH="$SCRIPT_DIR"

# Verify we're in the right place by checking for pubspec.yaml
if [ ! -f "$FRONTEND_PATH/pubspec.yaml" ]; then
    echo "[ERROR] pubspec.yaml not found in: $FRONTEND_PATH"
    echo "Please ensure this script is in the frontend directory."
    exit 1
fi

cd "$FRONTEND_PATH"

# Get API URL
DEFAULT_RAILWAY_URL="https://central360-backend-production.up.railway.app"

if [ -z "$API_BASE_URL" ]; then
    read -p "Enter Railway API URL (press Enter for default: $DEFAULT_RAILWAY_URL): " API_URL
    API_URL=${API_URL:-$DEFAULT_RAILWAY_URL}
else
    API_URL=$API_BASE_URL
fi

# Remove /api/v1 if included
API_URL=${API_URL%/api/v1}

echo ""
echo "[INFO] Using API URL: $API_URL"
echo "[INFO] Full API URL will be: $API_URL/api/v1"
echo ""

# Read version from pubspec.yaml
if [ -f "pubspec.yaml" ]; then
    if [[ $(grep -oP 'version:\s*\K[\d.]+' pubspec.yaml) ]]; then
        VERSION=$(grep -oP 'version:\s*\K[\d.]+' pubspec.yaml | head -c -2)
        BUILD_NUMBER=$(grep -oP 'version:.*\+\K\d+' pubspec.yaml)
        echo "[INFO] Building version: $VERSION+$BUILD_NUMBER"
    else
        echo "[WARN] Could not parse version from pubspec.yaml"
        VERSION="1.0.0"
        BUILD_NUMBER="1"
    fi
else
    echo "[WARN] pubspec.yaml not found"
    VERSION="1.0.0"
    BUILD_NUMBER="1"
fi

echo ""

# Clean previous builds
if [ "$1" != "--skip-clean" ]; then
    echo "[INFO] Cleaning previous builds..."
    flutter clean
    flutter pub get
else
    echo "[INFO] Skipping clean (using --skip-clean)"
    flutter pub get
fi

# Build Android APK
echo ""
echo "[INFO] Building Android APK (Release)..."
echo "   This may take a few minutes..."
echo ""

flutter build apk --release --dart-define=API_BASE_URL=$API_URL

if [ $? -eq 0 ]; then
    echo ""
    echo "[OK] Android APK built successfully!"
    echo ""
    
    # Get APK path
    APK_PATH="$FRONTEND_PATH/build/app/outputs/flutter-apk/app-release.apk"
    
    if [ -f "$APK_PATH" ]; then
        APK_SIZE=$(du -h "$APK_PATH" | cut -f1)
        
        echo "================================================================"
        echo "Build Complete!"
        echo "================================================================"
        echo ""
        echo "[INFO] Version: $VERSION+$BUILD_NUMBER"
        echo "[INFO] APK Location: $APK_PATH"
        echo "[INFO] APK Size: $APK_SIZE"
        echo ""
        
        # Suggest rename
        SUGGESTED_NAME="company360-v$VERSION.apk"
        echo "Suggested filename for release: $SUGGESTED_NAME"
        echo ""
        
        echo "Next Steps:"
        echo "   1. Test the APK on an Android device"
        echo "   2. Update backend version in: backend/src/routes/app.routes.js"
        echo "      - Update android.downloadUrl with GitHub release URL"
        echo "   3. Push code to GitHub:"
        echo "      git add ."
        echo "      git commit -m \"Release Android v$VERSION Build $BUILD_NUMBER\""
        echo "      git push"
        echo ""
        echo "   4. Create GitHub Release:"
        echo "      - Go to: https://github.com/Abinaya-Ramanathan/central360/releases/new"
        echo "      - Tag: v$VERSION"
        echo "      - Title: Central360 v$VERSION (Android)"
        echo "      - Upload: $SUGGESTED_NAME"
        echo ""
        echo "   5. Update download URL in app.routes.js after release"
        echo ""
    else
        echo "[WARN] APK file not found at expected location: $APK_PATH"
    fi
else
    echo "[ERROR] Android APK build failed"
    exit 1
fi

