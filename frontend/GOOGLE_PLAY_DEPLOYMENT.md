# Google Play Store Deployment Guide

## 🚀 Step-by-Step Deployment Process

### **STEP 1: Update App Information** ✅ (Partially Done)

I've already updated:
- ✅ Created environment configuration for production API URLs
- ✅ Updated API service to use configurable base URL
- ✅ Updated PDF generator email service to use configurable URL
- ✅ Updated pubspec.yaml with proper version (1.0.0+1)

**Action Required**: You need to decide on your package name. Currently it's `com.example.central360`. 

**❓ What package name would you like to use?**

Examples:
- `com.srisurya.central360`
- `in.co.companyname.central360`
- `com.yourcompany.central360`

**⚠️ Important**: Once you publish to Google Play, you CANNOT change the package name!

---

### **STEP 2: Update Package Name** ⏳ (Waiting for your decision)

**Files that need to be updated:**
1. `android/app/src/main/AndroidManifest.xml` - Change `package="com.example.central360"`
2. `android/app/build.gradle` - Change `applicationId`
3. Folder structure: `android/app/src/main/java/com/example/central360/` → new package structure

**After you provide the package name, I'll update all these files for you.**

---

### **STEP 3: Create Signing Keystore** 📝 (You need to do this)

**⚠️ CRITICAL**: This keystore file is essential. If you lose it, you won't be able to update your app on Google Play!

**Steps:**

1. **Open Command Prompt or Terminal** in your `frontend/android` directory

2. **Run this command**:
   ```bash
   keytool -genkey -v -keystore central360-release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias central360
   ```

3. **Enter the information when prompted**:
   - **Keystore password**: (Remember this! Write it down securely)
   - **Re-enter password**: (Type it again)
   - **Name**: Your name or organization name
   - **Organizational Unit**: (e.g., IT Department)
   - **Organization**: Your company name
   - **City**: Your city
   - **State/Province**: Your state
   - **Country Code**: (e.g., IN for India, US for United States - two letters)
   - **Confirm**: Type 'yes'
   - **Key password**: (Press Enter to use same as keystore password)

4. **Save the keystore file securely**:
   - File created: `central360-release-key.jks` in `frontend/android/` directory
   - **Back it up** to multiple secure locations (cloud storage, USB drive, etc.)
   - **Never commit it to Git!**

5. **Create `key.properties` file** in `frontend/android/` directory:
   ```
   storePassword=YOUR_KEYSTORE_PASSWORD
   keyPassword=YOUR_KEY_PASSWORD
   keyAlias=central360
   storeFile=central360-release-key.jks
   ```
   Replace `YOUR_KEYSTORE_PASSWORD` and `YOUR_KEY_PASSWORD` with the passwords you entered.

**⚠️ Keep these credentials secure!** Without them, you cannot update your app.

---

### **STEP 4: Configure Android Build for Signing** ⏳

**Waiting for**: You to complete Step 3, then I'll configure the build files for you.

I'll create/update:
- `android/app/build.gradle` - Configure signing config
- `.gitignore` - Ensure keystore files are NOT committed

---

### **STEP 5: Update Production API URL** 📝

**Current**: Using localhost (http://localhost:4000)

**Action Required**: You need to:
1. Deploy your backend to a production server (AWS, Heroku, DigitalOcean, etc.)
2. Get your production API URL (e.g., `https://api.central360.com`)
3. Update the environment configuration

**I've already set up the configuration system. You'll need to:**
- Build the app with: `flutter build appbundle --dart-define=API_BASE_URL=https://your-production-api.com`
- Or update the default in `lib/config/env_config.dart`

---

### **STEP 6: Create App Assets for Play Store** 📝

**Required Assets:**

1. **App Icon**:
   - Size: 512x512 pixels
   - Format: PNG (32-bit)
   - Background: No transparency (use solid background)
   - Location: Replace `android/app/src/main/res/mipmap-*/ic_launcher.png`

2. **Feature Graphic**:
   - Size: 1024x500 pixels
   - Format: PNG or JPG
   - This appears at the top of your Play Store listing

3. **Screenshots** (At least 2, up to 8):
   - Phone screenshots: 16:9 or 9:16 aspect ratio
   - Tablet screenshots: Min 768px width
   - Formats: PNG or JPG

4. **App Description**:
   - Short description: 80 characters max
   - Full description: 4000 characters max
   - What your app does, features, etc.

5. **Privacy Policy URL**:
   - Required by Google
   - Must be accessible via HTTPS
   - Must explain what data you collect and how you use it

**I can help you create the description once we know more about your app's features.**

---

### **STEP 7: Build Release App Bundle (AAB)** ⏳

**After completing Steps 1-5**, I'll help you build the release bundle:

```bash
cd frontend
flutter clean
flutter pub get
flutter build appbundle --release --dart-define=API_BASE_URL=https://your-production-api.com
```

This will create: `build/app/outputs/bundle/release/app-release.aab`

---

### **STEP 8: Set Up Google Play Console** 📝

**Steps:**
1. Go to [Google Play Console](https://play.google.com/console/)
2. Sign in with your Google account
3. Pay the $25 one-time registration fee
4. Complete your developer account profile

---

### **STEP 9: Create App Listing** 📝

1. Click "Create app" in Play Console
2. Fill in:
   - App name: "Central360"
   - Default language: Your preferred language
   - App or game: App
   - Free or paid: Free (or Paid)
   - Declarations: Check the boxes for your app's features

---

### **STEP 10: Upload App Bundle** 📝

1. Go to "Production" → "Create new release"
2. Upload your `app-release.aab` file
3. Add release notes
4. Review and roll out

---

## 📋 Quick Checklist

**Before Building Release:**
- [ ] Decide on package name
- [ ] Create keystore file
- [ ] Deploy backend to production
- [ ] Get production API URL
- [ ] Create app icon
- [ ] Create feature graphic
- [ ] Take screenshots
- [ ] Write app description
- [ ] Create privacy policy URL

**Before Uploading:**
- [ ] Build release AAB
- [ ] Test the release build
- [ ] Set up Google Play Console account
- [ ] Prepare all assets

---

## 🆘 What I Need From You

1. **Package Name**: What should the package name be? (e.g., `com.srisurya.central360`)
2. **Production API URL**: Where will your backend be deployed?
3. **App Description**: Brief description of what the app does
4. **Company Name**: For keystore and app details

Once you provide these, I'll complete the configuration for you!

---

## 🔧 Current Status

✅ **Completed:**
- Environment configuration system created
- API service updated to use configurable URLs
- PDF generator updated
- Version number updated in pubspec.yaml

⏳ **Waiting for you:**
- Package name decision
- Keystore creation
- Production backend deployment
- App assets creation

Let me know your package name and I'll proceed with the configuration!

