# 🚀 Company360 Release Guide

Complete guide for releasing new versions of Company360 with auto-update notifications.

## 📋 Quick Release Checklist

- [ ] Update version in `pubspec.yaml`
- [ ] Build Windows app
- [ ] Create installer
- [ ] Update backend version endpoint
- [ ] Test installer
- [ ] Push code to GitHub
- [ ] Deploy backend to Railway
- [ ] Create GitHub Release
- [ ] Upload installer to GitHub Release

---

## 🔧 Step-by-Step Release Process

### Step 1: Build the App

#### Option A: Using PowerShell Script (Recommended)

```powershell
# Navigate to project root
cd F:\central360

# Run the build script
.\build-and-release.ps1
```

The script will:
- ✅ Ask for new version number
- ✅ Update `pubspec.yaml` automatically
- ✅ Build Windows app with Railway URL
- ✅ Create installer (if Inno Setup is installed)
- ✅ Show next steps

#### Option B: Manual Build

```powershell
cd frontend

# Update version in pubspec.yaml manually
# version: 1.0.2+3  (version.build)

# Clean and build
flutter clean
flutter pub get
flutter build windows --release --dart-define=API_BASE_URL=https://central360-backend-production.up.railway.app

# Create installer (if Inno Setup installed)
# Run: Inno Setup Compiler → Open setup.iss → Build
```

---

### Step 2: Update Backend Version Endpoint

Edit `backend/src/routes/app.routes.js`:

```javascript
router.get('/version', (_req, res) => {
  const versionInfo = {
    version: '1.0.2',  // ← Update this
    buildNumber: '3',   // ← Update this
    downloadUrl: 'https://github.com/YOUR_USERNAME/central360/releases/download/v1.0.2/Company360-Setup.exe',
    releaseNotes: 'Fixed scrolling on all pages - Stock Management, Credit Details, Maintenance',
    isRequired: false,  // Set to true for critical security updates
    releaseDate: '2025-11-25T00:00:00Z',
  };
  res.json(versionInfo);
});
```

**Important:** 
- Update `version` and `buildNumber` to match `pubspec.yaml`
- Update `downloadUrl` with correct GitHub release URL
- Write clear `releaseNotes` describing changes
- Set `isRequired: true` only for critical updates

---

### Step 3: Test the Installer

1. **Test on a clean machine** (or VM):
   - Install the new version
   - Verify app works correctly
   - Check scrolling on all pages
   - Test all features

2. **Test auto-update notification**:
   - Install old version (1.0.1)
   - Launch app
   - Should see update notification
   - Test download and install

---

### Step 4: Push Code to GitHub

```powershell
# Navigate to project root
cd F:\central360

# Stage all changes
git add .

# Commit with descriptive message
git commit -m "Release v1.0.2 Build 3 - Fixed scrolling on all pages"

# Push to GitHub
git push origin main
```

---

### Step 5: Deploy Backend to Railway

1. **Automatic Deployment** (if connected):
   - Railway auto-deploys on push to main branch
   - Check Railway dashboard for deployment status

2. **Manual Deployment** (if needed):
   - Go to Railway dashboard
   - Select your backend service
   - Click "Redeploy"

3. **Verify Deployment**:
   - Check Railway logs for errors
   - Test version endpoint:
     ```
     https://central360-backend-production.up.railway.app/api/v1/app/version
     ```

---

### Step 6: Create GitHub Release

1. **Go to GitHub Releases**:
   ```
   https://github.com/YOUR_USERNAME/central360/releases/new
   ```

2. **Fill Release Details**:
   - **Tag:** `v1.0.2` (must match version)
   - **Title:** `Company360 v1.0.2`
   - **Description:**
     ```markdown
     ## What's New in v1.0.2
     
     ### 🎯 Fixed Scrolling Issues
     - ✅ Fixed scrolling on Stock Management page (both tabs)
     - ✅ Fixed scrolling on Credit Details page
     - ✅ Fixed scrolling on Maintenance Issue page
     - ✅ All pages now support vertical and horizontal scrolling
     
     ### 📦 Installation
     Download and run `Company360-Setup.exe` to install or update.
     
     ### 🔄 Auto-Update
     Existing users will be notified automatically on next app launch.
     ```

