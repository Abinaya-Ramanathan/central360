# Google Play Store Deployment Checklist

## ✅ What I've Already Done

1. ✅ **Environment Configuration**
   - Created `lib/config/env_config.dart` for configurable API URLs
   - Updated `lib/services/api_service.dart` to use environment config
   - Updated `lib/utils/pdf_generator.dart` to use environment config
   - You can now easily switch between development and production URLs

2. ✅ **Version Configuration**
   - Updated `pubspec.yaml` version to `1.0.0+1`
   - Added proper app description

3. ✅ **Documentation**
   - Created comprehensive deployment guide (`GOOGLE_PLAY_DEPLOYMENT.md`)
   - Created this checklist

---

## 📋 What YOU Need to Do - Step by Step

### **STEP 1: Decide on Package Name** ⚠️ IMPORTANT

**Current**: `com.example.central360` (Google Play won't accept this!)

**You need to choose**: A unique package name following reverse domain notation.

**Examples:**
- `com.srisurya.central360`
- `in.co.companyname.central360`
- `com.yourcompany.central360`

**⚠️ CRITICAL**: Once published, you CANNOT change the package name!

**After you tell me your package name, I'll update all necessary files.**

---

### **STEP 2: Create Signing Keystore** 🔐

**This is REQUIRED for Google Play Store!**

**Steps:**

1. **Open Command Prompt or PowerShell** (not VS Code terminal, use Windows Command Prompt)

2. **Navigate to your android folder**:
   ```cmd
   cd F:\central360\frontend\android
   ```

3. **Run this command**:
   ```cmd
   keytool -genkey -v -keystore central360-release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias central360
   ```

4. **Answer the prompts**:
   ```
   Enter keystore password: [Create a strong password - WRITE IT DOWN!]
   Re-enter new password: [Type same password]
   What is your first and last name?
     [Unknown]: Your Name or Company Name
   What is the name of your organizational unit?
     [Unknown]: IT Department (or your department)
   What is the name of your organization?
     [Unknown]: Your Company Name
   What is the name of your City or Locality?
     [Unknown]: Your City
   What is the name of your State or Province?
     [Unknown]: Your State
   What is the two-letter country code for this unit?
     [Unknown]: IN (or your country code - 2 letters)
   Is CN=Your Name, OU=IT Department, O=Your Company, L=City, ST=State, C=IN correct?
     [no]: yes
   Enter key password for <central360>
         (RETURN if same as keystore password): [Press Enter]
   ```

5. **File Created**: `central360-release-key.jks` in `frontend/android/` folder

6. **⚠️ IMPORTANT**: 
   - **Back up this file** to multiple secure locations (cloud, USB drive, etc.)
   - **Never commit it to Git!**
   - **Write down the password** in a secure location
   - **If you lose this file or password, you CANNOT update your app on Google Play!**

7. **Create `key.properties` file** in `frontend/android/` directory:
   - Create a new file: `key.properties`
   - Add this content (replace passwords with yours):
   ```
   storePassword=YOUR_KEYSTORE_PASSWORD
   keyPassword=YOUR_KEY_PASSWORD
   keyAlias=central360
   storeFile=central360-release-key.jks
   ```

**After you complete this step, tell me and I'll configure the build files to use it.**

---

### **STEP 3: Deploy Your Backend** 🌐

**Current**: Your app uses `http://localhost:4000` - this won't work for production!

**You need to:**
1. Deploy your backend to a production server
   - Options: AWS, Heroku, DigitalOcean, Google Cloud, Azure, etc.
   - Make sure it's accessible via HTTPS (required for production apps)

2. Get your production API URL
   - Example: `https://api.central360.com` or `https://central360-api.herokuapp.com`

3. **Tell me the production URL** and I'll help you configure it for builds

**Note**: For now, you can build with:
```bash
flutter build appbundle --release --dart-define=API_BASE_URL=https://your-production-api.com
```

---

### **STEP 4: Prepare App Assets** 📸

**Required for Google Play Store:**

1. **App Icon** (512x512 PNG)
   - Location: Replace app icon in Android project
   - No transparency, solid background
   - Square image (Google adds rounded corners)

2. **Feature Graphic** (1024x500 PNG)
   - Displays at top of Play Store listing
   - Should showcase your app

3. **Screenshots** (At least 2, up to 8)
   - Phone: 16:9 or 9:16 aspect ratio
   - Tablet: Min 768px width
   - Show key features of your app

4. **App Description**:
   - Short: 80 characters max (what appears in search results)
   - Full: 4000 characters max (detailed description)
   - Write about your app's features, what it does, etc.

5. **Privacy Policy URL** (REQUIRED)
   - Must be HTTPS URL
   - Must explain what data you collect and how you use it
   - Required even if you don't collect personal data

---

### **STEP 5: Set Up Google Play Console** 💼

1. Go to [Google Play Console](https://play.google.com/console/)
2. Sign in with Google account
3. Pay $25 one-time registration fee
4. Complete developer account profile

---

### **STEP 6: Create App Listing** 📱

1. Click "Create app"
2. Fill in:
   - App name: "Central360"
   - Default language
   - App or game: App
   - Free or paid: Free
   - Complete all required declarations

---

### **STEP 7: Build Release App Bundle** 📦

**After Steps 1-4 are complete**, I'll help you build:

```bash
cd frontend
flutter clean
flutter pub get
flutter build appbundle --release --dart-define=API_BASE_URL=https://your-production-api.com
```

**Output**: `build/app/outputs/bundle/release/app-release.aab`

---

### **STEP 8: Upload to Play Store** ⬆️

1. In Play Console, go to "Production" → "Create new release"
2. Upload your `app-release.aab` file
3. Add release notes (what's new in this version)
4. Review and roll out

---

## 🆘 Information I Need From You

Please provide:

1. **Package Name**: What should it be? (e.g., `com.srisurya.central360`)
2. **Company/Organization Name**: For keystore and app details
3. **Production Backend URL**: Where will your API be hosted?
4. **App Description**: Brief description of what Central360 does
5. **Privacy Policy URL**: Do you have one? If not, you'll need to create it

**Once you provide these, I'll:**
- ✅ Update all package names in the codebase
- ✅ Configure build.gradle for signing
- ✅ Set up environment variables
- ✅ Create build scripts
- ✅ Guide you through the rest of the process

---

## 📞 Next Steps

1. **Tell me your package name** (most important!)
2. **Complete Step 2** (create keystore) and let me know when done
3. **Share your production backend URL** when ready
4. **Start preparing app assets** (icons, screenshots, description)

**Let's start with Step 1 - what package name would you like to use?**

