-- Add sector_code column to daily_expenses table
ALTER TABLE daily_expenses
ADD COLUMN IF NOT EXISTS sector_code VARCHAR(50) REFERENCES sectors(code) ON DELETE CASCADE;

-- Create index for better query performance
CREATE INDEX IF NOT EXISTS idx_daily_expenses_sector ON daily_expenses(sector_code);
CREATE INDEX IF NOT EXISTS idx_daily_expenses_sector_date ON daily_expenses(sector_code, expense_date);

