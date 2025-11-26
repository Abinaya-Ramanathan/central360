# Install Inno Setup for Windows Installer

## Download and Install

1. **Download Inno Setup 6:**
   - Visit: https://jrsoftware.org/isdl.php
   - Download the latest version (Inno Setup 6.x)
   - File will be something like: `innosetup-6.x.x.exe`

2. **Install:**
   - Run the installer
   - Use default installation path (usually `C:\Program Files (x86)\Inno Setup 6\`)
   - Complete the installation

3. **Verify Installation:**
   ```powershell
   Test-Path "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
   ```
   Should return `True`

4. **Build Installer:**
   ```powershell
   cd F:\central360\frontend
   .\build-installer.ps1
   ```

## Alternative: Build Windows App Without Installer

If you just need the Windows app for testing (without installer):

```powershell
cd F:\central360\frontend
flutter build windows --release --dart-define=API_BASE_URL=https://central360-backend-production.up.railway.app
```

The executable will be at:
`build\windows\x64\runner\Release\company360.exe`

