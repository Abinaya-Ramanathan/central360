# Railway Deployment Guide for Company360 Backend

## Prerequisites
- Railway account (sign up at https://railway.app)
- GitHub repository with your backend code
- Railway CLI (optional, but helpful)

## Step-by-Step Deployment

### Option 1: Deploy via Railway Dashboard (Recommended)

1. **Push your code to GitHub**
   ```bash
   cd F:\central360
   git add .
   git commit -m "Update version to 1.0.4 for Windows and Android"
   git push origin main
   ```

2. **Login to Railway**
   - Go to https://railway.app
   - Sign in with your GitHub account

3. **Create a New Project**
   - Click "New Project"
   - Select "Deploy from GitHub repo"
   - Choose your `central360` repository
   - Railway will detect it's a Node.js project

4. **Configure the Service**
   - Railway should auto-detect the backend folder
   - If not, set the **Root Directory** to `backend`
   - Set the **Start Command** to `npm start` (should be auto-detected)

5. **Set Environment Variables**
   - Go to your service → Variables tab
   - Add all required environment variables:
     - `DATABASE_URL` (PostgreSQL connection string)
     - `JWT_SECRET` (your JWT secret key)
     - `PORT` (optional, Railway sets this automatically)
     - Any other env vars your app needs

6. **Add PostgreSQL Database (if not already added)**
   - Click "New" → "Database" → "Add PostgreSQL"
   - Railway will automatically create a `DATABASE_URL` variable
   - Run your migrations after deployment

7. **Deploy**
   - Railway will automatically deploy when you push to GitHub
   - Or click "Deploy" to trigger a manual deployment
   - Wait for the build to complete

8. **Get Your Backend URL**
   - After deployment, Railway will provide a public URL
   - Example: `https://your-app-name.up.railway.app`
   - Update your frontend `EnvConfig` to use this URL

### Option 2: Deploy via Railway CLI

1. **Install Railway CLI**
   ```bash
   npm install -g @railway/cli
   ```

2. **Login to Railway**
   ```bash
   railway login
   ```

3. **Initialize Railway in your project**
   ```bash
   cd F:\central360\backend
   railway init
   ```

4. **Link to existing project (if you have one)**
   ```bash
   railway link
   ```

5. **Set environment variables**
   ```bash
   railway variables set DATABASE_URL="your-database-url"
   railway variables set JWT_SECRET="your-jwt-secret"
   ```

6. **Deploy**
   ```bash
   railway up
   ```

## Verify Deployment

After deployment, test the version endpoint:

```bash
curl https://your-railway-url.up.railway.app/api/v1/app/version
```

Expected response:
```json
{
  "version": "1.0.4",
  "buildNumber": "5",
  "platforms": {
    "windows": {
      "downloadUrl": "https://github.com/Abinaya-Ramanathan/central360/releases/download/v1.0.4/Company360-Setup.exe",
      "isRequired": false
    },
    "android": {
      "downloadUrl": "https://github.com/Abinaya-Ramanathan/central360/releases/download/v1.0.4/company360-v1.0.4.apk",
      "isRequired": false
    }
  },
  "releaseNotes": "Added search functionality in Production tab, improved Android update installation",
  "isRequired": false,
  "releaseDate": "2025-11-26T00:00:00Z"
}
```

## Update Frontend Configuration

After deployment, update your frontend's API base URL:

1. Find your `EnvConfig` file (usually in `frontend/lib/config/env_config.dart`)
2. Update the `apiBaseUrl` to your Railway URL:
   ```dart
   static const String apiBaseUrl = 'https://your-railway-url.up.railway.app';
   ```
3. Rebuild your frontend apps

## Troubleshooting

### Build Fails
- Check Railway logs for errors
- Ensure `package.json` has correct `start` script
- Verify Node.js version compatibility

### Database Connection Issues
- Verify `DATABASE_URL` is set correctly
- Check if database is provisioned and running
- Run migrations: `node src/migrations/run_migration.js`

### API Not Responding
- Check service logs in Railway dashboard
- Verify the service is running (not paused)
- Check if port is correctly configured

### Version Endpoint Returns Old Version
- Verify `backend/src/routes/app.routes.js` has version `1.0.4`
- Clear Railway build cache and redeploy
- Check if deployment completed successfully

## Continuous Deployment

Railway automatically deploys when you push to your main branch. To update the version:

1. Update `backend/src/routes/app.routes.js` with new version
2. Commit and push to GitHub
3. Railway will automatically rebuild and deploy

## Important Notes

- **Both Windows and Android URLs** are configured in `app.routes.js`
- The endpoint returns platform-specific URLs based on the request
- Make sure GitHub releases exist for the version numbers you specify
- Update version numbers in both `app.routes.js` and `frontend/pubspec.yaml` when releasing

