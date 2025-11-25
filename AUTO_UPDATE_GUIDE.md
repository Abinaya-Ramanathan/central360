# Auto-Update System Guide

## 🎯 Overview

Your app now has an **automatic update notification system**! When you release a new version, users will be notified and can update without manually downloading a new installer.

## ✨ How It Works

1. **App checks for updates** when user logs in (after 2 seconds delay)
2. **Backend provides version info** via `/api/v1/app/version` endpoint
3. **User sees update dialog** if a newer version is available
4. **User can download and install** the update directly from the app

## 📋 Setup Instructions

### Step 1: Update Backend Environment Variables

When you release a new version, update these in Railway:

1. Go to **Railway Dashboard** → Your Backend Service → **Variables**
2. Add/Update these variables:

```env
APP_VERSION=1.0.1
APP_BUILD_NUMBER=2
APP_DOWNLOAD_URL=https://github.com/your-username/central360/releases/download/v1.0.1/Company360-Setup.exe
APP_RELEASE_NOTES=Fixed production save issue. Improved admin privileges.
APP_UPDATE_REQUIRED=false
APP_RELEASE_DATE=2025-11-25T00:00:00Z
```

**Or** update `backend/src/routes/app.routes.js` directly:

```javascript
const versionInfo = {
  version: '1.0.1',  // Update this
  buildNumber: '2',  // Update this
  downloadUrl: 'https://github.com/your-username/central360/releases/download/v1.0.1/Company360-Setup.exe',
  releaseNotes: 'Fixed production save issue. Improved admin privileges.',
  isRequired: false,  // Set to true for critical updates
  releaseDate: '2025-11-25T00:00:00Z',
};
```

### Step 2: Update Frontend Version

In `frontend/pubspec.yaml`:

```yaml
version: 1.0.1+2  # Match backend version and build number
```

### Step 3: Create GitHub Release

1. **Build the new installer:**
   ```powershell
   cd frontend
   flutter build windows
   # Then create installer using Inno Setup
   ```

2. **Create GitHub Release:**
   - Go to your GitHub repo → **Releases** → **Draft a new release**
   - Tag: `v1.0.1`
   - Title: `Version 1.0.1`
   - Description: Your release notes
   - **Upload** the installer `.exe` file
   - **Publish** the release

3. **Get Download URL:**
   - Right-click the uploaded `.exe` file → **Copy link address**
   - Use this URL in `APP_DOWNLOAD_URL`

### Step 4: Deploy Backend

```powershell
git add backend/src/routes/app.routes.js
git commit -m "Update app version to 1.0.1"
git push
```

Railway will auto-deploy the changes.

## 🔄 Update Flow

### For Users:

1. User opens the app and logs in
2. After 2 seconds, app checks for updates in background
3. If update available:
   - **Optional Update:** User sees dialog with "Later" and "Update Now" buttons
   - **Required Update:** User must update (can't dismiss dialog)
4. User clicks "Update Now"
5. App downloads installer (shows progress)
6. Installer launches automatically
7. User follows installation prompts
8. App restarts with new version

### For You (Developer):

1. Make code changes
2. Update version in `pubspec.yaml` and backend
3. Build new installer
4. Create GitHub release with installer
5. Update backend `APP_DOWNLOAD_URL`
6. Push to GitHub/Railway
7. Users will be notified on next app launch

## 🎛️ Configuration Options

### Optional vs Required Updates

- **Optional (`isRequired: false`):** User can click "Later" and continue using the app
- **Required (`isRequired: true`):** User must update - dialog can't be dismissed

### Update Check Timing

Currently checks **2 seconds after login**. To change:

Edit `frontend/lib/screens/home_screen.dart`:

```dart
Future.delayed(const Duration(seconds: 2), () {  // Change this delay
  _checkForUpdates();
});
```

### Manual Update Check

You can add a "Check for Updates" button in settings:

```dart
IconButton(
  icon: Icon(Icons.system_update),
  onPressed: _checkForUpdates,
  tooltip: 'Check for Updates',
)
```

## 📝 Version Format

- **Version:** Semantic versioning (e.g., `1.0.1`)
- **Build Number:** Incrementing integer (e.g., `1`, `2`, `3`)
- **Format:** `version+buildNumber` (e.g., `1.0.1+2`)

## 🔍 Testing

### Test Update Flow:

1. **Set test version in backend:**
   ```javascript
   version: '1.0.2',
   buildNumber: '999',
   ```

2. **Keep current app at:**
   ```yaml
   version: 1.0.1+1
   ```

3. **Launch app** - should see update dialog

4. **Test download** - should download installer

5. **Test install** - installer should launch

## ⚠️ Important Notes

1. **Download URL must be publicly accessible** (GitHub releases work great)
2. **Installer must be signed** (optional but recommended for Windows)
3. **Users need admin permission** to install (Windows will prompt)
4. **Update check is silent** - won't interrupt if backend is down
5. **Version comparison** uses build number first, then version string

## 🐛 Troubleshooting

### Update dialog not showing:
- Check backend `/api/v1/app/version` endpoint returns correct data
- Verify version/build number is actually newer
- Check app logs for errors

### Download fails:
- Verify `APP_DOWNLOAD_URL` is correct and accessible
- Check file size (large files may timeout)
- Ensure GitHub release is public

### Installer doesn't launch:
- Check Windows permissions
- Verify installer path is correct
- Check app logs for errors

## 📚 Files Modified

- ✅ `frontend/lib/services/update_service.dart` - Update checking logic
- ✅ `frontend/lib/screens/update_dialog.dart` - Update UI dialog
- ✅ `frontend/lib/screens/home_screen.dart` - Integrated update check
- ✅ `frontend/pubspec.yaml` - Added `package_info_plus` dependency
- ✅ `backend/src/routes/app.routes.js` - Version endpoint
- ✅ `backend/src/server.js` - Added app routes

## 🚀 Next Steps

1. **Install dependencies:**
   ```powershell
   cd frontend
   flutter pub get
   ```

2. **Test locally** (optional):
   - Set test version in backend
   - Launch app and verify update dialog

3. **Deploy:**
   ```powershell
   git add .
   git commit -m "Add auto-update system"
   git push
   ```

4. **For first release:**
   - Update version to `1.0.1+2` in `pubspec.yaml`
   - Update backend version endpoint
   - Build installer and create GitHub release
   - Update `APP_DOWNLOAD_URL` in Railway

Your users will now get automatic update notifications! 🎉

