# Manual Android Build Commands

## Quick Build (Using Script)
```powershell
cd F:\central360\frontend
.\build-android.ps1
```

## Manual Build Commands (Step by Step)

If you prefer to run commands manually:

```powershell
# 1. Navigate to frontend directory
cd F:\central360\frontend

# 2. Clean previous builds (optional but recommended)
flutter clean
flutter pub get

# 3. Build Android APK with Railway API URL
flutter build apk --release --dart-define=API_BASE_URL=https://central360-backend-production.up.railway.app

# 4. The APK will be created at:
#    build\app\outputs\flutter-apk\app-release.apk

# 5. Rename it for release (optional)
Copy-Item "build\app\outputs\flutter-apk\app-release.apk" "company360-v1.0.5.apk"
```

## What the Script Does

The `build-android.ps1` script:
1. Checks if Flutter is installed
2. Reads version from `pubspec.yaml` (currently 1.0.5+6)
3. Cleans previous builds
4. Runs `flutter build apk --release` with API URL
5. Shows the output location and suggested filename

## Output Location

After build completes:
- **APK File**: `F:\central360\frontend\build\app\outputs\flutter-apk\app-release.apk`
- **Suggested Name**: `company360-v1.0.5.apk` (rename before uploading to GitHub)

## Notes

- **Inno Setup** is only for Windows installers, not Android
- Android uses **Flutter build commands** directly
- The script automatically uses the Railway backend URL
- Build time: Usually 2-5 minutes depending on your system

