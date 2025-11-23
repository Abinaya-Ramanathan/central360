-- Add full_settlement_date column to credit_details table
ALTER TABLE credit_details 
ADD COLUMN IF NOT EXISTS full_settlement_date DATE;

