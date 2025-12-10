# Daily Income and Expense Feature

## Overview
Added a new "Daily Income and Expense Details" section to the Home page that allows users to track daily income and expenses by sector and date.

## Features Implemented

### 1. Database Table ✅
- **Table**: `daily_income_expense`
- **Migration**: `backend/src/migrations/053_create_daily_income_expense.sql`
- **Columns**:
  - `id` (Primary Key)
  - `sector_code` (Foreign Key to sectors)
  - `item_name` (Optional)
  - `quantity` (Optional)
  - `income_amount` (Decimal, default 0)
  - `expense_amount` (Decimal, default 0)
  - `entry_date` (Date, required)
  - `created_at`, `updated_at` (Timestamps)

### 2. Backend API ✅
- **Route**: `/api/v1/daily-income-expense`
- **File**: `backend/src/routes/daily_income_expense.routes.js`
- **Endpoints**:
  - `GET /` - Get records by sector and date
  - `POST /` - Create or update record
  - `DELETE /:id` - Delete record (only for main admin)

### 3. Frontend UI ✅
- **Location**: Home Screen (`frontend/lib/screens/home_screen.dart`)
- **Features**:
  - Table with columns: Item Name, Quantity, Income, Expense, Action
  - Date picker to select entry date
  - Add Income/Expense Item button
  - Edit/Save functionality (inline editing)
  - Delete button (only visible for "abinaya" login - main admin)
  - Total row showing sum of Income and Expense columns
  - All fields are non-mandatory

### 4. Sector and Date Specificity ✅
- Data is filtered by selected sector
- Data is filtered by selected date
- Each date requires separate entries
- Changing date reloads data for that date

## How to Use

### For Users:
1. Select a sector from the dropdown
2. Select a date using the date picker
3. Click "Add Income/Expense Item" to add new entries
4. Click Edit icon to modify existing entries
5. Click Save icon to save changes
6. Click Delete icon (only for abinaya login) to remove entries

### For Developers:

#### 1. Run Database Migration
```sql
-- Connect to PostgreSQL and run:
\i backend/src/migrations/053_create_daily_income_expense.sql
```

#### 2. Restart Backend Server
The route is already registered in `backend/src/server.js`

#### 3. Test the Feature
- Navigate to Home page
- Select a sector
- The Daily Income and Expense section will appear
- Test adding, editing, and deleting entries

## API Usage Examples

### Get Records
```javascript
GET /api/v1/daily-income-expense?sector=SSBM&date=2025-01-28
```

### Create/Update Record
```javascript
POST /api/v1/daily-income-expense
{
  "sector_code": "SSBM",
  "item_name": "Product Sale",
  "quantity": "10",
  "income_amount": 5000.00,
  "expense_amount": 0,
  "entry_date": "2025-01-28"
}
```

### Delete Record
```javascript
DELETE /api/v1/daily-income-expense/:id
```

## Security
- Delete functionality is restricted to main admin (password: "abinaya")
- All other users can add and edit entries
- Data is sector-specific (users can only see their sector's data)

## Database Indexes
Performance indexes added:
- `idx_daily_income_expense_sector` - For sector filtering
- `idx_daily_income_expense_date` - For date filtering
- `idx_daily_income_expense_sector_date` - Composite index for common queries

## Files Modified/Created

### Backend:
1. `backend/src/migrations/053_create_daily_income_expense.sql` - New migration
2. `backend/src/routes/daily_income_expense.routes.js` - New route file
3. `backend/src/server.js` - Added route registration

### Frontend:
1. `frontend/lib/screens/home_screen.dart` - Added UI component
2. `frontend/lib/services/api_service.dart` - Added API methods

## Notes
- All fields are optional (non-mandatory)
- Income and Expense amounts default to 0 if not provided
- Date picker defaults to today's date
- Table shows totals at the bottom
- Data automatically reloads when sector or date changes