3. **Upload Installer**:
   - Click "Attach binaries"
   - Select `Company360-Setup.exe` from `frontend/Output/`
   - Wait for upload to complete

4. **Publish Release**:
   - Click "Publish release"
   - Release is now live!

---

## 🔔 How Customers Get Notified

### Auto-Update Mechanism

1. **On App Launch:**
   - App checks `/api/v1/app/version` endpoint
   - Compares with current installed version
   - If new version available → Shows update dialog

2. **Update Dialog:**
   - Shows version number
   - Shows release notes
   - "Download" button → Downloads installer
   - "Later" button → Dismisses (if not required)
   - "Update Now" button → Downloads and installs (if required)

3. **Installation:**
   - Downloads installer to temp folder
   - Launches installer automatically
   - User completes installation
   - App restarts with new version

### Manual Notification (Optional)

If you want to notify customers manually:

1. **Email Notification:**
   ```
   Subject: Company360 Update Available - v1.0.2
   
   Hi,
   
   A new version of Company360 is available with important fixes:
   
   - Fixed scrolling on all pages
   - Improved user experience
   
   Download: [GitHub Release Link]
   
   Or update automatically: Launch the app and click "Update Now" when prompted.
   ```

2. **WhatsApp/Message:**
   ```
   📢 Company360 Update Available!
   
   Version 1.0.2 is now available with:
   ✅ Fixed scrolling issues
   ✅ Better user experience
   
   Update automatically by launching the app, or download from:
   [GitHub Release Link]
   ```

---

## 📝 Version Numbering

### Format: `MAJOR.MINOR.PATCH+BUILD`

- **MAJOR** (1.0.0): Breaking changes, major features
- **MINOR** (0.1.0): New features, backward compatible
- **PATCH** (0.0.1): Bug fixes, small improvements
- **BUILD** (+1): Build number, increments with each release

### Examples:
- `1.0.1+2` → `1.0.2+3` (Patch update)
- `1.0.2+3` → `1.1.0+4` (Minor update)
- `1.1.0+4` → `2.0.0+5` (Major update)

---

## 🐛 Troubleshooting

### Issue: Customers not seeing update notification

**Check:**
1. ✅ Backend version endpoint returns correct version
2. ✅ GitHub release is published
3. ✅ Download URL is correct and accessible
4. ✅ App version in `pubspec.yaml` matches backend

**Fix:**
```javascript
// Test version endpoint
curl https://central360-backend-production.up.railway.app/api/v1/app/version

// Should return:
{
  "version": "1.0.2",
  "buildNumber": "3",
  "downloadUrl": "https://github.com/.../Company360-Setup.exe",
  ...
}
```

### Issue: Installer download fails

**Check:**
1. ✅ GitHub release is public
2. ✅ Installer file is uploaded
3. ✅ Download URL is correct

**Fix:**
- Verify GitHub release is public
- Re-upload installer if needed
- Update download URL in backend

### Issue: App crashes after update

**Check:**
1. ✅ Test installer before release
2. ✅ Check Railway logs for backend errors
3. ✅ Verify API URL is correct

**Fix:**
- Rollback to previous version
- Fix issue
- Release new version

---

## 📊 Release History Template

Keep track of releases:

```markdown
## Release History

### v1.0.2 (2025-11-25)
- Fixed scrolling on all pages
- Improved user experience

### v1.0.1 (2025-11-20)
- Initial release
- Auto-update mechanism
```

---

## ✅ Quick Command Reference

```powershell
# Build and release
.\build-and-release.ps1

# Manual build
cd frontend
flutter build windows --release --dart-define=API_BASE_URL=https://central360-backend-production.up.railway.app

# Git commands
git add .
git commit -m "Release v1.0.2"
git push

# Test version endpoint
curl https://central360-backend-production.up.railway.app/api/v1/app/version
```

---

## 🎯 Summary

1. **Build:** Run `.\build-and-release.ps1`
2. **Update Backend:** Edit `app.routes.js`
3. **Test:** Test installer and app
4. **Push:** `git push`
5. **Deploy:** Railway auto-deploys
6. **Release:** Create GitHub release
7. **Done:** Customers notified automatically!

---

**Need Help?** Check `DEPLOYMENT.md` for detailed deployment instructions.

