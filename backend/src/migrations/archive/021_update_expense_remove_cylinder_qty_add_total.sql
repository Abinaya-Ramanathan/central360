-- Remove cylinder_quantity and add total_expense column
ALTER TABLE expense_details 
  DROP COLUMN IF EXISTS cylinder_quantity,
  ADD COLUMN IF NOT EXISTS total_expense DECIMAL(10, 2) DEFAULT 0;

