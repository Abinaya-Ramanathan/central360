# Troubleshooting Deployment Issues

## Issue: Data Not Being Added / Employee Creation Error

### Symptoms
- Error when creating employee
- Data not getting added in other pages
- API calls failing silently

### Root Causes & Fixes

#### 1. Missing Field in Backend Route
**Problem:** Backend route doesn't extract all fields from request body.

**Fix:** Ensure all fields are destructured in the route handler:
```javascript
const {
  name,
  contact,
  contact2,  // ← Make sure all fields are included
  address,
  // ... other fields
} = req.body;
```

#### 2. Frontend Not Sending All Fields
**Problem:** Frontend dialog/form not including all fields when creating object.

**Fix:** Ensure all form fields are included when creating the model:
```dart
final employee = Employee(
  name: _nameController.text.trim(),
  contact: _contactController.text.trim(),
  contact2: _contact2Controller.text.trim(),  // ← Include all fields
  // ... other fields
);
```

#### 3. Database Connection Issues
**Check Railway Logs:**
1. Go to Railway Dashboard
2. Select your backend service
3. Click **"Logs"** tab
4. Look for database connection errors

**Common Issues:**
- `DATABASE_URL` not set (should be auto-provided by Railway PostgreSQL)
- Database migrations not run
- Connection timeout

#### 4. CORS Issues
**Check:** Backend `server.js` should have:
```javascript
app.use(cors());  // Allow all origins
```

#### 5. API URL Mismatch
**Check Frontend:**
- Verify `API_BASE_URL` is set correctly in build
- Check `env_config.dart` for correct base URL
- Ensure Railway URL is accessible

### Quick Debugging Steps

1. **Check Railway Logs:**
   ```bash
   # In Railway Dashboard → Logs
   # Look for error messages
   ```

2. **Test API Directly:**
   ```bash
   # Test health endpoint
   curl https://your-app.railway.app/api/health
   
   # Test employee creation
   curl -X POST https://your-app.railway.app/api/v1/employees \
     -H "Content-Type: application/json" \
     -d '{"name":"Test","contact":"123","sector":"SSEW"}'
   ```

3. **Check Frontend Console:**
   - Open browser DevTools (F12)
   - Check Network tab for failed requests
   - Check Console for error messages

4. **Verify Database:**
   - Check Railway PostgreSQL service is running
   - Verify migrations ran successfully
   - Check if tables exist

### Common Error Messages

#### "Error creating employee"
- **Cause:** Missing field in backend destructuring
- **Fix:** Add missing field to `req.body` destructuring

#### "Sector does not exist"
- **Cause:** Sector not created in database
- **Fix:** Create sector first before adding employee

#### "Failed to load employees"
- **Cause:** Database connection issue or table doesn't exist
- **Fix:** Check Railway logs, verify migrations ran

#### Network errors (CORS, timeout)
- **Cause:** Backend not accessible or CORS misconfigured
- **Fix:** Check Railway deployment, verify CORS settings

### After Fixing

1. **Commit and Push:**
   ```powershell
   git add .
   git commit -m "Fix: Add missing contact2 field to employee routes"
   git push
   ```

2. **Railway Auto-Deploys:**
   - Railway will automatically redeploy on push
   - Wait for deployment to complete
   - Check logs for errors

3. **Rebuild Frontend (if needed):**
   ```powershell
   cd frontend
   flutter build windows --release --dart-define=API_BASE_URL=https://your-app.railway.app
   ```

4. **Test Again:**
   - Try creating employee
   - Check if data appears in list
   - Verify in database if needed

---

## Need More Help?

1. Check Railway deployment logs
2. Check browser console for frontend errors
3. Test API endpoints directly with curl/Postman
4. Verify database schema matches code expectations

