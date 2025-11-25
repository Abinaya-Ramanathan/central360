# Push Code and Build Installer - Step by Step

## Step 1: Push Code to GitHub

### 1.1 Add all changes
```powershell
git add .
```

### 1.2 Commit changes
```powershell
git commit -m "Add auto-update system and fix Railway URL connection"
```

### 1.3 Push to GitHub
```powershell
git push
```

**Note:** Railway will automatically deploy backend changes!

---

## Step 2: Build Windows App

### Option A: Quick Build (Recommended)
```powershell
cd frontend
flutter build windows --release
```

This automatically uses Railway URL in release builds!

### Option B: Using Build Script
```powershell
.\build-with-railway-url.ps1
```
Press Enter to use default Railway URL.

---

## Step 3: Create Installer

### 3.1 Open Inno Setup Compiler
- Open **Inno Setup Compiler** (if not installed, download from https://jrsoftware.org/isdl.php)

### 3.2 Open Setup Script
- **File** → **Open**
- Navigate to: `F:\central360\frontend\setup.iss`
- Click **Open**

### 3.3 Build Installer
- **Build** → **Compile** (or press **F9**)
- Wait for compilation to complete

### 3.4 Find Installer
- Installer will be at: `F:\central360\frontend\installer\Company360-Setup.exe`

---

## Step 4: Install the App

### 4.1 Run Installer
- Double-click `Company360-Setup.exe`
- Follow the installation wizard
- Choose installation location (default is fine)

### 4.2 Launch App
- After installation, launch **Company360** from Start Menu
- **Test login** - should connect to Railway automatically!

---

## Step 5: Verify It Works

1. **Open the app**
2. **Try to login** with your credentials
3. **Check connection:**
   - Should connect to Railway (no localhost error)
   - Should be able to login successfully

---

## Quick Commands Summary

```powershell
# 1. Push code
git add .
git commit -m "Add auto-update system and fix Railway URL connection"
git push

# 2. Build app
cd frontend
flutter build windows --release

# 3. Create installer in Inno Setup
# (Open setup.iss and compile)

# 4. Install and test!
```

---

## ✅ Expected Results

- ✅ Code pushed to GitHub
- ✅ Railway backend auto-deployed
- ✅ Windows app built with Railway URL
- ✅ Installer created
- ✅ App installed and connects to Railway automatically
- ✅ No localhost connection errors!

---

## 🆘 Troubleshooting

### If build fails:
- Make sure Flutter is in PATH: `flutter --version`
- Clean build: `flutter clean && flutter pub get`

### If installer fails:
- Check Inno Setup is installed
- Verify `setup.iss` path is correct

### If app doesn't connect:
- Check Railway is running: Visit https://central360-backend-production.up.railway.app/api/health
- Check app logs for connection URL

---

Ready to go! 🚀

