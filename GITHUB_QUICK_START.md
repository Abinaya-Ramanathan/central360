# 🚀 GitHub Distribution - Quick Start Guide

## ✅ **5-Minute Setup for GitHub Downloads**

---

## 📋 **Step 1: Create GitHub Repository** (2 minutes)

1. Go to [github.com](https://github.com) and sign in
2. Click **"+"** → **"New repository"**
3. Name: `central360-releases`
4. Set to **Public** (so anyone can download)
5. ✅ Check **"Add a README file"**
6. Click **"Create repository"**

---

## 📋 **Step 2: Build Your App Files** (3 minutes)

**Open Command Prompt or PowerShell:**
```cmd
cd F:\central360\frontend
.\build-release.bat
```

**Note:** In PowerShell, you need to use `.\build-release.bat` (with `.\` prefix). In Command Prompt, you can use just `build-release.bat`.

**When asked for API URL**, enter your production backend URL:
```
https://your-api-url.com
```

**Output Files:**
- Android APK: `build/app/outputs/flutter-apk/app-release.apk`
- Windows EXE: `build/windows/x64/runner/Release/central360.exe`

---

## 📋 **Step 3: Create GitHub Release** (2 minutes)

1. In your repository, click **"Releases"** tab
2. Click **"Create a new release"**
3. **Tag**: `v1.0.0`
4. **Title**: `Central360 v1.0.0`
5. **Description**: (optional) Add release notes
6. **Drag and drop** both files (APK and EXE) into "Attach binaries" area
7. Click **"Publish release"**

---

## 📋 **Step 4: Get Download Links** (1 minute)

After publishing, your download links will be:

**For Android:**
```
https://github.com/YOUR_USERNAME/central360-releases/releases/latest/download/app-release.apk
```

**For Windows:**
```
https://github.com/YOUR_USERNAME/central360-releases/releases/latest/download/central360-setup.exe
```

**Replace `YOUR_USERNAME` with your GitHub username!**

**Right-click on files in "Assets" section to copy direct links!**

---

## 📋 **Step 5: Share Links** (Done! ✅)

**Share the links via:**
- Email
- WhatsApp
- QR Code (for mobile)
- Website (if you have one)

**That's it!** Users can now download your app from GitHub! 🎉

---

## 🔄 **For Updates (New Versions):**

1. Build new files: `build-release.bat`
2. Create new release: `v1.0.1`, `v1.0.2`, etc.
3. Upload new files
4. Publish release
5. Same download links work! (They point to `/latest/`)

---

## ✅ **Complete Checklist**

- [ ] Create GitHub account
- [ ] Create repository (`central360-releases`)
- [ ] Build APK and EXE files
- [ ] Create first release (v1.0.0)
- [ ] Upload APK file
- [ ] Upload Windows EXE file
- [ ] Publish release
- [ ] Copy download links
- [ ] Share links with users

**Done!** 🚀

---

## 🆘 **Need More Details?**

Check these guides:
- **`GITHUB_SETUP_INSTRUCTIONS.md`** - Complete step-by-step guide
- **`GITHUB_DISTRIBUTION_GUIDE.md`** - Detailed distribution guide
- **`GITHUB_README_TEMPLATE.md`** - README template for repository

---

## 📝 **Next Steps (Optional):**

1. **Create Download Page** (GitHub Pages):
   - Upload `frontend/download-page.html` as `index.html`
   - Enable GitHub Pages in Settings
   - Share: `https://YOUR_USERNAME.github.io/central360-releases/`

2. **Update README.md**:
   - Copy `GITHUB_README_TEMPLATE.md`
   - Paste into repository README.md
   - Replace `YOUR_USERNAME` with your username
   - Update email/contact info

3. **Generate QR Code**:
   - Use [QR Code Generator](https://www.qr-code-generator.com/)
   - Generate QR for Android APK link
   - Print or share QR code

**Everything is ready! Share the links and you're done!** ✅

