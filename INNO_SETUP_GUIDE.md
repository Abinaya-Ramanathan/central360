# Inno Setup Installation Guide

## Problem Fixed
The error `permission_handler_windows_plugin.dll was not found` occurs when the Inno Setup script doesn't include all required DLL files. The script at `frontend/setup.iss` now includes all necessary files.

## How to Use the Inno Setup Script

### Prerequisites
1. Download and install [Inno Setup](https://jrsoftware.org/isdl.php) (free)
2. Ensure your Windows build is complete in `frontend/build/windows/x64/runner/Release/`

### Steps to Create Installer

1. **Open Inno Setup Compiler**
   - Launch Inno Setup from Start Menu

2. **Open the Script**
   - File → Open
   - Navigate to: `F:\central360\frontend\setup.iss`
   - Click Open

3. **Build the Installer**
   - Build → Compile (or press F9)
   - The installer will be created in: `frontend/installer/central360-setup.exe`

4. **Test the Installer**
   - Run `central360-setup.exe` on a test machine
   - Verify the app launches without DLL errors

## What's Included in the Script

The script includes:
- ✅ `central360.exe` - Main executable
- ✅ `flutter_windows.dll` - Flutter runtime
- ✅ `pdfium.dll` - PDF rendering
- ✅ `printing_plugin.dll` - Printing functionality
- ✅ `permission_handler_windows_plugin.dll` - **This was missing!**
- ✅ `file_selector_windows_plugin.dll` - File selection
- ✅ `data/` folder - All app assets and resources
- ✅ Any other DLL files in the Release folder (wildcard pattern)

## Customization

You can customize the script by editing `setup.iss`:

- **App Name/Version**: Change `AppName` and `AppVersion`
- **Install Location**: Change `DefaultDirName`
- **Icon**: Add path to `SetupIconFile` (use a `.ico` file)
- **License**: Add path to `LicenseFile` (use a `.txt` file)

## Troubleshooting

### If DLL errors still occur:
1. Check that all DLL files exist in `build/windows/x64/runner/Release/`
2. Rebuild the Flutter app: `flutter build windows --release`
3. Verify the script paths are correct (relative to `frontend/` folder)

### If installer is too large:
- The script uses LZMA compression (already enabled)
- Total size should be ~23 MB (matches your Release folder)

## Quick Build Command

If you have Inno Setup command-line tools installed:
```powershell
cd F:\central360\frontend
"C:\Program Files (x86)\Inno Setup 6\ISCC.exe" setup.iss
```

This will create the installer without opening the GUI.

