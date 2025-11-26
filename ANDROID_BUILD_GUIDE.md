# Android Build Guide for Central360

This guide explains how to build and release the Android version of Central360.

## Prerequisites

1. **Flutter SDK** (3.0+)
   - Install from: https://flutter.dev/docs/get-started/install
   - Make sure Flutter is in your PATH

2. **Android Studio** (recommended)
   - Install Android SDK and build tools
   - Set up Android emulator or connect a physical device for testing

3. **Java Development Kit (JDK)**
   - JDK 17 or later is required
   - The project is configured to use Java 17

## Building Android APK

### Option 1: Using PowerShell Script (Windows)

```powershell
cd frontend
.\build-android.ps1
```

The script will:
- Check for Flutter installation
- Prompt for API URL (defaults to Railway production URL)
- Clean previous builds
- Build release APK
- Show the APK location and next steps

### Option 2: Using Bash Script (Linux/Mac)

```bash
cd frontend
chmod +x build-android.sh
./build-android.sh
```

### Option 3: Manual Build

```bash
cd frontend
flutter clean
flutter pub get
flutter build apk --release --dart-define=API_BASE_URL=https://central360-backend-production.up.railway.app
```

The APK will be located at:
```
frontend/build/app/outputs/flutter-apk/app-release.apk
```

## APK Output

After building, the APK will be at:
- **Location**: `frontend/build/app/outputs/flutter-apk/app-release.apk`
- **Suggested filename for release**: `central360-v1.0.2.apk` (replace with actual version)

## Release Process

1. **Test the APK**
   - Install on a physical Android device
   - Test all major features
   - Verify API connectivity

2. **Update Backend Version Info**
   - Edit `backend/src/routes/app.routes.js`
   - Update the `android.downloadUrl` with the GitHub release URL
   - Example:
     ```javascript
     android: {
       downloadUrl: 'https://github.com/Abinaya-Ramanathan/central360/releases/download/v1.0.2/central360-v1.0.2.apk',
       isRequired: false,
     }
     ```

3. **Commit and Push**
   ```bash
   git add .
   git commit -m "Release Android v1.0.2 Build 3"
   git push
   ```

4. **Create GitHub Release**
   - Go to: https://github.com/Abinaya-Ramanathan/central360/releases/new
   - Tag: `v1.0.2` (match your version)
   - Title: `Central360 v1.0.2 (Android)`
   - Description: Add release notes
   - Upload: `central360-v1.0.2.apk`

5. **Deploy Backend** (if version changed)
   - Deploy updated backend to Railway
   - The app will automatically check for updates on next launch

## Android App Configuration

### App Details
- **Package Name**: `com.example.central360`
- **App Name**: Central360
- **Min SDK**: Defined by Flutter (typically Android 5.0+)
- **Target SDK**: Latest Android version

### Permissions
The app requires the following permissions (already configured in `AndroidManifest.xml`):
- Internet access
- Network state access
- Storage access (for PDF downloads on Android 10 and below)
- Notifications (Android 13+)
- Boot completed (for scheduled notifications)
- Vibrate (for notifications)

### Update Mechanism
- The app automatically checks for updates on launch
- Update information is fetched from: `/api/v1/app/version`
- Platform-specific download URLs are supported
- Android users will see update dialog if a new version is available
- APK is downloaded and can be installed manually

## Building App Bundle (AAB) for Google Play Store

If you want to publish to Google Play Store, build an App Bundle instead:

```bash
flutter build appbundle --release --dart-define=API_BASE_URL=https://central360-backend-production.up.railway.app
```

The AAB will be at:
```
frontend/build/app/outputs/bundle/release/app-release.aab
```

## Troubleshooting

### Build Fails
- Ensure Flutter is up to date: `flutter upgrade`
- Clean build: `flutter clean && flutter pub get`
- Check Android SDK is properly installed
- Verify Java JDK 17+ is installed

### APK Too Large
- The release APK is typically 20-50 MB
- To reduce size, consider building split APKs:
  ```bash
  flutter build apk --split-per-abi --release
  ```
  This creates separate APKs for different CPU architectures

### Update Check Not Working
- Verify backend is deployed and accessible
- Check API URL in app configuration
- Ensure version endpoint returns correct platform-specific URLs

## Notes

- The Android app uses the same codebase as Windows
- Platform-specific features are handled automatically by Flutter
- Update service detects platform and uses appropriate download URL
- Android installation requires user to manually install the APK after download

