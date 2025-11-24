# Company360 - Complete Deployment Guide

This guide will help you deploy Company360 to GitHub and Railway, and create a shareable download link.

## 📋 Prerequisites

1. **GitHub Account** - Sign up at https://github.com
2. **Railway Account** - Sign up at https://railway.app
3. **Git** - Install from https://git-scm.com/download/win
4. **Railway CLI** (optional) - Install from https://docs.railway.app/develop/cli

---

## Part 1: Deploy Backend to Railway

### Step 1: Prepare Backend for Railway

1. **Navigate to backend folder:**
   ```powershell
   cd F:\central360\backend
   ```

2. **Create/Update `.env` file** (if not exists):
   ```env
   NODE_ENV=production
   PORT=4000
   JWT_SECRET=your-super-secret-jwt-key-change-this
   JWT_EXPIRES_IN=7d
   ```

3. **Verify `package.json` has start script:**
   ```json
   "scripts": {
     "start": "node src/index.js"
   }
   ```

### Step 2: Deploy to Railway

**Option A - Using Railway Dashboard (Recommended):**

1. Go to https://railway.app and sign in
2. Click **"New Project"**
3. Select **"Deploy from GitHub repo"** (if you've pushed to GitHub) OR **"Empty Project"**
4. If Empty Project:
   - Click **"Add Service"** → **"GitHub Repo"**
   - Connect your GitHub account
   - Select your repository
   - Select the `backend` folder as root directory
5. Add PostgreSQL Database:
   - Click **"New"** → **"Database"** → **"Add PostgreSQL"**
6. Set Environment Variables:
   - Go to your service → **Variables** tab
   - Add these variables:
     ```
     NODE_ENV=production
     PORT=4000
     JWT_SECRET=your-super-secret-jwt-key-change-this
     JWT_EXPIRES_IN=7d
     ```
   - Railway automatically provides `DATABASE_URL` from the PostgreSQL service
7. Deploy:
   - Railway will automatically detect Node.js and deploy
   - Wait for deployment to complete
   - Note the generated domain (e.g., `your-app.railway.app`)

**Option B - Using Railway CLI:**

```powershell
# Install Railway CLI
npm i -g @railway/cli

# Login
railway login

# Initialize project
cd F:\central360\backend
railway init

# Link to existing project or create new
railway link

# Add PostgreSQL database
railway add

# Set environment variables
railway variables set NODE_ENV=production
railway variables set JWT_SECRET=your-super-secret-jwt-key
railway variables set JWT_EXPIRES_IN=7d

# Deploy
railway up
```

### Step 3: Get Your Railway API URL

After deployment, Railway will provide a URL like:
- `https://your-app-name.railway.app`

Your API will be available at:
- `https://your-app-name.railway.app/api/v1`

**Important:** Note this URL - you'll need it for the frontend build!

---

## Part 2: Deploy Code to GitHub

### Step 1: Initialize Git Repository (if not already done)

```powershell
cd F:\central360

# Initialize git (if not already done)
git init

# Add all files
git add .

# Commit
git commit -m "Initial commit - Company360"
```

### Step 2: Create GitHub Repository

1. Go to https://github.com/new
2. Repository name: `company360` (or your preferred name)
3. Description: "Company360 - Comprehensive Business Management App"
4. Choose **Private** or **Public**
5. **DO NOT** initialize with README, .gitignore, or license
6. Click **"Create repository"**

### Step 3: Push to GitHub

```powershell
# Add remote (replace YOUR_USERNAME with your GitHub username)
git remote add origin https://github.com/YOUR_USERNAME/company360.git

# Rename branch to main (if needed)
git branch -M main

# Push to GitHub
git push -u origin main
```

**If you need to authenticate:**
- Use GitHub Personal Access Token (Settings → Developer settings → Personal access tokens)
- Or use GitHub Desktop app

---

## Part 3: Build Windows Installer with Production API

### Step 1: Build Flutter App with Production API URL

Replace `YOUR_RAILWAY_URL` with your actual Railway URL:

```powershell
cd F:\central360\frontend

# Clean previous builds
flutter clean

# Build with production API URL
flutter build windows --release --dart-define=API_BASE_URL=https://YOUR_RAILWAY_URL
```

**Example:**
```powershell
flutter build windows --release --dart-define=API_BASE_URL=https://company360-backend.railway.app
```

### Step 2: Create Installer

1. Open **Inno Setup Compiler**
2. **File → Open** → `F:\central360\frontend\setup.iss`
3. **Build → Compile** (F9)
4. Installer will be at: `F:\central360\frontend\installer\company360-setup.exe`

---

## Part 4: Create Shareable Download Link

### Option 1: GitHub Releases (Recommended - Free)

1. **Go to your GitHub repository**
2. Click **"Releases"** → **"Create a new release"**
3. **Tag version:** `v1.0.0`
4. **Release title:** `Company360 v1.0.0 - Windows Installer`
5. **Description:**
   ```
   ## Company360 v1.0.0
   
   Windows installer for Company360 Business Management App.
   
   ### Installation
   1. Download `company360-setup.exe`
   2. Run the installer
   3. Follow the installation wizard
   4. Launch Company360
   
   ### Requirements
   - Windows 10 or later
   - 64-bit system
   ```
6. **Attach binary:**
   - Drag and drop `F:\central360\frontend\installer\company360-setup.exe`
7. Click **"Publish release"**
8. **Your download link will be:**
   ```
   https://github.com/YOUR_USERNAME/company360/releases/download/v1.0.0/company360-setup.exe
   ```

### Option 2: GitHub Releases with Latest Tag

For easier updates, use `latest` redirect:

1. Create release as above
2. Users can download from:
   ```
   https://github.com/YOUR_USERNAME/company360/releases/latest/download/company360-setup.exe
   ```

### Option 3: Simple File Hosting

**Alternative hosting options:**
- **Google Drive** - Upload file, share link (set to "Anyone with link")
- **Dropbox** - Upload file, create shareable link
- **OneDrive** - Upload file, share link
- **GitHub Gist** - For smaller files (not recommended for installers)

---

## Part 5: Create Download Page (Optional)

Create a simple HTML page for users to download:

### Create `download.html`:

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Download Company360</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            max-width: 800px;
            margin: 50px auto;
            padding: 20px;
            text-align: center;
        }
        .download-btn {
            display: inline-block;
            padding: 15px 30px;
            background-color: #007bff;
            color: white;
            text-decoration: none;
            border-radius: 5px;
            font-size: 18px;
            margin: 20px 0;
        }
        .download-btn:hover {
            background-color: #0056b3;
        }
    </style>
