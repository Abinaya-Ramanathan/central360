# Rebuild Installer - DLL Files Missing Fix

## Problem
After installing, the app shows errors for missing DLL files:
- `flutter_windows.dll`
- `printing_plugin.dll`
- `permission_handler_windows_plugin.dll`
- `file_selector_windows_plugin.dll`

## Solution: Rebuild the Installer

The `setup.iss` file has been updated to include all DLL files. You need to rebuild the installer.

### Step 1: Verify Build Files Exist
All DLL files should exist in: `F:\central360\frontend\build\windows\x64\runner\Release\`

✅ Verified DLLs:
- `company360.exe`
- `flutter_windows.dll` (18.5 MB)
- `pdfium.dll` (4.7 MB)
- `printing_plugin.dll` (135 KB)
- `permission_handler_windows_plugin.dll` (112 KB)
- `file_selector_windows_plugin.dll` (104 KB)

### Step 2: Rebuild the Installer

**Option A - Using Inno Setup GUI (Recommended):**
1. Open **Inno Setup Compiler**
2. **File → Open** → Navigate to `F:\central360\frontend\setup.iss`
3. **Build → Compile** (or press **F9**)
4. Wait for compilation to complete
5. Check for any errors in the compiler output

**Option B - Using PowerShell Script:**
```powershell
cd F:\central360\frontend
powershell -ExecutionPolicy Bypass -File .\build-installer.ps1
```

### Step 3: Install the New Installer

1. **Uninstall the old version** (if installed):
   - Control Panel → Programs → Uninstall Company360

2. **Run the new installer**:
   - Location: `F:\central360\frontend\installer\company360-setup.exe`
   - Run as Administrator

3. **Test the installation**:
   - Launch Company360
   - All DLL errors should be resolved

## What's Fixed in setup.iss

✅ All DLL files explicitly listed:
- `flutter_windows.dll`
- `pdfium.dll`
- `printing_plugin.dll`
- `permission_handler_windows_plugin.dll`
- `file_selector_windows_plugin.dll`

✅ Wildcard pattern to catch any additional DLLs:
- `Source: "build\windows\x64\runner\Release\*.dll"`

✅ Complete data folder included:
- `Source: "build\windows\x64\runner\Release\data\*"`

## Important Notes

- The installer must be rebuilt after any changes to `setup.iss`
- Make sure the Windows build is up to date: `flutter build windows --release`
- All DLL files must exist in the Release folder before building the installer
- The new installer will include all required files

