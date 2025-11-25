# Production URL Fix - Automatic Railway Connection

## ✅ Problem Solved

The app was trying to connect to `localhost:4000` in production builds, causing connection errors. This is now fixed!

## 🔧 Changes Made

### 1. **Updated Default API URL** (`frontend/lib/config/env_config.dart`)
   - **Production builds** (release mode): Automatically use Railway URL
   - **Development builds** (debug mode): Use localhost
   - **Priority order:**
     1. Config file (if exists)
     2. Environment variable (`--dart-define=API_BASE_URL=...`)
     3. **Default: Railway URL for release, localhost for debug**

### 2. **Updated Build Scripts**
   - `build-with-railway-url.ps1` - Uses Railway URL as default
   - `frontend/build-installer.ps1` - Automatically includes Railway URL
   - `frontend/build-release.bat` - Uses Railway URL as default

## 🚀 How It Works Now

### For Production Builds (Release Mode):
```dart
// Automatically uses: https://central360-backend-production.up.railway.app
```

### For Development Builds (Debug Mode):
```dart
// Automatically uses: http://localhost:4000
```

### Build Commands:

**Option 1: Use default Railway URL (Recommended)**
```powershell
cd frontend
flutter build windows --release
# Automatically uses Railway URL in release builds
```

**Option 2: Override with custom URL**
```powershell
flutter build windows --release --dart-define=API_BASE_URL=https://your-custom-url.com
```

**Option 3: Use build script**
```powershell
.\build-with-railway-url.ps1
# Press Enter to use default Railway URL
```

## 📋 Next Release Steps

1. **Build the installer:**
   ```powershell
   cd frontend
   flutter build windows --release
   # Railway URL is automatically included!
   ```

2. **Create installer** (Inno Setup):
   - Open `setup.iss` in Inno Setup
   - Build → Compile

3. **Test the installer:**
   - Install on a clean machine
   - App should connect to Railway automatically
   - No config file needed!

## ✅ Benefits

- ✅ **No user configuration needed** - works out of the box
- ✅ **Automatic Railway connection** in production builds
- ✅ **Still supports localhost** for development
- ✅ **Config file override** still works if needed
- ✅ **Environment variable override** still works if needed

## 🔍 Verification

After building, check the app logs on startup:
- Should see: `Using production default (Railway): https://central360-backend-production.up.railway.app`
- Or: `Config loaded from environment: https://...`

## 📝 Railway URL

Current production URL:
```
https://central360-backend-production.up.railway.app
```

If your Railway URL changes, update:
1. `frontend/lib/config/env_config.dart` - `_productionBaseUrl` constant
2. Build scripts (optional - they'll use the code default)

## 🎉 Result

**Next release will work automatically!** Users don't need to:
- Create config files
- Set environment variables
- Do any manual configuration

The app will connect to Railway immediately after installation! 🚀

