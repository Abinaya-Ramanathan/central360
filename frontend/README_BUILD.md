# 🚀 Quick Build Guide - Central360

## 📱💻 Build Both Android APK & Windows .exe

### **EASIEST METHOD: Use Build Script**

**Windows Command Prompt:**
```cmd
cd F:\central360\frontend
build-release.bat
```

**Windows PowerShell:**
```powershell
cd F:\central360\frontend
.\build-release.bat
```

**Note:** PowerShell requires `.\` prefix to run scripts in the current directory.

**What It Does:**
1. ✅ Cleans previous builds
2. ✅ Installs dependencies
3. ✅ Builds Android APK
4. ✅ Builds Windows .exe
5. ✅ Asks for production API URL

**Output Files:**
- Android APK: `build/app/outputs/flutter-apk/app-release.apk`
- Windows EXE: `build/windows/x64/runner/Release/central360.exe`

---

### **Manual Build (If Script Doesn't Work)**

**Build Android APK:**
```bash
cd frontend
flutter clean
flutter pub get
flutter build apk --release --dart-define=API_BASE_URL=https://your-production-api.com
```

**Build Windows .exe:**
```bash
cd frontend
flutter clean
flutter pub get
flutter build windows --release --dart-define=API_BASE_URL=https://your-production-api.com
```

---

## 📝 **Before Building**

1. **Update Production API URL**: 
   - Replace `https://your-production-api.com` with your actual backend URL
   - Example: `https://api.central360.com`

2. **Deploy Your Backend**:
   - Deploy backend to production server
   - Ensure it uses HTTPS (required for production)
   - Test API endpoints

3. **Build Files**:
   - Run build script
   - Get APK and .exe files
   - Test both versions

---

## 🌐 **Hosting Downloads**

1. Upload APK and .exe to your website
2. Update download links in `download-page.html`
3. Deploy HTML page
4. Share download link with users

---

## ✅ **Done!**

Users can now download and install your app on:
- ✅ Android Mobile (APK)
- ✅ Windows Laptop/Desktop (.exe)

**No store needed - just share download links!**

