# Backend Setup Guide - Step by Step

## Step 1: Install Required Software

### 1.1 Install Node.js
- **Download**: Go to https://nodejs.org/
- **Version**: Download the LTS (Long Term Support) version
- **Install**: Run the installer and follow the instructions
- **Verify**: Open PowerShell and run:
  ```powershell
  node --version
  npm --version
  ```
  You should see version numbers (e.g., v20.x.x and 10.x.x)

### 1.2 Install PostgreSQL
- **Download**: Go to https://www.postgresql.org/download/windows/
- **Install**: Run the installer
  - **Important**: Remember the password you set for the `postgres` user (you'll need it later)
  - **Port**: Keep default port 5432
  - **Install pgAdmin**: Make sure to check "pgAdmin 4" during installation
- **Verify**: PostgreSQL should be running as a Windows service

### 1.3 pgAdmin (Already included with PostgreSQL)
- pgAdmin should be installed automatically with PostgreSQL
- You can find it in Start Menu → pgAdmin 4

---

## Step 2: Set Up PostgreSQL Database

### 2.1 Open pgAdmin
1. Open **pgAdmin 4** from Start Menu
2. Enter your PostgreSQL password (the one you set during installation)
3. You'll see your PostgreSQL server in the left panel

### 2.2 Create the Database
1. Expand your PostgreSQL server (usually named "PostgreSQL 15" or similar)
2. Right-click on **"Databases"** → **"Create"** → **"Database..."**
3. In the dialog:
   - **Database name**: `central360`
   - Click **"Save"**

### 2.3 Run the Migration (Create Tables)
1. Expand **"Databases"** → expand **"central360"**
2. Right-click on **"central360"** → **"Query Tool"**
3. In the Query Tool:
   - Click the **"Open File"** icon (folder icon) at the top
   - Navigate to: `F:\central360\backend\src\migrations\001_initial_schema.sql`
   - Or copy-paste the SQL content from that file
4. Click the **"Execute"** button (play icon) or press **F5**
5. You should see: **"Query returned successfully"**

### 2.4 Verify Tables Created
1. In pgAdmin, expand: **central360** → **Schemas** → **public** → **Tables**
2. You should see 3 tables:
   - `attendance`
   - `employees`
   - `sectors`

---

## Step 3: Configure Backend Environment

### 3.1 Create .env File
1. Navigate to: `F:\central360\backend\`
2. Copy `env.example` and rename it to `.env`
3. Open `.env` in a text editor

### 3.2 Fill in .env File
Replace the placeholders with your actual values:

```env
# PostgreSQL Connection
# Format: postgres://USERNAME:PASSWORD@localhost:5432/central360
DATABASE_URL=postgres://postgres:YOUR_PASSWORD@localhost:5432/central360

# JWT Secret (use any random string)
JWT_SECRET=your-super-secret-key-change-this-in-production

# JWT Expiration
JWT_EXPIRES_IN=1d

# Server Port
PORT=3000
```

**Important**: 
- Replace `YOUR_PASSWORD` with the PostgreSQL password you set during installation
- If your PostgreSQL username is not `postgres`, replace it in the DATABASE_URL

### 3.3 Find Your PostgreSQL Username/Password
- **Username**: Usually `postgres` (default)
- **Password**: The one you set during PostgreSQL installation
- If you forgot, you can reset it in pgAdmin or reinstall PostgreSQL

---

## Step 4: Install Backend Dependencies

1. Open PowerShell
2. Navigate to backend folder:
   ```powershell
   cd F:\central360\backend
   ```
3. Install dependencies:
   ```powershell
   npm install
   ```
4. Wait for installation to complete (this may take a few minutes)

---

## Step 5: Start the Backend Server

1. Make sure you're in the backend folder:
   ```powershell
   cd F:\central360\backend
   ```
2. Start the server:
   ```powershell
   npm run dev
   ```
3. You should see:
   ```
   Server running on port 3000
   ```
   (or whatever port you set in .env)

4. **Keep this terminal open** - the server needs to keep running

---

## Step 6: Test the Backend

### 6.1 Test Health Endpoint
Open a browser and go to:
```
http://localhost:3000/api/health
```
You should see: `{"status":"ok"}`

### 6.2 Test API Endpoints
You can test these URLs in your browser:
- `http://localhost:3000/api/v1/sectors` - Should return `[]` (empty array, no sectors yet)
- `http://localhost:3000/api/v1/employees` - Should return `[]` (empty array, no employees yet)

---

## Step 7: View Data in pgAdmin

### 7.1 View Tables
1. In pgAdmin, expand: **central360** → **Schemas** → **public** → **Tables**
2. Right-click on any table (e.g., `sectors`) → **"View/Edit Data"** → **"All Rows"**
3. You'll see the table data in a grid view

### 7.2 Query Data
1. Right-click on **central360** → **"Query Tool"**
2. Type a SQL query, for example:
   ```sql
   SELECT * FROM sectors;
   SELECT * FROM employees;
   SELECT * FROM attendance;
   ```
3. Click **Execute** (F5) to see results

### 7.3 Add Test Data
You can manually add test data in pgAdmin:
1. Right-click on a table → **"View/Edit Data"** → **"All Rows"**
2. Click the **"+"** icon to add a new row
3. Fill in the data and save

Or use Query Tool to insert:
```sql
-- Add a test sector
INSERT INTO sectors (code, name) VALUES ('TEST', 'Test Sector');

-- View it
SELECT * FROM sectors;
```

---

## Troubleshooting

### Problem: "Cannot connect to database"
- **Solution**: Check your `.env` file - make sure DATABASE_URL is correct
- Verify PostgreSQL is running (check Windows Services)

### Problem: "Port already in use"
- **Solution**: Change PORT in `.env` to a different number (e.g., 3001, 4000)

### Problem: "Module not found"
- **Solution**: Run `npm install` again in the backend folder

### Problem: "Password authentication failed"
- **Solution**: Check your PostgreSQL password in `.env` file
- You can reset password in pgAdmin: Right-click server → Properties → Change Password

---

## Next Steps

Once backend is running:
1. Start the Flutter frontend (it will connect to `http://localhost:3000`)
2. Add sectors through the app
3. Add employees through the app
4. View all data in pgAdmin

---

## Quick Reference Commands

```powershell
# Navigate to backend
cd F:\central360\backend

# Install dependencies
npm install

# Start server (development mode with auto-reload)
npm run dev

# Start server (production mode)
npm start
```

