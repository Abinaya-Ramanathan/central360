# Troubleshooting "Error fetching sectors"

## Step 1: Check Server Terminal Output

The actual error message will be in the terminal where you ran `npm run dev`. Look for error messages like:
- "password authentication failed"
- "database does not exist"
- "relation 'sectors' does not exist"
- "connection refused"

## Step 2: Verify Database Connection

### Check your .env file:
1. Open `F:\central360\backend\.env`
2. Verify DATABASE_URL format:
   ```
   DATABASE_URL=postgres://USERNAME:PASSWORD@localhost:5432/central360
   ```
3. Make sure:
   - `USERNAME` is your PostgreSQL username (usually `postgres`)
   - `PASSWORD` is your PostgreSQL password
   - `central360` is the database name

### Test Database Connection in pgAdmin:
1. Open pgAdmin
2. Try to connect to your PostgreSQL server
3. If connection fails, your password might be wrong

## Step 3: Verify Database and Tables Exist

### In pgAdmin:
1. Expand: **Servers** → **PostgreSQL** → **Databases**
2. Check if `central360` database exists
3. If not, create it:
   - Right-click "Databases" → Create → Database
   - Name: `central360`

### Check if Tables Exist:
1. Expand: **central360** → **Schemas** → **public** → **Tables**
2. You should see 3 tables:
   - `sectors`
   - `employees`
   - `attendance`
3. If tables don't exist, run the migration:
   - Right-click `central360` → Query Tool
   - Open file: `F:\central360\backend\src\migrations\001_initial_schema.sql`
   - Execute (F5)

## Step 4: Test Database Connection Manually

### Option A: Test in pgAdmin Query Tool
1. Right-click `central360` → Query Tool
2. Run:
   ```sql
   SELECT * FROM sectors;
   ```
3. If this works, the database is fine
4. If you get an error, the table doesn't exist - run the migration

### Option B: Test Connection String
Create a test file `test-db.js` in backend folder:
```javascript
import dotenv from 'dotenv';
dotenv.config();
import pkg from 'pg';
const { Pool } = pkg;

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
});

pool.query('SELECT NOW()', (err, res) => {
  if (err) {
    console.error('Connection error:', err.message);
  } else {
    console.log('Database connected! Current time:', res.rows[0].now);
  }
  pool.end();
});
```

Run: `node test-db.js`

## Step 5: Common Issues and Solutions

### Issue: "password authentication failed"
**Solution**: 
- Check your PostgreSQL password in `.env`
- Reset password in pgAdmin: Right-click server → Properties → Change Password

### Issue: "database 'central360' does not exist"
**Solution**: 
- Create the database in pgAdmin
- Or update DATABASE_URL to use an existing database

### Issue: "relation 'sectors' does not exist"
**Solution**: 
- Run the migration SQL file in pgAdmin
- File: `backend/src/migrations/001_initial_schema.sql`

### Issue: "connection refused"
**Solution**: 
- Make sure PostgreSQL service is running
- Check Windows Services → PostgreSQL
- Start the service if it's stopped

### Issue: Port 4000 already in use
**Solution**: 
- Change PORT in `.env` to a different number (e.g., 3000, 5000)
- Restart the server

## Step 6: Quick Fix Checklist

1. ✅ PostgreSQL is installed and running
2. ✅ Database `central360` exists in pgAdmin
3. ✅ Tables (`sectors`, `employees`, `attendance`) exist
4. ✅ `.env` file exists in `backend` folder
5. ✅ DATABASE_URL in `.env` is correct
6. ✅ Server is running (`npm run dev`)
7. ✅ Check terminal output for actual error message

## Step 7: Get Detailed Error

Add better error logging. Update `backend/src/routes/sectors.routes.js`:

```javascript
router.get('/', async (req, res) => {
  try {
    const { rows } = await db.query('SELECT * FROM sectors ORDER BY code');
    res.json(rows);
  } catch (err) {
    console.error('Sector fetch error:', err.message);
    console.error('Full error:', err);
    res.status(500).json({ 
      message: 'Error fetching sectors',
      error: err.message  // Add this to see actual error
    });
  }
});
```

Then check the browser - you'll see the actual error message.

