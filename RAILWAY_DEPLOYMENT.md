# Railway Deployment - Step by Step

## Prerequisites

1. **Railway Account** - Sign up at https://railway.app (free tier available)
2. **GitHub Repository** - Your code should be on GitHub (see GITHUB_SETUP.md)

## Step 1: Create Railway Project

1. Go to https://railway.app
2. Click **"New Project"**
3. Select **"Deploy from GitHub repo"**
4. Authorize Railway to access your GitHub account
5. Select your `company360` repository
6. Click **"Deploy Now"**

## Step 2: Configure Backend Service

1. Railway will detect Node.js automatically
2. **Set Root Directory:**
   - Click on your service
   - Go to **Settings** tab
   - Set **Root Directory** to: `backend`
   - Click **Save**

## Step 3: Add PostgreSQL Database

1. In your Railway project, click **"+ New"**
2. Select **"Database"** → **"Add PostgreSQL"**
3. Railway will automatically:
   - Create the database
   - Provide `DATABASE_URL` environment variable
   - Link it to your backend service

## Step 4: Set Environment Variables

1. Click on your backend service
2. Go to **Variables** tab
3. Click **"+ New Variable"**
4. Add these variables:

```
NODE_ENV=production
PORT=4000
JWT_SECRET=your-super-secret-jwt-key-change-this-to-random-string
JWT_EXPIRES_IN=7d
```

**Important:** 
- `DATABASE_URL` is automatically provided by Railway (don't add it manually)
- Use a strong, random string for `JWT_SECRET`

## Step 5: Deploy

1. Railway will automatically deploy when you:
   - Push code to GitHub
   - Add environment variables
   - Make changes to the service

2. **Monitor Deployment:**
   - Go to **Deployments** tab
   - Watch the build logs
   - Wait for "Deploy Succeeded"

## Step 6: Get Your API URL

1. After successful deployment, go to **Settings** tab
2. Under **Networking**, you'll see:
   - **Public Domain** (e.g., `your-app.railway.app`)
   - Or click **"Generate Domain"** to create one

3. **Your API URL will be:**
   ```
   https://your-app.railway.app/api/v1
   ```

4. **Test your API:**
   ```
   https://your-app.railway.app/api/v1/health
   ```
   (You may need to add a health check endpoint)

## Step 7: Update Frontend Build

Now build your frontend with the Railway API URL:

```powershell
cd F:\central360\frontend
flutter build windows --release --dart-define=API_BASE_URL=https://your-app.railway.app
```

Then create the installer in Inno Setup.

## Troubleshooting

### Database Connection Issues
- Check that PostgreSQL service is running
- Verify `DATABASE_URL` is automatically set (don't set it manually)
- Check Railway logs for connection errors

### Deployment Fails
- Check **Deployments** tab → View logs
- Ensure `package.json` has `start` script
- Verify all environment variables are set

### API Not Accessible
- Check **Settings** → **Networking** → Public domain is set
- Verify service is running (green status)
- Check Railway logs for errors

## Environment Variables Reference

| Variable | Required | Description | Example |
|----------|----------|-------------|---------|
| `DATABASE_URL` | ✅ Auto | PostgreSQL connection (auto-provided) | `postgresql://...` |
| `NODE_ENV` | ✅ | Environment mode | `production` |
| `PORT` | ✅ | Server port | `4000` |
| `JWT_SECRET` | ✅ | Secret for JWT tokens | `random-secret-string` |
| `JWT_EXPIRES_IN` | ❌ | Token expiration | `7d` |

## Monitoring

- **Logs:** Railway Dashboard → Your Service → **Logs** tab
- **Metrics:** Railway Dashboard → Your Service → **Metrics** tab
- **Deployments:** Railway Dashboard → **Deployments** tab

## Free Tier Limits

Railway free tier includes:
- $5 credit per month
- 500 hours of usage
- Sufficient for small to medium apps

---

**Your Railway API URL:** `https://your-app.railway.app`

**Your API Endpoint:** `https://your-app.railway.app/api/v1`

