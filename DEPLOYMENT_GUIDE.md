# Google Play Store Deployment Guide for Central360

## 📋 Prerequisites Checklist

Before starting, ensure you have:
- [ ] Google Play Console account ($25 one-time registration fee)
- [ ] App icon (512x512 PNG, no transparency)
- [ ] App screenshots (at least 2, up to 8 per device type)
- [ ] Feature graphic (1024x500 PNG)
- [ ] Keystore for signing the app
- [ ] App description (4000 characters max)
- [ ] Privacy policy URL (required)

## 🚀 Deployment Steps

### Step 1: Prepare Your App for Production

#### 1.1 Update App Version
Currently your app version is `0.1.0`. For Google Play, update it to follow semantic versioning.

#### 1.2 Configure App Signing
You need to create a keystore to sign your app.

#### 1.3 Update App Package Name
Change from `com.example.central360` to your unique package name (e.g., `com.yourcompany.central360`)

#### 1.4 Configure App Icon and Branding
Create proper app icons and branding assets.

#### 1.5 Set Up Production Backend
Ensure your backend API is production-ready and accessible.

---

## 📝 Detailed Step-by-Step Instructions

### STEP 1: Update pubspec.yaml

**Action Required**: Update version number and remove `publish_to: "none"`

```yaml
name: central360
description: Central360 - Business Management App
publish_to: 'none'  # Remove this line or set to null
version: 1.0.0+1    # Version format: major.minor.patch+build_number
```

The `+1` is the build number which should increment with each release.

---

### STEP 2: Configure App Package Name

**Action Required**: Change package name from `com.example.central360` to your unique package name.

**Why?**: Google Play requires a unique package name. `com.example.*` is reserved for testing.

**Recommended**: Use reverse domain notation like:
- `com.yourcompany.central360`
- `com.srisurya.central360`
- `in.co.companyname.central360`

**Files to Update**:
1. `android/app/src/main/AndroidManifest.xml`
2. `android/app/build.gradle` (applicationId)
3. All Kotlin/Java files referencing the package
4. API service base URL (if hardcoded)

---

### STEP 3: Create Signing Keystore

**Action Required**: Generate a keystore file for app signing.

**Why?**: Google Play requires signed apps. This keystore is critical - keep it safe!

**Steps**:
1. Open terminal in your `frontend/android` directory
2. Run:
   ```bash
   keytool -genkey -v -keystore central360-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias central360
   ```
3. Answer the prompts:
   - Password: (Remember this! You'll need it)
   - Name, Organization, etc.
4. Save the keystore file in a secure location (NOT in your repository!)

**IMPORTANT**: 
- ⚠️ Keep the keystore file safe - losing it means you can't update your app!
- ⚠️ Never commit the keystore to version control
- ⚠️ Back it up in multiple secure locations

---

### STEP 4: Configure Build Signing

**Action Required**: Configure Android build to use your keystore.

---

### STEP 5: Update App Configuration

**Action Required**: Configure app name, icon, and other metadata.

---

### STEP 6: Prepare Google Play Console Assets

**Action Required**: Create required assets for Play Store listing.

**Required Assets**:
1. **App Icon**: 512x512 PNG (no transparency, square, no rounded corners - Google adds those)
2. **Feature Graphic**: 1024x500 PNG (displayed at top of Play Store listing)
3. **Screenshots**: 
   - At least 2 screenshots
   - Phone: 16:9 or 9:16 aspect ratio, min 320px, max 3840px
   - Tablet: min 768px
4. **App Description**: 
   - Short description: 80 characters max
   - Full description: 4000 characters max
5. **Privacy Policy**: URL to your privacy policy (required)

---

### STEP 7: Build Release App Bundle (AAB)

**Action Required**: Build the Android App Bundle for upload.

Google Play prefers AAB format over APK for better optimization.

---

### STEP 8: Create Google Play Console Account

**Action Required**: Set up your Google Play Console account.

1. Go to [Google Play Console](https://play.google.com/console/)
2. Pay the $25 one-time registration fee
3. Complete your developer account profile

---

### STEP 9: Create App Listing in Play Console

**Action Required**: Create your app listing and fill in all required information.

---

### STEP 10: Upload and Submit Your App

**Action Required**: Upload your AAB file and submit for review.

---

## ⚠️ Important Notes

1. **Backend API URL**: Make sure your production backend is deployed and accessible
2. **API Key/Secrets**: Never hardcode API keys - use environment variables or secure storage
3. **Testing**: Thoroughly test the release build before submission
4. **Privacy Policy**: Required by Google - must be accessible via HTTPS URL
5. **App Review**: Google reviews can take 1-7 days

---

## 🔧 Next Steps

I'll help you complete each step. Let's start with Step 1 - preparing your app configuration.

Would you like me to:
1. Update the pubspec.yaml with proper versioning?
2. Change the package name (what would you like it to be)?
3. Create the keystore configuration files?
4. Update the app icon and branding?

Let me know your preferred package name and we'll proceed!

