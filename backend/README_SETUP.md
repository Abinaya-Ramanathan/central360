# Backend Setup Instructions

## Database Setup

1. Make sure PostgreSQL is running and accessible.

2. Create the database:
```sql
CREATE DATABASE central360;
```

3. Run the migrations to create tables and insert default data:
```bash
# Run the complete schema migration
psql -U your_username -d central360 -f src/migrations/001_complete_schema.sql

# Run the default data migration
psql -U your_username -d central360 -f src/migrations/002_default_data.sql
```

**Note**: The migrations have been consolidated from 27 files into 2 files:
- `001_complete_schema.sql` - Contains all tables in their final state
- `002_default_data.sql` - Contains all default data (sectors and products)

The old migration files (001-027) have been moved to `src/migrations/archive/` for reference but are no longer needed for new installations.

Or manually run the SQL from the migration files in your PostgreSQL client.

## Environment Variables

Create a `.env` file in the backend directory with the following variables:

### Database Configuration (choose one method):

**Option 1: Individual Parameters (Recommended if password has special characters)**
```env
DB_HOST=localhost
DB_PORT=5432
DB_USER=your_username
DB_PASSWORD=your_password
DB_NAME=central360
```

**Option 2: Connection String**
```env
DATABASE_URL=postgres://user:password@localhost:5432/central360
```
⚠️ **Note**: If your password contains special characters (`@`, `:`, `/`, `#`, `%`, etc.), you must URL-encode them or use Option 1 instead.
- Example: `password@123` → `password%40123`
- Example: `pass:word` → `pass%3Aword`

### Email Configuration (Required for PDF email functionality):
```env
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_SECURE=false
SMTP_USER=your-email@gmail.com
SMTP_PASSWORD=your-app-password
```

**Note for Gmail users:**
- You need to use an "App Password" instead of your regular Gmail password
- Enable 2-Step Verification on your Google Account
- Generate an App Password: https://myaccount.google.com/apppasswords
- Use the generated 16-character app password as `SMTP_PASSWORD`

**For other email providers:**
- Update `SMTP_HOST` to your provider's SMTP server
- Update `SMTP_PORT` (587 for TLS, 465 for SSL)
- Set `SMTP_SECURE=true` for port 465 (SSL), `false` for port 587 (TLS)

### Other Required Variables:
- `JWT_SECRET`: A secret key for JWT tokens
- `JWT_EXPIRES_IN`: Token expiration (default: `1d`)
- `PORT`: Server port (optional, defaults to `4000`)

## Starting the Server

```bash
npm install
npm run dev
```

The server will run on `http://localhost:4000` (or the port specified in your config).

## API Endpoints

- `GET /api/v1/employees` - Get all employees
- `GET /api/v1/employees/sector/:code` - Get employees by sector
- `POST /api/v1/employees` - Create employee
- `PUT /api/v1/employees/:id` - Update employee
- `DELETE /api/v1/employees/:id` - Delete employee

- `GET /api/v1/sectors` - Get all sectors
- `POST /api/v1/sectors` - Create sector
- `DELETE /api/v1/sectors/:code` - Delete sector

- `GET /api/v1/attendance` - Get attendance records (query params: sector, month, date)
- `GET /api/v1/attendance/outstanding/:employeeId/:date` - Get latest outstanding advance for employee before date
- `POST /api/v1/attendance` - Create/update attendance record
- `POST /api/v1/attendance/bulk` - Bulk create/update attendance records

- `GET /api/v1/salary-expenses` - Get salary expense records (query params: sector, week_start, week_end, employee_id)
- `POST /api/v1/salary-expenses` - Create/update salary expense record
- `POST /api/v1/salary-expenses/bulk` - Bulk create/update salary expense records
- `DELETE /api/v1/salary-expenses/:id` - Delete salary expense record

- `GET /api/v1/daily-production` - Get daily production records (query params: month, date)
- `POST /api/v1/daily-production` - Create/update daily production record
- `DELETE /api/v1/daily-production/:id` - Delete daily production record

- `GET /api/v1/products` - Get products (query params: sector)
- `POST /api/v1/products` - Create product
- `PUT /api/v1/products/:id` - Update product
- `DELETE /api/v1/products/:id` - Delete product

- `GET /api/v1/daily-expenses` - Get daily expense records (query params: month, date)
- `POST /api/v1/daily-expenses` - Create/update daily expense record
- `DELETE /api/v1/daily-expenses/:id` - Delete daily expense record

- `GET /api/v1/maintenance-issues` - Get maintenance issues (query params: sector)
- `POST /api/v1/maintenance-issues` - Create/update maintenance issue
- `DELETE /api/v1/maintenance-issues/:id` - Delete maintenance issue

- `GET /api/v1/mahal-bookings` - Get event details (query params: sector)
- `POST /api/v1/mahal-bookings` - Create/update event details
- `DELETE /api/v1/mahal-bookings/:booking_id` - Delete event details

- `GET /api/v1/billing-details` - Get billing details (query params: booking_id)
- `POST /api/v1/billing-details` - Create/update billing details
- `DELETE /api/v1/billing-details/:booking_id` - Delete billing details

- `GET /api/v1/catering-details` - Get catering details (query params: booking_id)
- `POST /api/v1/catering-details` - Create/update catering details
- `DELETE /api/v1/catering-details/:booking_id` - Delete catering details

- `GET /api/v1/expense-details` - Get expense details (query params: booking_id)
- `POST /api/v1/expense-details` - Create/update expense details
- `DELETE /api/v1/expense-details/:booking_id` - Delete expense details

- `GET /api/v1/credit-details` - Get credit details (query params: sector, date, month)
- `POST /api/v1/credit-details` - Create/update credit details
- `DELETE /api/v1/credit-details/:id` - Delete credit details

## Notes

- Sectors are now stored in the database (no hardcoded sectors)
- All data persists across server restarts
- The frontend connects to `http://localhost:3000` by default (update in `api_service.dart` if needed)

