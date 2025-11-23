-- Add packing_items_charge column to expense_details table
ALTER TABLE expense_details 
  ADD COLUMN IF NOT EXISTS packing_items_charge DECIMAL(10, 2) DEFAULT 0;

