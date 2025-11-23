-- Update expense_details table: remove others_salary, add new columns
ALTER TABLE expense_details 
  DROP COLUMN IF EXISTS others_salary,
  ADD COLUMN IF NOT EXISTS current_bill DECIMAL(10, 2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS cleaning_bill DECIMAL(10, 2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS grocery_bill DECIMAL(10, 2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS vegetable_bill DECIMAL(10, 2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS cylinder_quantity INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS cylinder_amount DECIMAL(10, 2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS morning_food_expense DECIMAL(10, 2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS afternoon_food_expense DECIMAL(10, 2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS evening_food_expense DECIMAL(10, 2) DEFAULT 0;

