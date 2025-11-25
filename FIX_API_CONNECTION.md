# Fix: App Connection Error

## 🔍 Problem

The app is trying to connect to `localhost:4000` but the backend is on Railway. You're seeing:
```
Login failed: ClientException with SocketThe remote computer refused the network connection.
address = localhost, port = 53354, uri=http://localhost:4000/api/v1/auth/login
```

## ✅ Solution Applied

I've updated the app to:
1. **Read API URL from config file** (for installed apps)
2. **Fall back to environment variable** (for builds)
3. **Fall back to default** (localhost for development)

## 🚀 Quick Fix (For Installed App)

### Option 1: Create Config File (Recommended)

1. **Find your Railway backend URL:**
   - Go to Railway Dashboard → Your Service → Settings
   - Copy the **Public Domain** URL (e.g., `https://your-app.railway.app`)

2. **Create config file:**
   - Open File Explorer
   - Navigate to: `C:\Users\YourUsername\AppData\Local\Company360\`
   - Create a file named `config.json`
   - Add this content (replace with your Railway URL):
     ```json
     {
       "apiBaseUrl": "https://your-app.railway.app",
       "updatedAt": "2025-11-25T00:00:00Z"
     }
     ```

3. **Restart the app** - it will now connect to Railway!

### Option 2: Rebuild with Railway URL

If you want to build a new installer with the Railway URL baked in:

1. **Get your Railway URL:**
   - Railway Dashboard → Your Service → Settings → Public Domain

2. **Build with URL:**
   ```powershell
   cd frontend
   flutter build windows --release --dart-define=API_BASE_URL=https://your-app.railway.app
   ```

3. **Create new installer** with Inno Setup

## 📝 For Future Releases

When building the installer, you can either:

**A) Build with Railway URL:**
```powershell
flutter build windows --release --dart-define=API_BASE_URL=https://your-app.railway.app
```

**B) Let users create config file** (more flexible - they can update URL without reinstalling)

## 🔧 Testing

1. **Check current config:**
   - The app logs the API URL on startup
   - Look for: `Config loaded from file: ...` or `Using default config: ...`

2. **Test connection:**
   - Try logging in
   - Should connect to Railway instead of localhost

## 📍 Config File Location

- **Windows:** `C:\Users\YourUsername\AppData\Local\Company360\config.json`
- **Android:** App Documents Directory
- **iOS:** App Documents Directory

## 🆘 Still Not Working?

1. **Verify Railway URL is correct:**
   - Test in browser: `https://your-app.railway.app/api/health`
   - Should return: `{"status":"ok","service":"Company360 API"}`

2. **Check config file:**
   - Make sure JSON is valid
   - No trailing slashes in URL
   - Use `https://` not `http://`

3. **Check app logs:**
   - Look for config initialization messages
   - Check for connection errors

4. **Try rebuilding:**
   - Use Option 2 above to build with Railway URL directly

## 📚 Files Changed

- ✅ `frontend/lib/config/env_config.dart` - Added config file support
- ✅ `frontend/lib/main.dart` - Initialize config at startup
- ✅ `frontend/lib/services/api_service.dart` - Uses config (no changes needed)

The app will now automatically use the Railway URL from the config file! 🎉

