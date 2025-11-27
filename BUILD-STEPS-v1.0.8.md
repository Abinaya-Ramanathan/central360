# Build Steps for Company360 v1.0.8

## Current Version
- **Version**: 1.0.8
- **Build Number**: 9

## Prerequisites
- Flutter SDK installed and in PATH
- Android SDK configured (for Android builds)
- Inno Setup 5 or 6 installed (for Windows installer)

---

## Option 1: Quick Build (Automated Script)

### Build Both Windows and Android:
```powershell
cd f:\central360
.\build-release-v1.0.7.ps1
```
*(Note: Script name is v1.0.7 but it will build with current version from pubspec.yaml)*

### Build Windows Only:
```powershell
cd f:\central360
.\build-release-v1.0.7.ps1 -SkipAndroid
```

### Build Android Only:
```powershell
cd f:\central360
.\build-release-v1.0.7.ps1 -SkipWindows
```

---

## Option 2: Manual Build Steps

### Step 1: Navigate to Frontend Directory
```bash
cd f:\central360\frontend
```

### Step 2: Clean Previous Builds
```bash
flutter clean
```

### Step 3: Get Dependencies
```bash
flutter pub get
```

### Step 4: Build Windows Release
```bash
flutter build windows --release
```

**Output Location:**
- `frontend/build/windows/x64/runner/Release/company360.exe`

### Step 5: Build Android APK
```bash
flutter build apk --release
```

**Output Location:**
- `frontend/build/app/outputs/flutter-apk/app-release.apk`

**Copy APK with version name:**
```bash
copy build\app\outputs\flutter-apk\app-release.apk company360-v1.0.8.apk
```

### Step 6: Build Windows Installer (Optional)

**Using Script:**
```powershell
cd f:\central360
.\build-installer-only.ps1
```

**Or Manually:**
1. Open Inno Setup Compiler
2. Open `frontend/setup.iss`
3. Click "Build" → "Compile"

**Output Location:**
- `frontend/installer/company360-setup.exe`

---

## Complete Build Sequence (One Command)

### PowerShell:
```powershell
cd f:\central360\frontend; flutter clean; flutter pub get; flutter build windows --release; flutter build apk --release; copy build\app\outputs\flutter-apk\app-release.apk company360-v1.0.8.apk
```

### Command Prompt:
```batch
cd f:\central360\frontend && flutter clean && flutter pub get && flutter build windows --release && flutter build apk --release && copy build\app\outputs\flutter-apk\app-release.apk company360-v1.0.8.apk
```

---

## Expected Output Files

After successful build, you should have:

1. **Windows Executable:**
   - `frontend/build/windows/x64/runner/Release/company360.exe`
   - All required DLLs in the same directory

2. **Windows Installer:**
   - `frontend/installer/company360-setup.exe` (after building installer)

3. **Android APK:**
   - `frontend/company360-v1.0.8.apk`

---

## Troubleshooting

### If Android build fails:
1. Check Android SDK is properly configured:
   ```bash
   flutter doctor
   ```
2. Clean and rebuild:
   ```bash
   flutter clean
   flutter pub get
   flutter build apk --release
   ```

### If Windows build fails:
1. Ensure you're on Windows OS
2. Check Flutter Windows support:
   ```bash
   flutter doctor
   ```
3. Clean and rebuild:
   ```bash
   flutter clean
   flutter pub get
   flutter build windows --release
   ```

### If Installer build fails:
1. Check Inno Setup is installed
2. Verify `frontend/setup.iss` exists
3. Ensure Windows build completed successfully first

---

## Build Time Estimates

- **Windows Build**: ~3-5 minutes
- **Android Build**: ~5-10 minutes
- **Installer Build**: ~1-2 minutes

**Total**: ~10-17 minutes for complete build

---

## Next Steps After Build

1. ✅ Test Windows executable
2. ✅ Test Android APK (verify installation prompt appears)
3. ✅ Test Windows installer
4. Create GitHub release tag: `v1.0.8`
5. Upload files to GitHub release
6. Push code to repository

