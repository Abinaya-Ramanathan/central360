# Install Git on Windows - Quick Guide

## Step 1: Download Git

1. Go to: **https://git-scm.com/download/win**
2. The download will start automatically
3. Or click the download button if it doesn't start

## Step 2: Install Git

1. **Run the installer** (`Git-2.x.x-64-bit.exe`)
2. Click **"Next"** through the installation wizard
3. **Important settings:**
   - ✅ **Use Git from the command line and also from 3rd-party software** (recommended)
   - ✅ **Use bundled OpenSSH**
   - ✅ **Use the OpenSSL library**
   - ✅ **Checkout Windows-style, commit Unix-style line endings**
   - ✅ **Use Windows' default console window**
   - ✅ **Enable file system caching**
   - ✅ **Enable Git Credential Manager**
3. Click **"Install"**
4. Wait for installation to complete
5. Click **"Finish"**

## Step 3: Verify Installation

**Close and reopen PowerShell**, then run:

```powershell
git --version
```

You should see something like: `git version 2.43.0.windows.1`

## Step 4: Configure Git (First Time Only)

```powershell
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

**Example:**
```powershell
git config --global user.name "John Doe"
git config --global user.email "john.doe@example.com"
```

## Step 5: Continue with GitHub Setup

Once Git is installed, you can proceed with:

1. **Initialize repository:**
   ```powershell
   cd F:\central360
   git init
   ```

2. **Add files:**
   ```powershell
   git add .
   ```

3. **Commit:**
   ```powershell
   git commit -m "Initial commit - Company360 v1.0.0"
   ```

4. **Add remote and push:**
   ```powershell
   git remote add origin https://github.com/YOUR_USERNAME/company360.git
   git branch -M main
   git push -u origin main
   ```

---

## Alternative: Use GitHub Desktop (Easier GUI Option)

If you prefer a graphical interface:

1. Download: **https://desktop.github.com/**
2. Install GitHub Desktop
3. Sign in with your GitHub account
4. **File → Add Local Repository** → Select `F:\central360`
5. **Publish repository** to GitHub

This is easier for beginners but Git command line gives you more control.

---

## Troubleshooting

### Git still not recognized after installation
1. **Close and reopen PowerShell** (required to refresh PATH)
2. If still not working, restart your computer
3. Check if Git is in PATH:
   ```powershell
   $env:Path -split ';' | Select-String -Pattern "Git"
   ```

### Need to update PATH manually
1. Find Git installation: Usually `C:\Program Files\Git\cmd\`
2. Add to PATH: System Properties → Environment Variables → Path → Edit → Add

---

**After installing Git, continue with the deployment steps!** 🚀

