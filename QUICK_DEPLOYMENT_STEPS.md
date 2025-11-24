# Quick Deployment Steps - Company360

## 🚀 Fast Track Deployment

### 1. Deploy Backend to Railway (5 minutes)

1. Go to https://railway.app → Sign up/Login
2. **New Project** → **Empty Project**
3. **Add Service** → **GitHub Repo** (or **Empty Service**)
4. Connect GitHub and select your repo, set root to `backend/`
5. **Add Database** → **PostgreSQL**
6. **Variables** tab → Add:
   ```
   NODE_ENV=production
   JWT_SECRET=your-secret-key-here
   JWT_EXPIRES_IN=7d
   ```
7. Railway auto-deploys → **Copy the URL** (e.g., `https://your-app.railway.app`)

### 2. Push Code to GitHub (2 minutes)

```powershell
cd F:\central360
git add .
git commit -m "Initial deployment"
git remote add origin https://github.com/YOUR_USERNAME/company360.git
git push -u origin main
```

### 3. Build Installer with Production API (3 minutes)

```powershell
cd F:\central360\frontend
flutter build windows --release --dart-define=API_BASE_URL=https://YOUR_RAILWAY_URL
```

Then create installer in Inno Setup:
- Open `setup.iss`
- Build → Compile

### 4. Create GitHub Release (2 minutes)

1. GitHub repo → **Releases** → **Create a new release**
2. Tag: `v1.0.0`
3. Upload `installer\company360-setup.exe`
4. **Publish release**

### 5. Share Download Link

**Direct Download:**
```
https://github.com/YOUR_USERNAME/company360/releases/latest/download/company360-setup.exe
```

**Or share the Releases page:**
```
https://github.com/YOUR_USERNAME/company360/releases
```

---

## ✅ Checklist

- [ ] Backend deployed to Railway
- [ ] Railway URL noted: `https://__________.railway.app`
- [ ] Code pushed to GitHub
- [ ] Installer built with production API URL
- [ ] GitHub Release created
- [ ] Download link tested

---

**Total Time: ~15 minutes**

