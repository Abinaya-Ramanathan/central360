# Permissions Guide for Central360 App

## 1. PDF Download Permissions

### Current Implementation
The app uses the `printing` package (`Printing.layoutPdf()`) which handles file saving automatically. However, platform-specific permissions may still be required.

### Platform-Specific Requirements

#### **Windows (Desktop)**
- ✅ **No special permissions needed** - The printing package uses the system file picker/save dialog
- ✅ Users can save PDFs to any location they choose through the system dialog
- ✅ Works immediately without additional configuration

#### **Android**
- ⚠️ **Permissions MAY be required** depending on Android version:
  - **Android 9 and below**: May need `WRITE_EXTERNAL_STORAGE` permission
  - **Android 10+**: The `printing` package handles scoped storage automatically
  - **Android 11+**: Uses Storage Access Framework (SAF) - no permission needed

**Recommendation**: Add Android permissions to be safe (will be requested only if needed)

#### **iOS**
- ✅ **No permissions needed** - Uses system share dialog
- ✅ Works automatically

#### **Web**
- ✅ **No permissions needed** - Browser handles download
- ✅ PDF downloads directly to browser's default download folder

---

## 2. Notification Permissions

### Platform Requirements

#### **Android**
- ✅ **Permission REQUIRED** for Android 13+ (API 33+)
- ✅ **Permission REQUIRED** for Android 8.0+ (API 26+) for notification channels
- ⚠️ Must be requested at runtime

#### **iOS**
- ✅ **Permission REQUIRED**
- ✅ Must request permission from user
- ✅ Shows system permission dialog

#### **Windows**
- ✅ **Generally no permission needed** for basic notifications
- ⚠️ User may need to allow notifications in Windows Settings (Settings > System > Notifications)

#### **Web**
- ✅ **Permission REQUIRED**
- ✅ Browser prompts user for permission

---

## Implementation Status

### ✅ PDF Download Permissions
- **Android**: Permissions added to `AndroidManifest.xml` for Android 10 and below
- **iOS**: File sharing permissions added to `Info.plist`
- **Windows**: No additional permissions needed

### ✅ Notification System
- **Packages Installed**: 
  - `flutter_local_notifications` (^17.2.3)
  - `permission_handler` (^11.3.1)
  - `timezone` (^0.9.2)
  - `workmanager` (^0.5.2)

- **Android Permissions**: Added to `AndroidManifest.xml`
  - `POST_NOTIFICATIONS` (Android 13+)
  - `RECEIVE_BOOT_COMPLETED` (for scheduled notifications)
  - `VIBRATE` (for notification vibration)
  
- **iOS Permissions**: Added to `Info.plist`
  - `UIBackgroundModes` with `remote-notification` and `processing`
  - `NSUserNotificationsUsageDescription` for permission request message

- **Notification Features**:
  - ✅ Automatic permission request on app startup
  - ✅ Vehicle permit expiry check (2 days before expiry)
  - ✅ Periodic checks every 6 hours
  - ✅ Immediate check when vehicle licenses are loaded/updated
  - ✅ Duplicate notification prevention
  - ✅ Notification channel configured for Android

### How It Works

1. **On App Startup**: 
   - Notification service initializes
   - Permission is requested (Android 13+, iOS)
   - Expiry notification service starts checking every 6 hours

2. **Vehicle Permit Expiry Checks**:
   - Checks all vehicle licenses for permit dates expiring in 0-2 days
   - Sends notification with vehicle name, registration number, and days until expiry
   - Prevents duplicate notifications for the same vehicle/date combination

3. **When Vehicle License Updated**:
   - Automatically checks expiries after saving/updating
   - Re-evaluates all permits and sends notifications if needed

