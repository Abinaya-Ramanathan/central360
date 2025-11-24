# Company360 - Build Installer Guide

## ✅ Completed Steps

### 1. Icon Update
- ✅ Copied `c360-icon.ico` to `frontend\windows\runner\resources\app_icon.ico`
- ✅ Updated `Runner.rc` with correct Company360 branding
- ✅ Updated `setup.iss` to use the custom icon

### 2. Code Cleanup
- ✅ Fixed test file (company360 naming)
- ✅ Replaced all `print()` with `debugPrint()`
- ✅ Removed excessive debug statements
- ✅ Updated all branding from "central360" to "Company360"

### 3. Windows Build
- ✅ Built Windows release: `build\windows\x64\runner\Release\company360.exe`
- ✅ Icon is now embedded in the executable

## 📦 Create Installer

### Prerequisites

**Install Inno Setup 6** (required):
- Download from: https://jrsoftware.org/isdl.php
- Install to default location (usually `C:\Program Files (x86)\Inno Setup 6\`)

### Option 1: Using PowerShell Script (Recommended)

1. **Run the PowerShell script**:
   ```powershell
   cd F:\central360\frontend
   powershell -ExecutionPolicy Bypass -File .\build-installer.ps1
   ```

2. **The installer will be created at**:
   - `frontend\installer\company360-setup.exe`

### Option 2: Using Batch Script

1. **Run the batch script**:
   ```batch
   cd F:\central360\frontend
   build-installer.bat
   ```

2. **The installer will be created at**:
   - `frontend\installer\company360-setup.exe`

### Option 3: Manual Build

1. **Open Inno Setup Compiler**

2. **Load the script**:
   - File → Open
   - Navigate to: `F:\central360\frontend\setup.iss`

3. **Build the installer**:
   - Build → Compile (or press F9)

4. **Find the installer**:
   - Location: `F:\central360\frontend\installer\company360-setup.exe`

## 🎯 Icon Verification

After building, the app icon should appear:
- ✅ In Windows search results
- ✅ In the Start Menu
- ✅ On the desktop (if desktop icon is created)
- ✅ In the installer itself

## 📝 Notes

- The icon file is located at: `F:\central360\assets\brand\c360-icon.ico`
- The icon is embedded in the Windows executable
- The installer also uses this icon
- All branding has been updated to "Company360"

## 🔄 Next Steps

1. Test the installer on a clean Windows machine
2. Verify the icon appears correctly in search
3. Distribute the installer to users

---

**Last Updated**: After code cleanup and icon update
**Build Status**: ✅ Windows executable built successfully
**Installer Status**: Ready to build (requires Inno Setup)

