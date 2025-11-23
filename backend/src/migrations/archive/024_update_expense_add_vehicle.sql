-- Add vehicle_expense column to expense_details table
ALTER TABLE expense_details 
  ADD COLUMN IF NOT EXISTS vehicle_expense DECIMAL(10, 2) DEFAULT 0;

