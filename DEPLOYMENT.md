# Company360 - Complete Deployment Guide

## 🚀 Quick Start (15 minutes)

1. **Deploy Backend to Railway** (5 min) → Get API URL
2. **Build Production Installer** (3 min) → Create installer with Railway URL
3. **Create GitHub Release** (2 min) → Get shareable download link
4. **Share the Link** → Done! 🎉

---

## Step 1: Deploy Backend to Railway

### Prerequisites
- Railway account: https://railway.app (free tier available)
- GitHub repository: https://github.com/Abinaya-Ramanathan/company360

### Deployment Steps

1. **Go to Railway:**
   - Visit https://railway.app
   - Sign up/Login with GitHub

2. **Create New Project:**
   - Click **"New Project"**
   - Select **"Deploy from GitHub repo"**
   - Authorize Railway to access GitHub
   - Select `company360` repository
   - Click **"Deploy Now"**

3. **Configure Backend:**
   - Click on your service
   - Go to **Settings** tab
   - Set **Root Directory** to: `backend`
   - Click **Save**

4. **Add PostgreSQL Database:**
   - In your Railway project, click **"+ New"**
   - Select **"Database"** → **"Add PostgreSQL"**
   - Railway automatically provides `DATABASE_URL`

5. **Set Environment Variables:**
   - Go to **Variables** tab
   - Click **"+ New Variable"**
   - Add these:
     ```
     NODE_ENV=production
     PORT=4000
     JWT_SECRET=your-random-secret-key-change-this
     JWT_EXPIRES_IN=7d
     ```
   - **Note:** `DATABASE_URL` is auto-provided (don't add manually)

6. **Get Your Railway URL:**
   - After deployment, go to **Settings** → **Networking**
   - Click **"Generate Domain"** or use the provided domain
   - Your API URL: `https://your-app.railway.app`
   - **Copy this URL** - you'll need it for the installer!

---

## Step 2: Build Production Installer

### Option A: Using PowerShell Script (Recommended)

```powershell
cd F:\central360
.\build-with-railway-url.ps1
```

Enter your Railway URL when prompted.

### Option B: Manual Build

```powershell
cd F:\central360\frontend

# Replace YOUR_RAILWAY_URL with your actual Railway URL
flutter build windows --release --dart-define=API_BASE_URL=https://your-app.railway.app
```

### Create Installer

1. Open **Inno Setup Compiler**
2. **File** → **Open** → `F:\central360\frontend\setup.iss`
3. **Build** → **Compile** (F9)
4. Installer created at: `F:\central360\frontend\installer\company360-setup.exe`

---

## Step 3: Create GitHub Release

1. **Go to Releases:**
   - Visit: https://github.com/Abinaya-Ramanathan/company360/releases
   - Click **"Create a new release"**

2. **Fill Release Details:**
   - **Tag version:** `v1.0.0` (must start with `v`)
   - **Release title:** `Company360 v1.0.0`
   - **Description:** (optional)
     ```
     ## Company360 v1.0.0
     
     Windows installer for Company360 Business Management Application.
     
     ### Installation
     1. Download the installer
     2. Run company360-setup.exe
     3. Follow the installation wizard
     4. Launch Company360
     
     ### System Requirements
     - Windows 10 or later
     - 64-bit system
     - Internet connection
     ```

3. **Attach Installer:**
   - Drag and drop: `F:\central360\frontend\installer\company360-setup.exe`
   - Or click **"Attach binaries"** and select the file

4. **Publish:**
   - Click **"Publish release"**

---

## Step 4: Get Your Shareable Download Link

After publishing, your download links are:

### Latest Release (Recommended)
```
https://github.com/Abinaya-Ramanathan/company360/releases/latest/download/company360-setup.exe
```
✅ Always points to the newest version

### Specific Version
```
https://github.com/Abinaya-Ramanathan/company360/releases/download/v1.0.0/company360-setup.exe
```

### Releases Page
```
https://github.com/Abinaya-Ramanathan/company360/releases
```
✅ Users can browse all versions

---

## 🔄 Updating the App

When you release a new version:

1. **Update code:**
   ```powershell
   git add .
   git commit -m "Update: description of changes"
   git push
   ```

2. **Rebuild installer:**
   ```powershell
   cd F:\central360\frontend
   flutter build windows --release --dart-define=API_BASE_URL=https://your-app.railway.app
   # Create installer in Inno Setup
   ```

3. **Create new release:**
   - Tag: `v1.0.1` (increment version)
   - Upload new installer
   - Publish

4. **Users get latest automatically** via the `latest` download link!

---

## ✅ Checklist

- [ ] Backend deployed to Railway
- [ ] Railway URL copied: `https://__________.railway.app`
- [ ] Installer built with production API URL
- [ ] GitHub Release created
- [ ] Download link tested
- [ ] Link shared with users

---

## 🆘 Troubleshooting

### Railway Deployment Issues
- Check **Deployments** tab → View logs
- Verify environment variables are set
- Ensure `DATABASE_URL` is auto-provided by PostgreSQL service
- Check service status (should be green/running)

### Build Issues
- Verify Railway URL is correct
- Check Flutter build output for errors
- Ensure all DLL files exist in `build\windows\x64\runner\Release\`

### GitHub Release Issues
- Verify file size is under 100MB (GitHub limit)
- Check that tag starts with `v` (e.g., `v1.0.0`)
- Ensure installer file is attached before publishing

---

## 📚 Quick Reference

**Railway API URL Format:**
```
https://your-app.railway.app/api/v1
```

**GitHub Download Link:**
```
https://github.com/Abinaya-Ramanathan/company360/releases/latest/download/company360-setup.exe
```

**Build Command:**
```powershell
flutter build windows --release --dart-define=API_BASE_URL=https://your-app.railway.app
```

---

**Need Help?** Check Railway and GitHub documentation for detailed guides.

