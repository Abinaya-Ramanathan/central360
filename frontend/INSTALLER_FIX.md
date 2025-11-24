# Fix for Missing DLL Error

## Problem
The error "permission_handler_windows_plugin.dll was not found" occurs when the installer doesn't include all required DLL files.

## Solution

### Step 1: Rebuild the Windows App
Make sure you have the latest build:
```batch
cd F:\central360\frontend
flutter clean
flutter build windows --release
```

### Step 2: Rebuild the Installer
The `setup.iss` file has been updated to ensure all DLL files are included. Now rebuild the installer:

**Option A - Using Inno Setup GUI:**
1. Open Inno Setup Compiler
2. File → Open → `F:\central360\frontend\setup.iss`
3. Build → Compile (F9)

**Option B - Using PowerShell Script:**
```powershell
cd F:\central360\frontend
powershell -ExecutionPolicy Bypass -File .\build-installer.ps1
```

### Step 3: Verify DLL Files
Before building the installer, verify these DLLs exist:
- `build\windows\x64\runner\Release\company360.exe`
- `build\windows\x64\runner\Release\flutter_windows.dll`
- `build\windows\x64\runner\Release\permission_handler_windows_plugin.dll`
- `build\windows\x64\runner\Release\printing_plugin.dll`
- `build\windows\x64\runner\Release\pdfium.dll`
- `build\windows\x64\runner\Release\file_selector_windows_plugin.dll`
- `build\windows\x64\runner\Release\data\*` (entire folder)

## What Was Fixed

The `setup.iss` file now includes:
1. ✅ All individual DLL files explicitly listed
2. ✅ Wildcard pattern to catch any additional DLLs: `*.dll`
3. ✅ Recursive pattern for DLLs in subdirectories: `*\*.dll`
4. ✅ Complete data folder with all assets

## After Rebuilding

The new installer at `installer\company360-setup.exe` will include all required files and the error should be resolved.

