# 🚀 GitHub Setup Instructions - Step by Step

## 📋 **Complete Setup Guide for GitHub Distribution**

---

## ✅ **Step 1: Create GitHub Repository**

### **1.1. Sign In to GitHub**

1. Go to [github.com](https://github.com)
2. Sign in (or create account if needed)
3. Click your profile picture (top right)

### **1.2. Create New Repository**

1. Click **"+"** icon (top right) → **"New repository"**
2. Fill in details:
   - **Repository name**: `central360-releases` (or your preferred name)
   - **Description**: `Central360 App - Android APK and Windows Installer Downloads`
   - **Visibility**: 
     - ✅ **Public** (anyone can download)
     - OR **Private** (only you can access - invite users if needed)
3. ✅ Check **"Add a README file"**
4. Click **"Create repository"**

---

## ✅ **Step 2: Build Your App Files**

### **2.1. Build Android APK**

**Open Command Prompt** and run:

```cmd
cd F:\central360\frontend
build-release.bat
```

**When asked for API URL**, enter your production backend URL:
```
https://api.central360.com
```
(Replace with your actual backend URL)

**Output:**
- Android APK: `build/app/outputs/flutter-apk/app-release.apk`

### **2.2. Build Windows EXE**

The script also builds Windows EXE automatically:
- Windows EXE: `build/windows/x64/runner/Release/central360.exe`

**Note:** For easier Windows distribution, you can create a ZIP file:
1. Zip the entire `Release` folder
2. Rename to `central360-v1.0.0-windows.zip`
3. Or create an installer (optional)

---

## ✅ **Step 3: Create GitHub Release**

### **3.1. Go to Releases Page**

1. In your repository, click **"Releases"** tab (on right sidebar)
2. Click **"Create a new release"** button

### **3.2. Fill Release Details**

**Tag Version:**
- Click **"Choose tag"** → Type: `v1.0.0`
- Click **"Create new tag: v1.0.0 on publish"**

**Release Title:**
```
Central360 v1.0.0
```

**Description:**
```markdown
## Central360 v1.0.0

### 📱 Android APK
- Download for Android mobile devices
- Compatible with Android 5.0+

### 💻 Windows Installer
- Download for Windows 10/11
- Portable version available

### ✨ Features
- Employee Management
- Expense Tracking
- Credit Management
- Vehicle & Driver Details
- And much more!

### 📝 Installation
See README.md for detailed installation instructions.
```

### **3.3. Upload Files**

**Drag and Drop:**
1. Drag `app-release.apk` into the **"Attach binaries"** area
2. Drag Windows EXE (or ZIP) into the **"Attach binaries"** area

**OR**

**Click to Browse:**
1. Click **"Attach binaries by dropping them here or selecting them"**
2. Browse and select `app-release.apk`
3. Browse and select Windows EXE/ZIP

### **3.4. Publish Release**

1. Click **"Publish release"** button
2. Wait for upload to complete
3. Release is now live! ✅

---

## ✅ **Step 4: Get Download Links**

### **4.1. Direct Download Links**

After publishing, go to your release page:
```
https://github.com/YOUR_USERNAME/central360-releases/releases/tag/v1.0.0
```

**Right-click on each file in "Assets" section:**
- `app-release.apk` → Copy link address
- `central360-setup.exe` → Copy link address

**Links will look like:**
```
https://github.com/YOUR_USERNAME/central360-releases/releases/download/v1.0.0/app-release.apk
https://github.com/YOUR_USERNAME/central360-releases/releases/download/v1.0.0/central360-setup.exe
```

### **4.2. Latest Release Link (Recommended)**

**For Latest Version (always points to newest):**
```
https://github.com/YOUR_USERNAME/central360-releases/releases/latest/download/app-release.apk
https://github.com/YOUR_USERNAME/central360-releases/releases/latest/download/central360-setup.exe
```

**Replace `YOUR_USERNAME` with your GitHub username!**

---

## ✅ **Step 5: Create Download Page (Optional)**

### **5.1. Update Download Page HTML**

1. Open `frontend/download-page.html`
2. Find and replace:
   - `YOUR_USERNAME` → Your GitHub username
   - `central360-releases` → Your repository name
3. Save the file

### **5.2. Upload to GitHub**

**Option A: Using GitHub Web Interface**

1. In your repository, click **"Add file"** → **"Create new file"**
2. Name it: `index.html`
3. Copy content from `frontend/download-page.html`
4. Paste into editor
5. Update download links (replace `YOUR_USERNAME`)
6. Click **"Commit new file"**

**Option B: Using Git Command Line**

```bash
cd F:\central360
git clone https://github.com/YOUR_USERNAME/central360-releases.git
cd central360-releases
copy frontend\download-page.html index.html
# Edit index.html and update YOUR_USERNAME
git add index.html
git commit -m "Add download page"
git push
```

### **5.3. Enable GitHub Pages**

1. Go to repository → **"Settings"** tab
2. Scroll down to **"Pages"** section (left sidebar)
3. Under **"Source"**, select **"Deploy from a branch"**
4. Select branch: **"main"** (or **"master"**)
5. Select folder: **"/ (root)"**
6. Click **"Save"**

**Your download page will be available at:**
```
https://YOUR_USERNAME.github.io/central360-releases/
```

**Wait 1-2 minutes for GitHub Pages to deploy!**

---

## ✅ **Step 6: Create README.md**

### **6.1. Update Repository README**

1. In your repository, click on **"README.md"**
2. Click **"Edit"** (pencil icon)
3. Replace with:

```markdown
# 📱💻 Central360 - Download Page

## Latest Version: v1.0.0

### Download Links

- **📱 Android APK**: [Download Latest](https://github.com/YOUR_USERNAME/central360-releases/releases/latest/download/app-release.apk)
- **💻 Windows Installer**: [Download Latest](https://github.com/YOUR_USERNAME/central360-releases/releases/latest/download/central360-setup.exe)

### 📋 Installation Instructions

#### 📱 Android Mobile:
1. Download APK from link above
2. Open "Downloads" folder on your phone
3. Tap the APK file to install
4. If prompted, enable "Install from Unknown Sources" in Settings
5. Tap "Install" and wait for installation to complete
6. Open the app from your app drawer

#### 💻 Windows Laptop/Desktop:
1. Download EXE from link above
2. Run the downloaded file
3. If Windows shows security warning, click "More info" → "Run anyway"
4. Follow installation wizard
5. Launch Central360 from Start Menu

### 📦 All Releases

View all versions and download previous releases: [All Releases](https://github.com/YOUR_USERNAME/central360-releases/releases)

### 🆘 Support

For issues or questions, please contact: your-email@example.com

---

## 🚀 About Central360

Central360 is a comprehensive business management app for managing:
- Employees & Attendance
- Expenses & Credits
- Vehicle & Driver Details
- Mahal Bookings & Catering
- And much more!
```

**Replace `YOUR_USERNAME` with your GitHub username!**

4. Click **"Commit changes"**

---

## ✅ **Step 7: Share Links**

### **7.1. Share Direct Download Links**

**For Android:**
```
https://github.com/YOUR_USERNAME/central360-releases/releases/latest/download/app-release.apk
```

**For Windows:**
```
https://github.com/YOUR_USERNAME/central360-releases/releases/latest/download/central360-setup.exe
```

**Share via:**
- Email
- WhatsApp
- QR Code
- Website (if you have one)
- GitHub Pages (download page)

### **7.2. Share Releases Page**

**Link to all releases:**
```
https://github.com/YOUR_USERNAME/central360-releases/releases
```

### **7.3. Share GitHub Pages (If Enabled)**

**Link to download page:**
```
https://YOUR_USERNAME.github.io/central360-releases/
```

---

## 🔄 **Updating App (New Versions)**

When you release a new version:

1. **Build new files:**
   ```cmd
   cd F:\central360\frontend
   build-release.bat
   ```
   (Enter production API URL when asked)

2. **Create new release on GitHub:**
   - Tag: `v1.0.1` (increment version)
   - Title: `Central360 v1.0.1`
   - Description: Add changelog
   - Upload new APK and EXE files
   - Click "Publish release"

3. **Download links automatically update:**
   - Latest release links (`/releases/latest/`) automatically point to newest version
   - Users can always download the latest version!

---

## ✅ **Complete Checklist**

**Initial Setup:**
- [ ] Create GitHub account
- [ ] Create repository (`central360-releases`)
- [ ] Build APK and Windows EXE
- [ ] Create first release (v1.0.0)
- [ ] Upload APK file
- [ ] Upload Windows EXE/ZIP file
- [ ] Publish release
- [ ] Copy download links
- [ ] Update README.md
- [ ] (Optional) Create download page (index.html)
- [ ] (Optional) Enable GitHub Pages
- [ ] Share links with users

**For Updates:**
- [ ] Build new APK and EXE
- [ ] Create new release (increment version)
- [ ] Upload new files
- [ ] Add changelog
- [ ] Publish release
- [ ] Share updated links (or use same `/latest/` links)

---

## 🎯 **Example Links (Replace YOUR_USERNAME)**

**Direct Downloads:**
```
https://github.com/YOUR_USERNAME/central360-releases/releases/latest/download/app-release.apk
https://github.com/YOUR_USERNAME/central360-releases/releases/latest/download/central360-setup.exe
```

**Releases Page:**
```
https://github.com/YOUR_USERNAME/central360-releases/releases
```

**GitHub Pages (if enabled):**
```
https://YOUR_USERNAME.github.io/central360-releases/
```

---

## 🆘 **Troubleshooting**

**File won't upload?**
- Check file size (GitHub allows up to 100MB per file)
- Make sure you're uploading in "Attach binaries" area

**Download page not showing?**
- Wait 1-2 minutes for GitHub Pages to deploy
- Check repository Settings → Pages is enabled
- Make sure `index.html` is in root directory

**Links not working?**
- Make sure you copied the correct link
- Replace `YOUR_USERNAME` with your actual username
- Check that release is published (not draft)

---

## ✅ **That's It!**

**You now have:**
- ✅ Free hosting on GitHub
- ✅ Professional download links
- ✅ Easy version management
- ✅ Download page (if enabled)
- ✅ Automatic updates via `/latest/` links

**Share the links and you're done!** 🚀

