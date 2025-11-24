# Creating Shareable Download Link - Company360

## 🎯 Quick Solution: GitHub Releases (Recommended)

### Why GitHub Releases?
- ✅ **Free** - No cost
- ✅ **Reliable** - GitHub's CDN
- ✅ **Version Control** - Easy to manage versions
- ✅ **Direct Download** - Users can download directly
- ✅ **No Setup** - Works immediately

## 📦 Step-by-Step: Create Shareable Link

### Step 1: Build Production Installer

```powershell
cd F:\central360\frontend

# Set your Railway URL
$env:RAILWAY_URL = "https://your-app.railway.app"

# Build with production API
flutter build windows --release --dart-define=API_BASE_URL=$env:RAILWAY_URL

# Create installer in Inno Setup
# Open setup.iss → Build → Compile
```

**Or use the automated script:**
```powershell
cd F:\central360
$env:RAILWAY_URL = "https://your-app.railway.app"
.\build-production-installer.bat
```

### Step 2: Create GitHub Release

1. Go to: `https://github.com/YOUR_USERNAME/company360/releases`
2. Click **"Create a new release"**
3. Fill in:
   - **Tag version:** `v1.0.0` (must start with `v`)
   - **Release title:** `Company360 v1.0.0`
   - **Description:**
     ```markdown
     ## Company360 v1.0.0
     
     Windows installer for Company360 Business Management Application.
     
     ### Installation
     1. Download the installer
     2. Run `company360-setup.exe`
     3. Follow the installation wizard
     4. Launch Company360
     
     ### System Requirements
     - Windows 10 or later
     - 64-bit system
     - Internet connection
     ```
4. **Attach binary:**
   - Drag and drop `F:\central360\frontend\installer\company360-setup.exe`
   - Or click "Attach binaries" and select the file
5. Click **"Publish release"**

### Step 3: Get Your Shareable Links

After publishing, you'll have these links:

#### Option A: Latest Release (Recommended)
```
https://github.com/YOUR_USERNAME/company360/releases/latest/download/company360-setup.exe
```
✅ Always points to the newest version

#### Option B: Specific Version
```
https://github.com/YOUR_USERNAME/company360/releases/download/v1.0.0/company360-setup.exe
```
✅ Points to a specific version

#### Option C: Releases Page
```
https://github.com/YOUR_USERNAME/company360/releases
```
✅ Users can browse all versions

### Step 4: Share the Link

**Share directly:**
- Send the link via email, WhatsApp, etc.
- Users click → Download starts automatically

**Or create a download page:**
- Use the provided `download.html` file
- Host it on GitHub Pages, Netlify, or your own server
- Update the GitHub username in the HTML file

---

## 🔄 Updating the App

When you release a new version:

1. **Update code and push:**
   ```powershell
   git add .
   git commit -m "Update: new features"
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

4. **Users automatically get latest:**
   - The `latest` link always points to newest version
   - Or they can visit releases page to see all versions

---

## 📊 Alternative Hosting Options

### Option 1: GitHub Releases (Recommended) ✅
- **Cost:** Free
- **Reliability:** High
- **Setup:** Easy
- **Best for:** Most use cases

### Option 2: Google Drive
1. Upload `company360-setup.exe` to Google Drive
2. Right-click → Get link → Set to "Anyone with link"
3. Share the link
- **Note:** Users need to download, not direct install

### Option 3: Dropbox
1. Upload file to Dropbox
2. Create shareable link
3. Change `?dl=0` to `?dl=1` for direct download
- **Note:** Similar to Google Drive

### Option 4: Your Own Web Server
1. Upload installer to your web server
2. Share direct link
3. Example: `https://yourdomain.com/downloads/company360-setup.exe`

---

## 🎨 Custom Download Page

I've created `frontend/download.html` for you. To use it:

1. **Update GitHub username:**
   - Open `frontend/download.html`
   - Replace `YOUR_USERNAME` with your actual GitHub username
   - Save the file

2. **Host the page:**
   - **GitHub Pages** (free):
     - Create `gh-pages` branch
     - Push `download.html` to that branch
     - Enable GitHub Pages in repository settings
     - Access at: `https://YOUR_USERNAME.github.io/company360/download.html`
   
   - **Netlify** (free):
     - Drag and drop `download.html` to Netlify
     - Get instant URL
   
   - **Vercel** (free):
     - Connect GitHub repo
     - Deploy automatically

---

## ✅ Quick Checklist

- [ ] Backend deployed to Railway
- [ ] Railway URL: `https://__________.railway.app`
- [ ] Code pushed to GitHub
- [ ] Installer built with production API URL
- [ ] GitHub Release created
- [ ] Download link tested
- [ ] Link shared with users

---

## 📝 Example Shareable Message

```
🎉 Company360 is now available for download!

📥 Download: https://github.com/YOUR_USERNAME/company360/releases/latest/download/company360-setup.exe

💻 System Requirements:
- Windows 10 or later
- 64-bit system
- Internet connection

📋 Installation:
1. Download the installer
2. Run company360-setup.exe
3. Follow the installation wizard
4. Launch Company360

🔐 Login:
- Admin: username: admin, password: admin
- Main Admin: username: abinaya, password: abinaya

For more info: https://github.com/YOUR_USERNAME/company360
```

---

**Your Shareable Link:**
```
https://github.com/YOUR_USERNAME/company360/releases/latest/download/company360-setup.exe
```

Replace `YOUR_USERNAME` with your actual GitHub username!