</head>
<body>
    <h1>Company360</h1>
    <h2>Download Windows Installer</h2>
    <p>Click the button below to download Company360 for Windows.</p>
    <a href="https://github.com/YOUR_USERNAME/company360/releases/latest/download/company360-setup.exe" 
       class="download-btn" 
       download>
        Download Company360 v1.0.0
    </a>
    <h3>Installation Instructions</h3>
    <ol style="text-align: left; max-width: 600px; margin: 0 auto;">
        <li>Download the installer file</li>
        <li>Run <code>company360-setup.exe</code></li>
        <li>Follow the installation wizard</li>
        <li>Launch Company360 from Start Menu or Desktop</li>
    </ol>
    <h3>System Requirements</h3>
    <ul style="text-align: left; max-width: 600px; margin: 0 auto;">
        <li>Windows 10 or later</li>
        <li>64-bit system</li>
        <li>Internet connection (for backend API)</li>
    </ul>
</body>
</html>
```

**Host this page:**
- GitHub Pages (free)
- Netlify (free)
- Vercel (free)
- Your own web server

---

## Part 6: Update Process (For Future Releases)

When you need to update the app:

1. **Update code and commit:**
   ```powershell
   git add .
   git commit -m "Update: description of changes"
   git push
   ```

2. **Rebuild with production API:**
   ```powershell
   cd F:\central360\frontend
   flutter build windows --release --dart-define=API_BASE_URL=https://YOUR_RAILWAY_URL
   ```

3. **Create new installer** (using Inno Setup)

4. **Create new GitHub Release:**
   - Tag: `v1.0.1` (increment version)
   - Upload new `company360-setup.exe`
   - Publish release

5. **Users can download latest:**
   - Direct link: `https://github.com/YOUR_USERNAME/company360/releases/latest/download/company360-setup.exe`
   - Or from Releases page

---

## Quick Reference

### Railway API URL Format
```
https://your-app-name.railway.app/api/v1
```

### GitHub Release Download Link
```
https://github.com/YOUR_USERNAME/company360/releases/latest/download/company360-setup.exe
```

### Build Command with Production API
```powershell
flutter build windows --release --dart-define=API_BASE_URL=https://YOUR_RAILWAY_URL
```

---

## Troubleshooting

### Railway Deployment Issues
- Check Railway logs: Railway Dashboard → Your Service → Deployments → View Logs
- Verify environment variables are set correctly
- Ensure `DATABASE_URL` is automatically provided by Railway PostgreSQL service

### GitHub Push Issues
- Use Personal Access Token instead of password
- Or use GitHub Desktop for easier authentication

### Installer Issues
- Make sure all DLL files exist in `build\windows\x64\runner\Release\`
- Rebuild installer after any code changes
- Test installer on a clean Windows machine

---

## Security Notes

1. **Never commit `.env` files** - They're in `.gitignore`
2. **Use strong JWT_SECRET** - Generate a random string
3. **Keep Railway URL private** - Or use environment variables
4. **Regular backups** - Backup your database regularly

---

**Need Help?** Check the Railway and GitHub documentation for detailed guides.

