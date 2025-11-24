# 🚀 Railway Deployment - Quick Start (5 Minutes)

## ✅ **Deploy Your Backend to Get Production API URL**

---

## 📋 **Step 1: Prepare Backend Code** (2 minutes)

### **1.1. Check GitHub Repository**

Make sure your backend code is on GitHub:

1. Go to [github.com](https://github.com)
2. Create repository: `central360-backend` (if not created)
3. Upload backend code from `F:\central360\backend` folder

**OR** if already on GitHub, make sure it's up to date.

---

## 📋 **Step 2: Deploy to Railway** (3 minutes)

### **2.1. Sign Up**

1. Go to [railway.app](https://railway.app)
2. Click **"Start a New Project"**
3. Sign up with **GitHub** account (easiest)

### **2.2. Create Project**

1. Click **"New Project"**
2. Select **"Deploy from GitHub repo"**
3. Select your `central360-backend` repository
4. Railway will automatically detect Node.js

### **2.3. Add Database**

1. Click **"+ New"** button (on the left sidebar)
2. Click **"Database"**
3. Select **"Add PostgreSQL"**
4. Wait for database to be created
5. **Copy the connection URL** (you'll need this!)

### **2.4. Set Environment Variables**

1. Click on your **service** (not the database)
2. Click **"Variables"** tab
3. Add these variables:

   **Required:**
   ```
   DATABASE_URL=<paste PostgreSQL connection URL here>
   JWT_SECRET=<any-random-secret-string>
   PORT=3000
   NODE_ENV=production
   ```

   **Optional (for email feature):**
   ```
   SMTP_HOST=smtp.gmail.com
   SMTP_PORT=587
   SMTP_SECURE=false
   SMTP_USER=your-email@gmail.com
   SMTP_PASSWORD=your-app-password
   ```

4. Click **"Add"** for each variable

### **2.5. Deploy**

1. Railway automatically starts deploying
2. Wait 5-10 minutes for deployment
3. Check **"Deployments"** tab for status
4. When green ✅, deployment is complete!

### **2.6. Get Production URL**

1. Click **"Settings"** tab (in your service)
2. Scroll to **"Domains"** section
3. Click **"Generate Domain"**
4. Your production URL: `https://your-app-name.up.railway.app`

**Your Production API URL:**
```
https://your-app-name.up.railway.app/api/v1
```

**Copy this URL!** ✅

---

## 📋 **Step 3: Setup Database** (5 minutes)

### **3.1. Connect to Database**

1. In Railway dashboard, click on **PostgreSQL** service
2. Click **"Data"** tab
3. Click **"Connect"** button
4. Copy the connection command (looks like: `psql $DATABASE_URL`)

### **3.2. Run Database Schema**

**Option A: Using Railway Web Interface**

1. Click on PostgreSQL service
2. Click **"Query"** tab
3. Copy contents of `backend/src/migrations/001_complete_schema.sql`
4. Paste and run

**Option B: Using Local psql**

1. Install PostgreSQL client (if not installed)
2. Use connection command from Railway
3. Run: `\i backend/src/migrations/001_complete_schema.sql`

---

## 📋 **Step 4: Test Production API** (1 minute)

**Test in browser:**
```
https://your-app-name.up.railway.app/api/health
```

**Should return:**
```json
{"status":"ok"}
```

**If it works, your backend is live!** ✅

---

## 📋 **Step 5: Build Your App** (Now you can build!)

**Use your production API URL:**

```powershell
cd F:\central360\frontend
.\build-release.bat
```

**When asked for API URL, enter:**
```
https://your-app-name.up.railway.app/api/v1
```

**Replace `your-app-name` with your actual Railway app name!**

---

## ✅ **Complete Checklist**

- [ ] Backend code on GitHub
- [ ] Signed up at Railway
- [ ] Created project from GitHub
- [ ] Added PostgreSQL database
- [ ] Set environment variables (DATABASE_URL, JWT_SECRET, etc.)
- [ ] Deployed successfully
- [ ] Generated domain URL
- [ ] Tested API (`/api/health`)
- [ ] Ran database migrations
- [ ] Built app with production URL

**Done!** 🎉

---

## 🆘 **Troubleshooting**

**Deployment fails?**
- Check **"Logs"** tab for errors
- Make sure `package.json` has `"start": "node src/server.js"`
- Check environment variables are set

**Database connection error?**
- Check `DATABASE_URL` is correct
- Make sure PostgreSQL service is running
- Run database migrations

**API not responding?**
- Check service is deployed (green status)
- Test `/api/health` endpoint
- Check logs for errors

**Need help?** Let me know and I'll assist you!

