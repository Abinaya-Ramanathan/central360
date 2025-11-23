-- Add advance_deducted column to salary_expenses table
ALTER TABLE salary_expenses 
ADD COLUMN IF NOT EXISTS advance_deducted INTEGER DEFAULT 0;

-- Remove unique constraint to allow multiple entries per month
ALTER TABLE salary_expenses 
DROP CONSTRAINT IF EXISTS salary_expenses_employee_id_week_start_date_week_end_date_key;

-- Add new index for better querying
CREATE INDEX IF NOT EXISTS idx_salary_expenses_employee_month 
ON salary_expenses(employee_id, week_start_date, week_end_date);

