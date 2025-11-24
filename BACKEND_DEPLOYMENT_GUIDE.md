# 🚀 Backend Deployment Guide - Get Production API URL

## 📋 **Before Building Your App**

**You need to deploy your backend first to get a production API URL!**

Your app connects to a backend API. Before distributing the app, you need to:
1. ✅ Deploy backend to a production server
2. ✅ Get production API URL (e.g., `https://api.central360.com`)
3. ✅ Build app with production URL
4. ✅ Share app with users

---

## 🎯 **Free Backend Hosting Options**

### **Option 1: Railway (RECOMMENDED - Easiest)** ⭐⭐⭐

**Why This is Best:**
- ✅ **Free tier** (with credit card - no charges unless you exceed)
- ✅ **Very easy** setup - connects to GitHub
- ✅ **Automatic deploys** from GitHub
- ✅ **PostgreSQL included** - no separate database needed
- ✅ **HTTPS included** - secure URLs
- ✅ **Fast deployment** - 5-10 minutes

**How It Works:**
1. Sign up at [railway.app](https://railway.app)
2. Connect GitHub account
3. Deploy from GitHub repository
4. Get production URL automatically
5. Done! ✅

**Best For:** Easiest deployment, quick setup

---

### **Option 2: Render (Free Tier Available)** ⭐⭐

**Why This is Good:**
- ✅ **Free tier** available (with limitations)
- ✅ **Easy setup** - connects to GitHub
- ✅ **Automatic deploys** from GitHub
- ✅ **PostgreSQL included**
- ✅ **HTTPS included**

**Limitations:**
- ⚠️ Free tier spins down after 15 minutes of inactivity
- ⚠️ First request after spin-down takes ~30 seconds

**Best For:** Simple deployments, non-critical apps

---

### **Option 3: Fly.io (Free Tier Available)** ⭐⭐

**Why This is Good:**
- ✅ **Free tier** available
- ✅ **Global deployment**
- ✅ **PostgreSQL included**
- ✅ **HTTPS included**

**Best For:** Global reach, production apps

---

### **Option 4: Heroku (Paid Now - But Reliable)** ⭐

**Why This is Good:**
- ✅ **Very reliable** - proven platform
- ✅ **Easy setup**
- ✅ **PostgreSQL addon**

**Limitations:**
- ❌ No longer has free tier (requires payment)
- ❌ $7-25/month minimum

**Best For:** Production apps, if budget allows

---

### **Option 5: Self-Hosted (Your Own Server)** ⚠️

**Why This is Good:**
- ✅ **Full control**
- ✅ **No hosting fees**

**Limitations:**
- ❌ Requires server setup
- ❌ Requires domain name
- ❌ Requires SSL certificate
- ❌ More technical knowledge needed

**Best For:** If you have your own server

---

## 🚀 **Recommended: Railway (Easiest Setup)**

### **Step-by-Step: Deploy Backend to Railway**

### **Step 1: Prepare Backend for Deployment**

1. **Create GitHub repository** (if not already created):
   - Go to [github.com](https://github.com)
   - Create new repository: `central360-backend`
   - Upload your backend code

2. **Update `.env` file**:
   - Railway will set environment variables
   - Don't commit `.env` file (add to `.gitignore`)

3. **Check `package.json`**:
   - Make sure you have a `start` script:
     ```json
     "scripts": {
       "start": "node src/server.js",
       "dev": "nodemon src/server.js"
     }
     ```

### **Step 2: Deploy to Railway**

1. **Sign up at Railway**:
   - Go to [railway.app](https://railway.app)
   - Click **"Start a New Project"**
   - Sign up with GitHub account (easiest)

2. **Create New Project**:
   - Click **"New Project"**
   - Select **"Deploy from GitHub repo"**
   - Select your `central360-backend` repository

3. **Add PostgreSQL Database**:
   - Click **"+ New"** → **"Database"** → **"Add PostgreSQL"**
   - Railway automatically creates database
   - Copy connection URL (you'll need this)

4. **Set Environment Variables**:
   - Click on your service → **"Variables"** tab
   - Add these variables:
     ```
     DATABASE_URL=<PostgreSQL connection URL from Railway>
     JWT_SECRET=<your-secret-key>
     PORT=3000
     NODE_ENV=production
     
     # Email (optional - for PDF email feature)
     SMTP_HOST=smtp.gmail.com
     SMTP_PORT=587
     SMTP_SECURE=false
     SMTP_USER=your-email@gmail.com
     SMTP_PASSWORD=your-app-password
     ```
   - Click **"Add"** for each variable

5. **Deploy**:
   - Railway automatically deploys from GitHub
   - Wait for deployment to complete (5-10 minutes)
   - Check logs for any errors

6. **Get Production URL**:
   - Click on your service → **"Settings"** tab
   - Scroll to **"Domains"** section
   - Click **"Generate Domain"**
   - Your production URL: `https://your-app-name.up.railway.app`
   - Or add custom domain: `https://api.central360.com`

**Your Production API URL:**
```
https://your-app-name.up.railway.app/api/v1
```

**Done!** ✅

---

## 📋 **Alternative: Render (Free Tier)**

### **Step-by-Step: Deploy Backend to Render**

1. **Sign up at Render**:
   - Go to [render.com](https://render.com)
   - Sign up with GitHub account

2. **Create New Web Service**:
   - Click **"New +"** → **"Web Service"**
   - Connect GitHub repository
   - Select your `central360-backend` repository

3. **Configure Service**:
   - **Name**: `central360-backend`
   - **Root Directory**: `backend` (if repo has frontend/backend folders)
   - **Build Command**: `npm install`
   - **Start Command**: `npm start`
   - **Environment**: `Node`

4. **Add PostgreSQL Database**:
   - Click **"New +"** → **"PostgreSQL"**
   - Create database
   - Copy connection URL

5. **Set Environment Variables**:
   - In service settings → **"Environment"** tab
   - Add variables:
     ```
     DATABASE_URL=<PostgreSQL connection URL from Render>
     JWT_SECRET=<your-secret-key>
     NODE_ENV=production
     ```

6. **Deploy**:
   - Click **"Create Web Service"**
   - Wait for deployment
   - Get production URL: `https://central360-backend.onrender.com`

**Your Production API URL:**
```
https://central360-backend.onrender.com/api/v1
```

---

## 🔧 **After Deployment - Update Database Schema**

Once deployed, you need to run database migrations:

### **Option A: Connect via Railway/Render Console**

1. Open Railway/Render dashboard
2. Connect to database console
3. Run SQL from `backend/src/migrations/001_complete_schema.sql`
4. Run SQL from `backend/src/migrations/002_default_data.sql` (if needed)

### **Option B: Run Migrations via Node.js**

1. Update `DATABASE_URL` in environment variables
2. Create migration script to run migrations
3. Run script from deployment platform

---

## ✅ **Testing Production API**

After deployment, test your API:

```bash
# Test health endpoint
curl https://your-api-url.com/api/health

# Should return: {"status":"ok"}
```

Test other endpoints:
- Login: `POST /api/v1/auth/login`
- Get employees: `GET /api/v1/employees`
- etc.

---

## 📝 **Quick Deployment Checklist**

**Before Deployment:**
- [ ] Backend code is on GitHub
- [ ] `package.json` has `start` script
- [ ] `.env` file is in `.gitignore`
- [ ] Database migrations are ready

**Deployment Steps:**
- [ ] Sign up at Railway/Render
- [ ] Connect GitHub repository
- [ ] Create PostgreSQL database
- [ ] Set environment variables
- [ ] Deploy service
- [ ] Get production URL
- [ ] Test API endpoints
- [ ] Run database migrations

**After Deployment:**
- [ ] Copy production API URL
- [ ] Build app with production URL
- [ ] Test app with production API
- [ ] Deploy app files to GitHub Releases

---

## 🎯 **My Recommendation**

**For Easiest Setup: Use Railway** ⭐⭐⭐

**Why:**
- ✅ Easiest to set up
- ✅ Automatic deployments
- ✅ PostgreSQL included
- ✅ HTTPS included
- ✅ Free tier available
- ✅ Reliable

**Steps:**
1. Sign up at Railway
2. Deploy from GitHub
3. Get production URL
4. Build app with production URL
5. Done! ✅

---

## 📞 **Need Help?**

**Common Issues:**

1. **Deployment fails?**
   - Check logs in Railway/Render dashboard
   - Make sure `package.json` has correct scripts
   - Check environment variables are set

2. **Database connection error?**
   - Check `DATABASE_URL` environment variable
   - Make sure PostgreSQL service is running
   - Run database migrations

3. **API not working?**
   - Check API URL in browser
   - Test with `curl` or Postman
   - Check server logs

**Let me know if you need help with any step!**

