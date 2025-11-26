# Android Release Steps - Central360 v1.0.2

## ✅ Build Completed Successfully!

**APK Details:**
- **File**: `central360-v1.0.2.apk`
- **Size**: 54.2 MB
- **Version**: 1.0.2+3
- **Location**: `frontend/central360-v1.0.2.apk`

## Next Steps to Complete Release

### 1. Test the APK (Recommended)
- Install the APK on an Android device
- Test all major features:
  - Login functionality
  - API connectivity
  - Notifications
  - PDF generation
  - All core features

### 2. Create GitHub Release

1. **Go to GitHub Releases:**
   - Navigate to: https://github.com/Abinaya-Ramanathan/central360/releases/new

2. **Create New Release:**
   - **Tag**: `v1.0.2` (or create new tag if needed)
   - **Title**: `Central360 v1.0.2 (Android)`
   - **Description**: 
     ```
     ## Android Release v1.0.2
     
     ### What's New
     - Fixed scrolling on all pages
     - Stock Management, Credit Details, and Maintenance pages now support full vertical and horizontal scrolling
     - Android app now available for download
     
     ### Installation
     - Download the APK file below
     - Enable "Install from Unknown Sources" on your Android device
     - Install the APK
     ```

3. **Upload APK:**
   - Upload: `central360-v1.0.2.apk`
   - The file is located at: `frontend/central360-v1.0.2.apk`

4. **Publish Release:**
   - Click "Publish release"

### 3. Update Backend Version Info

After the GitHub release is published, update the download URL in:
`backend/src/routes/app.routes.js`

**Update this line:**
```javascript
android: {
  downloadUrl: 'https://github.com/Abinaya-Ramanathan/central360/releases/download/v1.0.2/central360-v1.0.2.apk',
  isRequired: false,
}
```

**Note:** The URL format is:
`https://github.com/USERNAME/REPO/releases/download/TAG/FILENAME`

### 4. Commit and Push Changes

```bash
git add .
git commit -m "Release Android v1.0.2 Build 3"
git push
```

### 5. Deploy Backend (if needed)

If you updated the backend version info, deploy to Railway:
- The backend will automatically serve the new Android download URL
- Android users will see update notifications on next app launch

## APK Distribution Options

### Option 1: GitHub Releases (Recommended)
- ✅ Free hosting
- ✅ Version tracking
- ✅ Easy updates
- ✅ Direct download links

### Option 2: Google Play Store (Future)
- For production distribution
- Requires Google Play Developer account ($25 one-time fee)
- Better discoverability
- Automatic updates

### Option 3: Direct Hosting
- Host APK on your own server
- Update download URL in backend accordingly

## Testing Checklist

Before releasing, verify:
- [ ] APK installs successfully on Android device
- [ ] App launches without crashes
- [ ] Login works correctly
- [ ] API connectivity is working
- [ ] All screens load properly
- [ ] Notifications work (if applicable)
- [ ] PDF generation works
- [ ] No critical bugs

## Troubleshooting

### APK Installation Issues
- **"Install blocked"**: Enable "Install from Unknown Sources" in Android settings
- **"App not installed"**: Check if a previous version exists and uninstall it first
- **"Parse error"**: APK might be corrupted, rebuild

### Update Notifications
- Users will automatically see update dialog if:
  - Backend version is higher than installed version
  - Backend has correct download URL
  - App has internet connectivity

## Notes

- The APK is signed with debug keys (for development)
- For production, you should sign with a release keystore
- Current APK size: 54.2 MB (can be optimized with split APKs if needed)
- Version checking is automatic - users will be notified of updates

