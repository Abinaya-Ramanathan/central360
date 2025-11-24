# 🚀 Company360 - Deployment Quick Start

**Follow these steps in order to deploy your app and create a shareable download link.**

---

## ⚡ Quick Overview (15 minutes)

1. **Deploy Backend to Railway** (5 min) → Get API URL
2. **Push Code to GitHub** (2 min) → Host your code
3. **Build Production Installer** (3 min) → Create installer with production API
4. **Create GitHub Release** (2 min) → Get shareable download link
5. **Share the Link** (1 min) → Done! 🎉

---

## 📋 Step-by-Step Guide

### Step 1: Deploy Backend to Railway

**Time: 5 minutes**

1. Go to https://railway.app → Sign up/Login
2. **New Project** → **Deploy from GitHub repo**
3. Connect GitHub → Select `company360` repository
4. **Settings** → Set **Root Directory** to: `backend`
5. **+ New** → **Database** → **Add PostgreSQL**
6. **Variables** tab → Add:
   ```
   NODE_ENV=production
   JWT_SECRET=your-random-secret-key-here
   JWT_EXPIRES_IN=7d
   ```
7. Wait for deployment → **Copy the URL** (e.g., `https://your-app.railway.app`)

📖 **Detailed guide:** See `RAILWAY_DEPLOYMENT.md`

---

### Step 2: Push Code to GitHub

**Time: 2 minutes**

**If Git is not installed:**
1. Download: https://git-scm.com/download/win
2. Install with default settings
3. Restart PowerShell

**Push your code:**
```powershell
cd F:\central360

# Initialize git (if not done)
git init
git add .
git commit -m "Initial commit - Company360 v1.0.0"

# Add remote (replace YOUR_USERNAME)
git remote add origin https://github.com/YOUR_USERNAME/company360.git
git branch -M main
git push -u origin main
```

**If asked for credentials:**
- Username: Your GitHub username
- Password: Use Personal Access Token (GitHub → Settings → Developer settings → Personal access tokens)

📖 **Detailed guide:** See `GITHUB_SETUP.md`

---

### Step 3: Build Production Installer

**Time: 3 minutes**

**Option A - Using Batch Script:**
```powershell
cd F:\central360
$env:RAILWAY_URL = "https://your-app.railway.app"
.\build-production-installer.bat
```

**Option B - Manual:**
```powershell
cd F:\central360\frontend
flutter build windows --release --dart-define=API_BASE_URL=https://your-app.railway.app
```

Then:
1. Open **Inno Setup Compiler**
2. **File** → **Open** → `F:\central360\frontend\setup.iss`
3. **Build** → **Compile** (F9)
4. Installer created at: `F:\central360\frontend\installer\company360-setup.exe`

**Replace `https://your-app.railway.app` with your actual Railway URL from Step 1!**

---

### Step 4: Create GitHub Release

**Time: 2 minutes**

1. Go to: `https://github.com/YOUR_USERNAME/company360/releases`
2. Click **"Create a new release"**
3. Fill in:
   - **Tag:** `v1.0.0`
   - **Title:** `Company360 v1.0.0`
   - **Description:** (optional)
4. **Attach binary:** Drag `F:\central360\frontend\installer\company360-setup.exe`
5. Click **"Publish release"**

---

### Step 5: Get Your Shareable Link

**Your download link:**
```
https://github.com/YOUR_USERNAME/company360/releases/latest/download/company360-setup.exe
```

**Replace `YOUR_USERNAME` with your actual GitHub username!**

**Share this link with anyone** - they can download and install Company360!

📖 **Detailed guide:** See `SHAREABLE_LINK_GUIDE.md`

---

## ✅ Checklist

- [ ] Backend deployed to Railway
- [ ] Railway URL copied: `https://__________.railway.app`
- [ ] Code pushed to GitHub
- [ ] Installer built with production API URL
- [ ] GitHub Release created
- [ ] Download link tested
- [ ] Link shared with users

---

## 📚 Detailed Guides

- **Railway Deployment:** `RAILWAY_DEPLOYMENT.md`
- **GitHub Setup:** `GITHUB_SETUP.md`
- **Shareable Link:** `SHAREABLE_LINK_GUIDE.md`
- **Complete Guide:** `DEPLOYMENT_COMPLETE_GUIDE.md`
- **Quick Steps:** `QUICK_DEPLOYMENT_STEPS.md`

---

## 🔄 Future Updates

When you update the app:

1. **Update code:**
   ```powershell
   git add .
   git commit -m "Update: description"
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

## 🆘 Need Help?

- **Railway Issues:** Check `RAILWAY_DEPLOYMENT.md` → Troubleshooting
- **GitHub Issues:** Check `GITHUB_SETUP.md`
- **Build Issues:** Check `DEPLOYMENT_COMPLETE_GUIDE.md`

---

## 🎉 You're Done!

Your app is now:
- ✅ Deployed on Railway (backend)
- ✅ Hosted on GitHub (code)
- ✅ Available for download (installer)

**Share this link:**
```
https://github.com/YOUR_USERNAME/company360/releases/latest/download/company360-setup.exe
```

---

**Total Time: ~15 minutes** ⏱️

