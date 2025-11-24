# GitHub Setup - Step by Step

## Step 1: Install Git (if not installed)

1. Download Git: https://git-scm.com/download/win
2. Install with default settings
3. Restart your terminal/PowerShell

## Step 2: Configure Git (First Time Only)

```powershell
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

## Step 3: Create GitHub Repository

1. Go to https://github.com/new
2. Repository name: `company360`
3. Description: "Company360 - Business Management App"
4. Choose **Private** (recommended) or **Public**
5. **DO NOT** check "Initialize with README"
6. Click **"Create repository"**

## Step 4: Push Code to GitHub

```powershell
# Navigate to project root
cd F:\central360

# Initialize git (if not already done)
git init

# Add all files
git add .

# Commit
git commit -m "Initial commit - Company360 v1.0.0"

# Add remote (replace YOUR_USERNAME with your GitHub username)
git remote add origin https://github.com/YOUR_USERNAME/company360.git

# Rename branch to main
git branch -M main

# Push to GitHub
git push -u origin main
```

**If asked for credentials:**
- Username: Your GitHub username
- Password: Use a **Personal Access Token** (not your GitHub password)
  - Go to: GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
  - Generate new token with `repo` scope
  - Use this token as password

## Step 5: Verify

1. Go to https://github.com/YOUR_USERNAME/company360
2. You should see all your files

## Step 6: Create GitHub Release

1. Go to your repository → **Releases** → **"Create a new release"**
2. **Tag version:** `v1.0.0`
3. **Release title:** `Company360 v1.0.0 - Windows Installer`
4. **Description:**
   ```
   ## Company360 v1.0.0
   
   Windows installer for Company360 Business Management Application.
   
   ### Installation
   1. Download `company360-setup.exe`
   2. Run the installer
   3. Follow the installation wizard
   4. Launch Company360
   
   ### System Requirements
   - Windows 10 or later
   - 64-bit system
   - Internet connection
   ```
5. **Attach binary:**
   - Drag and drop `F:\central360\frontend\installer\company360-setup.exe`
6. Click **"Publish release"**

## Step 7: Get Your Download Link

After publishing, your download links will be:

**Latest Release (always points to newest):**
```
https://github.com/YOUR_USERNAME/company360/releases/latest/download/company360-setup.exe
```

**Specific Version:**
```
https://github.com/YOUR_USERNAME/company360/releases/download/v1.0.0/company360-setup.exe
```

**Releases Page (users can browse):**
```
https://github.com/YOUR_USERNAME/company360/releases
```

## Step 8: Share the Link

You can share any of these links:
- Direct download link (for direct downloads)
- Releases page link (for users to browse versions)

---

## Future Updates

When you update the app:

```powershell
# Make changes to code
git add .
git commit -m "Update: description of changes"
git push

# Build new installer (with production API URL)
cd frontend
flutter build windows --release --dart-define=API_BASE_URL=https://YOUR_RAILWAY_URL
# Create installer in Inno Setup

# Create new GitHub release
# Tag: v1.0.1, v1.0.2, etc.
# Upload new installer
```

---

**Done!** Your app is now on GitHub with a shareable download link! 🎉

