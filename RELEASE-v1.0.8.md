# Company360 v1.0.8 Release Guide

## Version Information
- **Version**: 1.0.8
- **Build Number**: 9
- **Release Date**: December 1, 2025

## What's New in v1.0.8
- **Fixed**: Android APK installation prompt issue - installation dialog now appears automatically after download
- Added Sales and Credit Details functionality
- Renamed "Daily Report Details" to "Production and Expense Details"
- Added Attendance and Advance Details page
- Black background for Android app icon
- Code refactoring with utility functions
- Improved date handling and formatting

## Build Instructions

### Prerequisites
1. Flutter SDK installed and in PATH
2. Android SDK configured (for Android builds)
3. Inno Setup 5 or 6 installed (for Windows installer)

### Quick Build (All Platforms)

**PowerShell:**
```powershell
.\build-release-v1.0.8.ps1
```

**Command Prompt:**
```batch
build-release-v1.0.8.bat
```

### Build Options

**Build Windows only:**
```powershell
.\build-release-v1.0.8.ps1 -SkipAndroid
```

**Build Android only:**
```powershell
.\build-release-v1.0.8.ps1 -SkipWindows
```

**Build installer only (after Windows build):**
```powershell
.\build-installer-only.ps1
```

### Manual Build Steps

1. **Update version numbers** (already done):
   - `frontend/pubspec.yaml`: `version: 1.0.8+9`
   - `backend/src/routes/app.routes.js`: `version: '1.0.8'`, `buildNumber: '9'`
   - `frontend/setup.iss`: `AppVersion=1.0.8`

2. **Build Windows:**
   ```bash
   cd frontend
   flutter clean
   flutter pub get
   flutter build windows --release
   ```

3. **Build Android:**
   ```bash
   cd frontend
   flutter build apk --release
   # Copy APK
   copy build\app\outputs\flutter-apk\app-release.apk company360-v1.0.8.apk
   ```

4. **Build Windows Installer:**
   - Open Inno Setup Compiler
   - Open `frontend/setup.iss`
   - Click "Build" → "Compile"
   - Or use: `.\build-installer-only.ps1`

## Output Files

After building, you should have:

1. **Windows Executable:**
   - `frontend/build/windows/x64/runner/Release/company360.exe`

2. **Windows Installer:**
   - `frontend/installer/company360-setup.exe`

3. **Android APK:**
   - `frontend/company360-v1.0.8.apk`

## Release Checklist

- [x] Update version numbers in all files
- [x] Update release notes in `app.routes.js`
- [x] Update release date
- [ ] Build Windows release
- [ ] Build Android release
- [ ] Build Windows installer
- [ ] Test Windows installer
- [ ] Test Android APK (verify installation prompt appears)
- [ ] Create GitHub release tag: `v1.0.8`
- [ ] Upload `Company360-Setup.exe` to GitHub release
- [ ] Upload `company360-v1.0.8.apk` to GitHub release
- [ ] Update download URLs in `app.routes.js` (if needed)
- [ ] Push code to repository
- [ ] Deploy backend (if needed)

## GitHub Release

1. Go to: https://github.com/Abinaya-Ramanathan/central360/releases/new
2. Create new release:
   - **Tag**: `v1.0.8`
   - **Title**: `Company360 v1.0.8`
   - **Description**: Copy from release notes
3. Upload files:
   - `frontend/installer/company360-setup.exe` → Name: `Company360-Setup.exe`
   - `frontend/company360-v1.0.8.apk` → Name: `company360-v1.0.8.apk`
4. Publish release

## Notes

- The installer will be created in `frontend/installer/` directory
- APK will be copied to `frontend/` root directory
- Make sure to test both Windows and Android builds before releasing
- **Important**: Test Android APK installation to verify the installation prompt appears automatically
- Update download URLs in `app.routes.js` after uploading to GitHub

