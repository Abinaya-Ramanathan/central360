# How to Run Migration 048 on Railway Database

This migration adds the `ot_hours` column to the `attendance` table.

## Option 1: Using Railway Dashboard (Easiest)

1. Go to your Railway project dashboard: https://railway.app
2. Click on your PostgreSQL database service
3. Click on the "Data" tab or "Query" tab
4. Copy and paste the SQL from `src/migrations/048_add_ot_hours_to_attendance_standalone.sql`
5. Click "Run" or "Execute"
6. Verify the column was added by running:
   ```sql
   SELECT column_name, data_type 
   FROM information_schema.columns 
   WHERE table_name = 'attendance' AND column_name = 'ot_hours';
   ```

## Option 2: Using Railway CLI

1. Install Railway CLI (if not already installed):
   ```bash
   npm install -g @railway/cli
   ```

2. Login to Railway:
   ```bash
   railway login
   ```

3. Link to your project:
   ```bash
   railway link
   ```

4. Connect to your database:
   ```bash
   railway connect
   ```

5. Once connected, run the migration:
   ```bash
   psql $DATABASE_URL -f src/migrations/048_add_ot_hours_to_attendance_standalone.sql
   ```

## Option 3: Using psql Directly

If you have the database connection string:

```bash
psql "your-database-url-here" -f src/migrations/048_add_ot_hours_to_attendance_standalone.sql
```

## Option 4: Run SQL Directly via Railway CLI

```bash
railway run psql $DATABASE_URL -c "ALTER TABLE attendance ADD COLUMN IF NOT EXISTS ot_hours DECIMAL(10, 2) DEFAULT 0;"
```

## Verify Migration

After running the migration, verify it worked:

```sql
SELECT column_name, data_type, column_default
FROM information_schema.columns
WHERE table_name = 'attendance' AND column_name = 'ot_hours';
```

You should see:
- column_name: ot_hours
- data_type: numeric
- column_default: 0

## Troubleshooting

If you get an error that the column already exists, that's fine - the migration is idempotent and safe to run multiple times.

If you get permission errors, make sure you're using the correct database user with ALTER TABLE permissions.

